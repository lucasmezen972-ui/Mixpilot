#if os(macOS)
import Combine
import Foundation
import MixPilotRemoteProtocol
import Network

private final class MixPilotRemoteClientSession: @unchecked Sendable {
    let id = UUID()
    let connection: NWConnection
    var deviceID: String?
    var deviceName: String?
    var authenticated = false
    var subscribed = false
    var protocolVersion = MixPilotRemoteProtocolVersion.minimumSupported

    private let queue: DispatchQueue
    private var closed = false

    init(connection: NWConnection) {
        self.connection = connection
        self.queue = DispatchQueue(label: "com.mixpilot.remote.session.\(id.uuidString)")
    }

    func start(
        onReady: @escaping @Sendable () -> Void,
        onMessage: @escaping @Sendable (Data) -> Void,
        onClose: @escaping @Sendable () -> Void
    ) {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                onReady()
                self.receiveNext(onMessage: onMessage, onClose: onClose)
            case .failed, .cancelled:
                onClose()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func send(_ data: Data, completion: (@Sendable (NWError?) -> Void)? = nil) {
        guard !closed else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(
            identifier: "mixpilot-remote-message",
            metadata: [metadata]
        )
        connection.send(
            content: data,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { error in completion?(error) }
        )
    }

    func close() {
        guard !closed else { return }
        closed = true
        connection.cancel()
    }

    private func receiveNext(
        onMessage: @escaping @Sendable (Data) -> Void,
        onClose: @escaping @Sendable () -> Void
    ) {
        connection.receiveMessage { [weak self] content, _, _, error in
            guard let self else { return }
            if let content, !content.isEmpty {
                onMessage(content)
            }
            if error != nil {
                onClose()
                return
            }
            self.receiveNext(onMessage: onMessage, onClose: onClose)
        }
    }
}

@MainActor
public final class MixPilotRemoteBridge: ObservableObject, @unchecked Sendable {
    @Published public private(set) var isRunning = false
    @Published public private(set) var status = "Télécommande désactivée"
    @Published public private(set) var pairingCode = "------"
    @Published public private(set) var connectedClientCount = 0

    private weak var provider: (any MixPilotRemoteStateProvider)?
    private var listener: NWListener?
    private var sessions: [UUID: MixPilotRemoteClientSession] = [:]
    private var snapshotTask: Task<Void, Never>?
    private var sequence = 0
    private let networkQueue = DispatchQueue(label: "com.mixpilot.remote.listener")
    private let pairingAuthority: MixPilotRemotePairingAuthority

    private var currentTrackKey: String?
    private var currentTrackElapsed: TimeInterval = 0
    private var lastClockUpdate = Date()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init() {
        self.pairingAuthority = MixPilotRemotePairingAuthority()
    }

    deinit {
        listener?.cancel()
        snapshotTask?.cancel()
        sessions.values.forEach { $0.close() }
    }

