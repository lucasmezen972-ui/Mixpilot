import Foundation
import MixPilotRemoteProtocol
import UIKit

@MainActor
final class RemoteConnection: ObservableObject {
    @Published private(set) var status: RemoteConnectionStatus = .idle
    @Published private(set) var snapshot: RemoteSnapshot?
    @Published private(set) var lastAcknowledgement: RemoteCommandAcknowledgement?
    @Published private(set) var lastError: String?
    @Published var pairingRequired = false
    @Published private(set) var isDemo = false

    private var endpoint: RemoteEndpoint?
    private var socket: URLSessionWebSocketTask?
    private var receiverTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var sequencePolicy = RemoteSnapshotSequencePolicy()
    private var reconnectPolicy = RemoteTransportRetryPolicy()
    private var shouldReconnect = false
    private var transportGeneration: UInt64 = 0

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

    private var deviceID: String {
        let key = "mixpilot.remote.device-id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }

    func connect(to endpoint: RemoteEndpoint) {
        stopAllTransport()
        isDemo = false
        snapshot = nil
        lastError = nil
        lastAcknowledgement = nil
        pairingRequired = false
        self.endpoint = endpoint
        shouldReconnect = true
        reconnectPolicy.reset()
        beginConnection()
    }

    func pair(using pin: String) {
        guard let endpoint else { return }
        let normalized = pin.filter { $0.isNumber }
        guard normalized.count == 6 else {
            lastError = "Le code doit contenir six chiffres."
            return
        }

        let generation = transportGeneration
        Task { [weak self] in
            guard let self else { return }
            await self.send(
                .pair(
                    deviceID: self.deviceID,
                    deviceName: UIDevice.current.name,
                    pin: normalized
                ),
                generation: generation
            )
            guard generation == self.transportGeneration else { return }
            self.status = .pairingRequired(endpoint.name)
        }
    }

    func sendCommand(_ kind: RemoteCommandKind) {
        if isDemo {
            applyDemoCommand(kind)
            return
        }

        guard status.isAuthenticated else {
            lastError = "Le Mac n’est pas connecté."
            return
        }

        let command = RemoteCommand(kind: kind)
        let generation = transportGeneration
        Task { [weak self] in
            await self?.send(.command(command), generation: generation)
        }
    }

    func startDemo() {
        stopAllTransport()
        isDemo = true
        endpoint = nil
        pairingRequired = false
        lastError = nil
        lastAcknowledgement = nil
        snapshot = .demo
        status = .authenticated("Mode démo")
    }

    func disconnect(reason: String = "Fermé par l’utilisateur") {
        stopAllTransport()
        isDemo = false
        endpoint = nil
        pairingRequired = false
        snapshot = nil
        status = .disconnected(reason)
    }

    private func beginConnection() {
        guard shouldReconnect, let endpoint else { return }
        closeSocketTransport()
        transportGeneration &+= 1
        let generation = transportGeneration
        status = .connecting(endpoint.name)

        var components = URLComponents()
        components.scheme = "ws"
        components.host = endpoint.host
        components.port = endpoint.port
        components.path = "/v1/remote"

        guard let url = components.url else {
            shouldReconnect = false
            status = .failed("Adresse réseau invalide")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(
            "mixpilot-remote-v\(MixPilotRemoteProtocolVersion.current)",
            forHTTPHeaderField: "Sec-WebSocket-Protocol"
        )

        let socket = URLSession.shared.webSocketTask(with: request)
        self.socket = socket
        socket.resume()

        receiverTask = Task { [weak self] in
            await self?.receiveLoop(generation: generation)
        }

        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(12))
                } catch {
                    return
                }
                guard let self,
                      !Task.isCancelled,
                      generation == self.transportGeneration else { return }
                await self.send(.ping(), generation: generation)
            }
        }

        Task { [weak self] in
            guard let self, generation == self.transportGeneration else { return }
            await self.send(
                .hello(deviceID: self.deviceID, deviceName: UIDevice.current.name),
                generation: generation
            )
            guard generation == self.transportGeneration else { return }
            if let token = KeychainStore.shared.read(account: endpoint.id) {
                await self.send(
                    .authenticate(deviceID: self.deviceID, token: token),
                    generation: generation
                )
            }
        }
    }

    private func stopAllTransport() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectPolicy.reset()
        closeSocketTransport()
    }

    private func closeSocketTransport() {
        transportGeneration &+= 1
        receiverTask?.cancel()
        heartbeatTask?.cancel()
        receiverTask = nil
        heartbeatTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    private func send(
        _ message: RemoteClientMessage,
        generation: UInt64
    ) async {
        guard generation == transportGeneration, let socket else { return }
        do {
            let data = try encoder.encode(message)
            try await socket.send(.data(data))
        } catch {
            handleTransportFailure(error.localizedDescription, generation: generation)
        }
    }

    private func receiveLoop(generation: UInt64) async {
        do {
            while !Task.isCancelled {
                guard generation == transportGeneration, let socket else { return }
                let message = try await socket.receive()
                guard generation == transportGeneration else { return }

                let data: Data
                switch message {
                case .data(let value):
                    data = value
                case .string(let value):
                    data = Data(value.utf8)
                @unknown default:
                    continue
                }

                let serverMessage = try decoder.decode(RemoteServerMessage.self, from: data)
                handle(serverMessage)
            }
        } catch {
            guard !Task.isCancelled else { return }
            handleTransportFailure(error.localizedDescription, generation: generation)
        }
    }

    private func handleTransportFailure(_ message: String, generation: UInt64) {
        guard generation == transportGeneration,
              shouldReconnect,
              !isDemo,
              endpoint != nil else { return }

        closeSocketTransport()
        let retryGeneration = transportGeneration
        snapshot = nil
        pairingRequired = false
        guard reconnectTask == nil else { return }

        guard let delay = reconnectPolicy.nextDelay() else {
            shouldReconnect = false
            lastError = "La reconnexion automatique a échoué. Sélectionne de nouveau le Mac."
            status = .disconnected("Mac indisponible")
            return
        }

        let seconds = max(1, Int(delay.rounded()))
        lastError = "Connexion interrompue. Nouvelle tentative dans \(seconds) s."
        status = .disconnected("Reconnexion en cours")
        reconnectTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard let self,
                  !Task.isCancelled,
                  self.shouldReconnect,
                  self.transportGeneration == retryGeneration else { return }
            self.reconnectTask = nil
            self.beginConnection()
        }
    }

    private func handle(_ message: RemoteServerMessage) {
        guard MixPilotRemoteProtocolVersion.supports(message.version) else {
            lastError = "Version du protocole non compatible. Mets à jour MixPilot sur le Mac et l’iPhone."
            shouldReconnect = false
            reconnectTask?.cancel()
            reconnectTask = nil
            return
        }

        switch message.type {
        case "pairing_required":
            pairingRequired = true
            status = .pairingRequired(endpoint?.name ?? "Mac")

        case "paired":
            guard let endpoint, let token = message.sessionToken else {
                lastError = "Réponse d’appairage incomplète."
                return
            }
            do {
                try KeychainStore.shared.save(token, account: endpoint.id)
                reconnectPolicy.markReady()
                pairingRequired = false
                lastError = nil
                status = .authenticated(endpoint.name)
                let lastSequence = sequencePolicy.lastSequence(for: endpoint.id)
                let generation = transportGeneration
                Task { [weak self] in
                    await self?.send(.subscribe(lastSequence: lastSequence), generation: generation)
                }
            } catch {
                lastError = error.localizedDescription
            }

        case "authenticated":
            reconnectPolicy.markReady()
            pairingRequired = false
            lastError = nil
            status = .authenticated(endpoint?.name ?? "Mac")
            let lastSequence = endpoint.flatMap { sequencePolicy.lastSequence(for: $0.id) }
            let generation = transportGeneration
            Task { [weak self] in
                await self?.send(.subscribe(lastSequence: lastSequence), generation: generation)
            }

        case "snapshot":
            if let endpoint,
               let incoming = message.snapshot,
               sequencePolicy.shouldAccept(sequence: incoming.sequence, endpointID: endpoint.id) {
                snapshot = incoming
            }

        case "ack":
            lastAcknowledgement = message.acknowledgement
            if message.acknowledgement?.accepted == false {
                lastError = message.acknowledgement?.message
            } else {
                lastError = nil
            }

        case "error":
            lastError = message.message ?? "Erreur distante inconnue."

        case "pong", "hello":
            break

        default:
            lastError = "Message distant inconnu : \(message.type)"
        }
    }

    private func applyDemoCommand(_ kind: RemoteCommandKind) {
        guard let current = snapshot else { return }
        let acknowledgement = RemoteCommandAcknowledgement(
            commandID: UUID(),
            accepted: true,
            message: "Commande simulée"
        )
        lastAcknowledgement = acknowledgement
        lastError = nil

        switch kind {
        case .pauseAutopilot:
            snapshot = copy(current, mode: .paused, alert: "Autopilote en pause depuis l’iPhone")
        case .resumeAutopilot:
            snapshot = copy(current, mode: .live, alert: nil)
        case .skipTransition:
            snapshot = RemoteSnapshot(
                sequence: current.sequence + 1,
                updatedAt: Date(),
                mode: current.mode,
                setName: current.setName,
                backend: current.backend,
                currentTrack: current.nextTrack ?? current.currentTrack,
                nextTrack: nil,
                activeDeck: current.activeDeck,
                elapsed: 0,
                duration: 198,
                transitionLabel: "Prochaine transition recalculée",
                transitionConfidence: 84,
                audioStatus: current.audioStatus,
                alert: "Transition suivante passée en mode démo",
                canPause: true,
                canResume: false,
                canSkipTransition: false,
                canSafeFade: true,
                canTakeManualControl: true
            )
        case .safeFade:
            snapshot = copy(current, mode: .recovery, alert: "Safe Fade demandé depuis l’iPhone")
        case .takeManualControl:
            snapshot = copy(current, mode: .manualControl, alert: "Contrôle manuel activé")
        }
    }

    private func copy(_ value: RemoteSnapshot, mode: RemoteMode, alert: String?) -> RemoteSnapshot {
        RemoteSnapshot(
            sequence: value.sequence + 1,
            updatedAt: Date(),
            mode: mode,
            setName: value.setName,
            backend: value.backend,
            currentTrack: value.currentTrack,
            nextTrack: value.nextTrack,
            activeDeck: value.activeDeck,
            elapsed: value.elapsed,
            duration: value.duration,
            transitionLabel: value.transitionLabel,
            transitionConfidence: value.transitionConfidence,
            audioStatus: value.audioStatus,
            alert: alert,
            canPause: mode == .live,
            canResume: mode == .paused,
            canSkipTransition: mode == .live,
            canSafeFade: mode != .manualControl,
            canTakeManualControl: mode != .manualControl
        )
    }
}
