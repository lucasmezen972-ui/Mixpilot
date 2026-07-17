import Foundation

public enum MixPilotRemoteProtocolVersion {
    public static let current = 2
    public static let minimumSupported = 1
}

public enum RemoteDJBackendIdentifier: String, Codable, CaseIterable, Sendable {
    case djay
    case rekordbox
    case serato

    public var displayName: String {
        switch self {
        case .djay: "djay Pro"
        case .rekordbox: "rekordbox"
        case .serato: "Serato DJ Pro"
        }
    }
}

public enum RemoteMode: String, Codable, Sendable {
    case idle
    case preflight
    case live
    case paused
    case manualControl
    case recovery
}

public struct RemoteTrackSummary: Codable, Hashable, Sendable {
    public let title: String
    public let artist: String
    public let bpm: Double?

    public init(title: String, artist: String, bpm: Double?) {
        self.title = title
        self.artist = artist
        self.bpm = bpm
    }
}

public struct RemoteBackendSummary: Codable, Hashable, Sendable {
    public let identifier: RemoteDJBackendIdentifier
    public let softwareVersion: String?
    public let modeLabel: String
    public let degradedCapabilities: [String]

    public init(
        identifier: RemoteDJBackendIdentifier,
        softwareVersion: String? = nil,
        modeLabel: String,
        degradedCapabilities: [String] = []
    ) {
        self.identifier = identifier
        self.softwareVersion = softwareVersion
        self.modeLabel = modeLabel
        self.degradedCapabilities = degradedCapabilities
    }
}

public struct RemoteSnapshot: Codable, Hashable, Sendable {
    public let sequence: Int
    public let updatedAt: Date
    public let mode: RemoteMode
    public let setName: String
    public let backend: RemoteBackendSummary?
    public let currentTrack: RemoteTrackSummary?
    public let nextTrack: RemoteTrackSummary?
    public let activeDeck: String?
    public let elapsed: TimeInterval
    public let duration: TimeInterval
    public let transitionLabel: String?
    public let transitionConfidence: Int?
    public let audioStatus: String?
    public let alert: String?
    public let canPause: Bool
    public let canResume: Bool
    public let canSkipTransition: Bool
    public let canSafeFade: Bool
    public let canTakeManualControl: Bool

    public init(
        sequence: Int,
        updatedAt: Date,
        mode: RemoteMode,
        setName: String,
        backend: RemoteBackendSummary? = nil,
        currentTrack: RemoteTrackSummary?,
        nextTrack: RemoteTrackSummary?,
        activeDeck: String? = nil,
        elapsed: TimeInterval,
        duration: TimeInterval,
        transitionLabel: String?,
        transitionConfidence: Int?,
        audioStatus: String? = nil,
        alert: String?,
        canPause: Bool,
        canResume: Bool,
        canSkipTransition: Bool,
        canSafeFade: Bool,
        canTakeManualControl: Bool
    ) {
        self.sequence = max(0, sequence)
        self.updatedAt = updatedAt
        self.mode = mode
        self.setName = setName
        self.backend = backend
        self.currentTrack = currentTrack
        self.nextTrack = nextTrack
        self.activeDeck = activeDeck
        self.elapsed = max(0, elapsed)
        self.duration = max(0, duration)
        self.transitionLabel = transitionLabel
        self.transitionConfidence = transitionConfidence
        self.audioStatus = audioStatus
        self.alert = alert
        self.canPause = canPause
        self.canResume = canResume
        self.canSkipTransition = canSkipTransition
        self.canSafeFade = canSafeFade
        self.canTakeManualControl = canTakeManualControl
    }

    public func with(
        sequence: Int? = nil,
        updatedAt: Date? = nil,
        elapsed: TimeInterval? = nil,
        canPause: Bool? = nil,
        canResume: Bool? = nil,
        canSkipTransition: Bool? = nil,
        canSafeFade: Bool? = nil,
        canTakeManualControl: Bool? = nil
    ) -> Self {
        .init(
            sequence: sequence ?? self.sequence,
            updatedAt: updatedAt ?? self.updatedAt,
            mode: mode,
            setName: setName,
            backend: backend,
            currentTrack: currentTrack,
            nextTrack: nextTrack,
            activeDeck: activeDeck,
            elapsed: elapsed ?? self.elapsed,
            duration: duration,
            transitionLabel: transitionLabel,
            transitionConfidence: transitionConfidence,
            audioStatus: audioStatus,
            alert: alert,
            canPause: canPause ?? self.canPause,
            canResume: canResume ?? self.canResume,
            canSkipTransition: canSkipTransition ?? self.canSkipTransition,
            canSafeFade: canSafeFade ?? self.canSafeFade,
            canTakeManualControl: canTakeManualControl ?? self.canTakeManualControl
        )
    }