    public func start(provider: any MixPilotRemoteStateProvider) {
        guard !isRunning else {
            self.provider = provider
            return
        }
        self.provider = provider
        pairingCode = pairingAuthority.rotatePairingCode()

        do {
            let parameters = NWParameters.tcp
            let webSocketOptions = NWProtocolWebSocket.Options()
            webSocketOptions.autoReplyPing = true
            webSocketOptions.maximumMessageSize = 64 * 1_024
            parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

            let listener = try NWListener(using: parameters, on: .any)
            listener.service = NWListener.Service(
                name: ProcessInfo.processInfo.hostName,
                type: "_mixpilot._tcp"
            )
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in self?.accept(connection) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in self?.applyListenerState(state) }
            }
            self.listener = listener
            listener.start(queue: networkQueue)
            isRunning = true
            status = "Démarrage de la télécommande…"
            startSnapshotLoop()
        } catch {
            providerFailure(error)
        }
    }

    public func stop() {
        snapshotTask?.cancel()
        snapshotTask = nil
        listener?.cancel()
        listener = nil
        sessions.values.forEach { $0.close() }
        sessions.removeAll()
        connectedClientCount = 0
        isRunning = false
        status = "Télécommande désactivée"
        provider = nil
    }

    public func rotatePairingCode() {
        pairingCode = pairingAuthority.rotatePairingCode()
    }

    private func providerFailure(_ error: Error) {
        listener = nil
        isRunning = false
        provider = nil
        status = "Échec télécommande : \(error.localizedDescription)"
    }

    private func applyListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            if let port = listener?.port {
                status = "Télécommande active • port \(port.rawValue)"
            } else {
                status = "Télécommande active"
            }
        case .failed(let error):
            status = "Échec réseau : \(error.localizedDescription)"
            stop()
        case .cancelled:
            if isRunning { status = "Télécommande arrêtée" }
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        guard isRunning else {
            connection.cancel()
            return
        }
        let session = MixPilotRemoteClientSession(connection: connection)
        sessions[session.id] = session
        connectedClientCount = sessions.count

        session.start(
            onReady: { [weak self, weak session] in
                Task { @MainActor in
                    guard let self, let session else { return }
                    self.send(.simple("hello", message: "MixPilot Autopilot"), to: session)
                }
            },
            onMessage: { [weak self, weak session] data in
                Task { @MainActor in
                    guard let self, let session else { return }
                    await self.handle(data, from: session)
                }
            },
            onClose: { [weak self, weak session] in
                Task { @MainActor in
                    guard let self, let session else { return }
                    self.remove(session)
                }
            }
        )
    }

    private func remove(_ session: MixPilotRemoteClientSession) {
        sessions.removeValue(forKey: session.id)
        connectedClientCount = sessions.count
    }

    private func handle(_ data: Data, from session: MixPilotRemoteClientSession) async {
        let message: MixPilotRemoteClientMessage
        do {
            message = try decoder.decode(MixPilotRemoteClientMessage.self, from: data)
        } catch {
            send(.simple("error", message: "Message JSON invalide."), to: session)
            return
        }

        guard MixPilotRemoteProtocolVersion.supports(message.version) else {
            send(
                .simple(
                    "error",
                    message: "Version du protocole non compatible. Versions acceptées : \(MixPilotRemoteProtocolVersion.minimumSupported) à \(MixPilotRemoteProtocolVersion.current)."
                ),
                to: session
            )
            return
        }
        session.protocolVersion = message.version

        switch message.type {
        case "hello":
            session.deviceID = message.deviceID
            session.deviceName = message.deviceName
            send(.simple("pairing_required", message: "Appairage ou authentification requis."), to: session)

        case "pair":
            guard let deviceID = message.deviceID,
                  let pin = message.pin,
                  !deviceID.isEmpty else {
                send(.simple("error", message: "Demande d’appairage incomplète."), to: session)
                return
            }
            do {
                let token = try pairingAuthority.pair(deviceID: deviceID, pin: pin)
                session.deviceID = deviceID
                session.deviceName = message.deviceName
                session.authenticated = true
                pairingCode = pairingAuthority.pairingCode
                send(.paired(token: token), to: session)
            } catch {
                send(.simple("error", message: error.localizedDescription), to: session)
            }

        case "authenticate":
            guard let deviceID = message.deviceID,
                  let token = message.token,
                  pairingAuthority.authenticate(deviceID: deviceID, token: token) else {
                send(.simple("pairing_required", message: "Jeton absent ou révoqué."), to: session)
                return
            }
            session.deviceID = deviceID
            session.authenticated = true
            send(.simple("authenticated"), to: session)

        case "subscribe":
            guard session.authenticated else {
                send(.simple("error", message: "Authentification requise."), to: session)
                return
            }
            session.subscribed = true
            publishSnapshot(to: session)

        case "command":
            guard session.authenticated,
                  let deviceID = session.deviceID,
                  let command = message.command else {
                send(.simple("error", message: "Commande non authentifiée."), to: session)
                return
            }
            let authorization = pairingAuthority.authorize(command: command, deviceID: deviceID)
            guard authorization.allowed else {
                send(.acknowledgement(.init(
                    commandID: command.id,
                    accepted: false,
                    message: authorization.message
                )), to: session)
                return
            }
            guard let provider else {
                send(.acknowledgement(.init(
                    commandID: command.id,
                    accepted: false,
                    message: "MixPilot n’est pas disponible."
                )), to: session)
                return
            }
            let decision = await provider.handleRemoteCommand(command.kind)
            send(.acknowledgement(.init(
                commandID: command.id,
                accepted: decision.accepted,
                message: decision.message
            )), to: session)
            publishSnapshot()

        case "ping":
            send(.simple("pong"), to: session)

        default:
            send(.simple("error", message: "Type de message inconnu : \(message.type)"), to: session)
        }
    }

    private func startSnapshotLoop() {
        snapshotTask?.cancel()
        snapshotTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.publishSnapshot()
            }
        }
    }

    private func publishSnapshot(to onlySession: MixPilotRemoteClientSession? = nil) {
        guard let provider else { return }
        sequence += 1
        let now = Date()
        var snapshot = provider.makeRemoteSnapshot(sequence: sequence, now: now)
        snapshot = applyProgressClock(to: snapshot, now: now)

        let targets = onlySession.map { [$0] } ?? Array(sessions.values)
        for session in targets where session.authenticated && session.subscribed {
            let canControl = session.deviceID.map(pairingAuthority.isPrimary(deviceID:)) ?? false
            let outgoing = canControl ? snapshot : snapshot.with(
                canPause: false,
                canResume: false,
                canSkipTransition: false,
                canSafeFade: false,
                canTakeManualControl: false
            )
            send(.snapshot(outgoing), to: session)
        }
    }

    private func applyProgressClock(to snapshot: MixPilotRemoteSnapshot, now: Date) -> MixPilotRemoteSnapshot {
        let key = snapshot.currentTrack.map { "\($0.title)|\($0.artist)" }
        if key != currentTrackKey {
            currentTrackKey = key
            currentTrackElapsed = 0
            lastClockUpdate = now
        } else {
            let delta = max(0, now.timeIntervalSince(lastClockUpdate))
            if snapshot.mode == .live {
                currentTrackElapsed += delta
            }
            lastClockUpdate = now
        }
        let capped = snapshot.duration > 0 ? min(currentTrackElapsed, snapshot.duration) : currentTrackElapsed
        return snapshot.with(elapsed: capped)
    }

    private func send(_ message: MixPilotRemoteServerMessage, to session: MixPilotRemoteClientSession) {
        do {
            let compatibleMessage = MixPilotRemoteServerMessage(
                version: session.protocolVersion,
                type: message.type,
                message: message.message,
                sessionToken: message.sessionToken,
                snapshot: message.snapshot,
                acknowledgement: message.acknowledgement
            )
            let data = try encoder.encode(compatibleMessage)
            session.send(data)
        } catch {
            status = "Erreur d’encodage distante : \(error.localizedDescription)"
        }
    }
}
#endif
