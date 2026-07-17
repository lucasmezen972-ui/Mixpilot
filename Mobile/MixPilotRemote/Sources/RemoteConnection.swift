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
    private var sequencePolicy = RemoteSnapshotSequencePolicy()

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
        closeTransport()
        isDemo = false
        snapshot = nil
        lastError = nil
        lastAcknowledgement = nil
        pairingRequired = false
        self.endpoint = endpoint
        status = .connecting(endpoint.name)

        var components = URLComponents()
        components.scheme = "ws"
        components.host = endpoint.host
        components.port = endpoint.port
        components.path = "/v1/remote"

        guard let url = components.url else {
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
            await self?.receiveLoop()
        }

        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard let self, !Task.isCancelled else { return }
                await self.send(.ping())
            }
        }

        Task { [weak self] in
            guard let self else { return }
            await self.send(.hello(deviceID: self.deviceID, deviceName: UIDevice.current.name))
            if let token = KeychainStore.shared.read(account: endpoint.id) {
                await self.send(.authenticate(deviceID: self.deviceID, token: token))
            }
        }
    }

    func pair(using pin: String) {
        guard let endpoint else { return }
        let normalized = pin.filter { $0.isNumber }
        guard normalized.count == 6 else {
            lastError = "Le code doit contenir six chiffres."
            return
        }

        Task { [weak self] in
            guard let self else { return }
            await self.send(.pair(
                deviceID: self.deviceID,
                deviceName: UIDevice.current.name,
                pin: normalized
            ))
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
        Task { [weak self] in
            await self?.send(.command(command))
        }
    }

    func startDemo() {
        closeTransport()
        isDemo = true
        endpoint = nil
        pairingRequired = false
        lastError = nil
        lastAcknowledgement = nil
        snapshot = .demo
        status = .authenticated("Mode démo")
    }

    func disconnect(reason: String = "Fermé par l’utilisateur") {
        closeTransport()
        isDemo = false
        endpoint = nil
        pairingRequired = false
        snapshot = nil
        status = .disconnected(reason)
    }

    private func closeTransport() {
        receiverTask?.cancel()
        heartbeatTask?.cancel()
        receiverTask = nil
        heartbeatTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    private func send(_ message: RemoteClientMessage) async {
        guard let socket else { return }
        do {
            let data = try encoder.encode(message)
            try await socket.send(.data(data))
        } catch {
            lastError = error.localizedDescription
            status = .disconnected("Envoi impossible")
        }
    }

    private func receiveLoop() async {
        do {
            while !Task.isCancelled {
                guard let socket else { return }
                let message = try await socket.receive()
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
            snapshot = nil
            pairingRequired = false
            status = .disconnected(error.localizedDescription)
        }
    }

    private func handle(_ message: RemoteServerMessage) {
        guard MixPilotRemoteProtocolVersion.supports(message.version) else {
            lastError = "Version du protocole non compatible. Mets à jour MixPilot sur le Mac et l’iPhone."
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
                pairingRequired = false
                status = .authenticated(endpoint.name)
                let lastSequence = sequencePolicy.lastSequence(for: endpoint.id)
                Task { [weak self] in await self?.send(.subscribe(lastSequence: lastSequence)) }
            } catch {
                lastError = error.localizedDescription
            }

        case "authenticated":
            pairingRequired = false
            status = .authenticated(endpoint?.name ?? "Mac")
            let lastSequence = endpoint.flatMap { sequencePolicy.lastSequence(for: $0.id) }
            Task { [weak self] in await self?.send(.subscribe(lastSequence: lastSequence)) }

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