    enum CodingKeys: String, CodingKey {
        case sequence, updatedAt, mode, setName, backend, currentTrack, nextTrack,
             activeDeck, elapsed, duration, transitionLabel, transitionConfidence,
             audioStatus, alert, canPause, canResume, canSkipTransition,
             canSafeFade, canTakeManualControl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sequence: try container.decode(Int.self, forKey: .sequence),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            mode: try container.decode(RemoteMode.self, forKey: .mode),
            setName: try container.decode(String.self, forKey: .setName),
            backend: try container.decodeIfPresent(RemoteBackendSummary.self, forKey: .backend),
            currentTrack: try container.decodeIfPresent(RemoteTrackSummary.self, forKey: .currentTrack),
            nextTrack: try container.decodeIfPresent(RemoteTrackSummary.self, forKey: .nextTrack),
            activeDeck: try container.decodeIfPresent(String.self, forKey: .activeDeck),
            elapsed: try container.decode(TimeInterval.self, forKey: .elapsed),
            duration: try container.decode(TimeInterval.self, forKey: .duration),
            transitionLabel: try container.decodeIfPresent(String.self, forKey: .transitionLabel),
            transitionConfidence: try container.decodeIfPresent(Int.self, forKey: .transitionConfidence),
            audioStatus: try container.decodeIfPresent(String.self, forKey: .audioStatus),
            alert: try container.decodeIfPresent(String.self, forKey: .alert),
            canPause: try container.decode(Bool.self, forKey: .canPause),
            canResume: try container.decode(Bool.self, forKey: .canResume),
            canSkipTransition: try container.decode(Bool.self, forKey: .canSkipTransition),
            canSafeFade: try container.decode(Bool.self, forKey: .canSafeFade),
            canTakeManualControl: try container.decode(Bool.self, forKey: .canTakeManualControl)
        )
    }
}

public enum RemoteCommandKind: String, Codable, CaseIterable, Sendable {
    case pauseAutopilot
    case resumeAutopilot
    case skipTransition
    case safeFade
    case takeManualControl

    public var displayName: String {
        switch self {
        case .pauseAutopilot: "Mettre en pause"
        case .resumeAutopilot: "Reprendre"
        case .skipTransition: "Changer la prochaine transition"
        case .safeFade: "Transition de secours"
        case .takeManualControl: "Reprendre la main"
        }
    }
}

public struct RemoteCommand: Codable, Sendable {
    public let id: UUID
    public let kind: RemoteCommandKind
    public let issuedAt: Date

    public init(id: UUID = UUID(), kind: RemoteCommandKind, issuedAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.issuedAt = issuedAt
    }
}

public struct RemoteClientMessage: Codable, Sendable {
    public let version: Int
    public let type: String
    public let deviceID: String?
    public let deviceName: String?
    public let pin: String?
    public let token: String?
    public let command: RemoteCommand?
    public let lastSequence: Int?

    public init(
        version: Int = MixPilotRemoteProtocolVersion.current,
        type: String,
        deviceID: String? = nil,
        deviceName: String? = nil,
        pin: String? = nil,
        token: String? = nil,
        command: RemoteCommand? = nil,
        lastSequence: Int? = nil
    ) {
        self.version = version
        self.type = type
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.pin = pin
        self.token = token
        self.command = command
        self.lastSequence = lastSequence
    }

    public static func hello(deviceID: String, deviceName: String) -> Self {
        .init(type: "hello", deviceID: deviceID, deviceName: deviceName)
    }

    public static func pair(deviceID: String, deviceName: String, pin: String) -> Self {
        .init(type: "pair", deviceID: deviceID, deviceName: deviceName, pin: pin)
    }

    public static func authenticate(deviceID: String, token: String) -> Self {
        .init(type: "authenticate", deviceID: deviceID, token: token)
    }

    public static func subscribe(lastSequence: Int?) -> Self {
        .init(type: "subscribe", lastSequence: lastSequence)
    }

    public static func command(_ command: RemoteCommand) -> Self {
        .init(type: "command", command: command)
    }

    public static func ping() -> Self { .init(type: "ping") }
}

public struct RemoteCommandAcknowledgement: Codable, Hashable, Sendable {
    public let commandID: UUID
    public let accepted: Bool
    public let message: String

    public init(commandID: UUID, accepted: Bool, message: String) {
        self.commandID = commandID
        self.accepted = accepted
        self.message = message
    }
}

public struct RemoteServerMessage: Codable, Sendable {
    public let version: Int
    public let type: String
    public let message: String?
    public let sessionToken: String?
    public let snapshot: RemoteSnapshot?
    public let acknowledgement: RemoteCommandAcknowledgement?

    public init(
        version: Int = MixPilotRemoteProtocolVersion.current,
        type: String,
        message: String? = nil,
        sessionToken: String? = nil,
        snapshot: RemoteSnapshot? = nil,
        acknowledgement: RemoteCommandAcknowledgement? = nil
    ) {
        self.version = version
        self.type = type
        self.message = message
        self.sessionToken = sessionToken
        self.snapshot = snapshot
        self.acknowledgement = acknowledgement
    }

    public static func simple(_ type: String, message: String? = nil) -> Self {
        .init(type: type, message: message)
    }

    public static func paired(token: String) -> Self {
        .init(type: "paired", sessionToken: token)
    }

    public static func snapshot(_ snapshot: RemoteSnapshot) -> Self {
        .init(type: "snapshot", snapshot: snapshot)
    }

    public static func acknowledgement(_ acknowledgement: RemoteCommandAcknowledgement) -> Self {
        .init(type: "ack", acknowledgement: acknowledgement)
    }
}
