import Foundation

enum RemoteConnectionStatus: Equatable {
    case idle
    case discovering
    case connecting(String)
    case pairingRequired(String)
    case authenticated(String)
    case disconnected(String)
    case failed(String)

    var title: String {
        switch self {
        case .idle: return "Hors ligne"
        case .discovering: return "Recherche du Mac…"
        case .connecting(let name): return "Connexion à \(name)…"
        case .pairingRequired(let name): return "Appairage avec \(name)"
        case .authenticated(let name): return "Connecté à \(name)"
        case .disconnected(let reason): return "Déconnecté • \(reason)"
        case .failed(let reason): return "Erreur • \(reason)"
        }
    }

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}

struct RemoteEndpoint: Identifiable, Hashable {
    let name: String
    let host: String
    let port: Int

    var id: String { "\(host):\(port)" }
}

enum RemoteMode: String, Codable {
    case idle
    case preflight
    case live
    case paused
    case manualControl
    case recovery
}

struct RemoteTrackSummary: Codable, Hashable {
    let title: String
    let artist: String
    let bpm: Double?
}

struct RemoteSnapshot: Codable, Hashable {
    let sequence: Int
    let updatedAt: Date
    let mode: RemoteMode
    let setName: String
    let currentTrack: RemoteTrackSummary?
    let nextTrack: RemoteTrackSummary?
    let elapsed: TimeInterval
    let duration: TimeInterval
    let transitionLabel: String?
    let transitionConfidence: Int?
    let alert: String?
    let canPause: Bool
    let canResume: Bool
    let canSkipTransition: Bool
    let canSafeFade: Bool
    let canTakeManualControl: Bool

    static let demo = RemoteSnapshot(
        sequence: 1,
        updatedAt: Date(),
        mode: .live,
        setName: "Baptême — Set principal",
        currentTrack: RemoteTrackSummary(title: "Water", artist: "Tyla", bpm: 117),
        nextTrack: RemoteTrackSummary(title: "One Track Mind", artist: "Naïka", bpm: 116),
        elapsed: 74,
        duration: 201,
        transitionLabel: "Smooth Blend dans 1 min 12",
        transitionConfidence: 91,
        alert: nil,
        canPause: true,
        canResume: false,
        canSkipTransition: true,
        canSafeFade: true,
        canTakeManualControl: true
    )
}

enum RemoteCommandKind: String, Codable {
    case pauseAutopilot
    case resumeAutopilot
    case skipTransition
    case safeFade
    case takeManualControl
}

struct RemoteCommand: Codable {
    let id: UUID
    let kind: RemoteCommandKind
    let issuedAt: Date

    init(kind: RemoteCommandKind) {
        self.id = UUID()
        self.kind = kind
        self.issuedAt = Date()
    }
}

struct RemoteClientMessage: Codable {
    let version: Int
    let type: String
    let deviceID: String?
    let deviceName: String?
    let pin: String?
    let token: String?
    let command: RemoteCommand?
    let lastSequence: Int?

    static func hello(deviceID: String, deviceName: String) -> Self {
        .init(version: 1, type: "hello", deviceID: deviceID, deviceName: deviceName, pin: nil, token: nil, command: nil, lastSequence: nil)
    }

    static func pair(deviceID: String, deviceName: String, pin: String) -> Self {
        .init(version: 1, type: "pair", deviceID: deviceID, deviceName: deviceName, pin: pin, token: nil, command: nil, lastSequence: nil)
    }

    static func authenticate(deviceID: String, token: String) -> Self {
        .init(version: 1, type: "authenticate", deviceID: deviceID, deviceName: nil, pin: nil, token: token, command: nil, lastSequence: nil)
    }

    static func subscribe(lastSequence: Int?) -> Self {
        .init(version: 1, type: "subscribe", deviceID: nil, deviceName: nil, pin: nil, token: nil, command: nil, lastSequence: lastSequence)
    }

    static func command(_ command: RemoteCommand) -> Self {
        .init(version: 1, type: "command", deviceID: nil, deviceName: nil, pin: nil, token: nil, command: command, lastSequence: nil)
    }

    static func ping() -> Self {
        .init(version: 1, type: "ping", deviceID: nil, deviceName: nil, pin: nil, token: nil, command: nil, lastSequence: nil)
    }
}

struct RemoteCommandAcknowledgement: Codable, Hashable {
    let commandID: UUID
    let accepted: Bool
    let message: String
}

struct RemoteServerMessage: Codable {
    let version: Int
    let type: String
    let message: String?
    let sessionToken: String?
    let snapshot: RemoteSnapshot?
    let acknowledgement: RemoteCommandAcknowledgement?
}
