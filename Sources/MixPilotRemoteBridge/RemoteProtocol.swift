#if os(macOS)
import Foundation

public enum MixPilotRemoteMode: String, Codable, Sendable {
    case idle
    case preflight
    case live
    case paused
    case manualControl
    case recovery
}

public struct MixPilotRemoteTrackSummary: Codable, Hashable, Sendable {
    public let title: String
    public let artist: String
    public let bpm: Double?

    public init(title: String, artist: String, bpm: Double?) {
        self.title = title
        self.artist = artist
        self.bpm = bpm
    }
}

public struct MixPilotRemoteSnapshot: Codable, Hashable, Sendable {
    public let sequence: Int
    public let updatedAt: Date
    public let mode: MixPilotRemoteMode
    public let setName: String
    public let currentTrack: MixPilotRemoteTrackSummary?
    public let nextTrack: MixPilotRemoteTrackSummary?
    public let elapsed: TimeInterval
    public let duration: TimeInterval
    public let transitionLabel: String?
    public let transitionConfidence: Int?
    public let alert: String?
    public let canPause: Bool
    public let canResume: Bool
    public let canSkipTransition: Bool
    public let canSafeFade: Bool
    public let canTakeManualControl: Bool

    public init(
        sequence: Int,
        updatedAt: Date,
        mode: MixPilotRemoteMode,
        setName: String,
        currentTrack: MixPilotRemoteTrackSummary?,
        nextTrack: MixPilotRemoteTrackSummary?,
        elapsed: TimeInterval,
        duration: TimeInterval,
        transitionLabel: String?,
        transitionConfidence: Int?,
        alert: String?,
        canPause: Bool,
        canResume: Bool,
        canSkipTransition: Bool,
        canSafeFade: Bool,
        canTakeManualControl: Bool
    ) {
        self.sequence = sequence
        self.updatedAt = updatedAt
        self.mode = mode
        self.setName = setName
        self.currentTrack = currentTrack
        self.nextTrack = nextTrack
        self.elapsed = max(0, elapsed)
        self.duration = max(0, duration)
        self.transitionLabel = transitionLabel
        self.transitionConfidence = transitionConfidence
        self.alert = alert
        self.canPause = canPause
        self.canResume = canResume
        self.canSkipTransition = canSkipTransition
        self.canSafeFade = canSafeFade
        self.canTakeManualControl = canTakeManualControl
    }

    func with(
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
            currentTrack: currentTrack,
            nextTrack: nextTrack,
            elapsed: elapsed ?? self.elapsed,
            duration: duration,
            transitionLabel: transitionLabel,
            transitionConfidence: transitionConfidence,
            alert: alert,
            canPause: canPause ?? self.canPause,
            canResume: canResume ?? self.canResume,
            canSkipTransition: canSkipTransition ?? self.canSkipTransition,
            canSafeFade: canSafeFade ?? self.canSafeFade,
            canTakeManualControl: canTakeManualControl ?? self.canTakeManualControl
        )
    }
}

public enum MixPilotRemoteCommandKind: String, Codable, Sendable {
    case pauseAutopilot
    case resumeAutopilot
    case skipTransition
    case safeFade
    case takeManualControl
}

public struct MixPilotRemoteCommand: Codable, Sendable {
    public let id: UUID
    public let kind: MixPilotRemoteCommandKind
    public let issuedAt: Date
}

struct MixPilotRemoteClientMessage: Codable, Sendable {
    let version: Int
    let type: String
    let deviceID: String?
    let deviceName: String?
    let pin: String?
    let token: String?
    let command: MixPilotRemoteCommand?
    let lastSequence: Int?
}

public struct MixPilotRemoteCommandAcknowledgement: Codable, Hashable, Sendable {
    public let commandID: UUID
    public let accepted: Bool
    public let message: String

    public init(commandID: UUID, accepted: Bool, message: String) {
        self.commandID = commandID
        self.accepted = accepted
        self.message = message
    }
}

struct MixPilotRemoteServerMessage: Codable, Sendable {
    let version: Int
    let type: String
    let message: String?
    let sessionToken: String?
    let snapshot: MixPilotRemoteSnapshot?
    let acknowledgement: MixPilotRemoteCommandAcknowledgement?

    static func simple(_ type: String, message: String? = nil) -> Self {
        .init(version: 1, type: type, message: message, sessionToken: nil, snapshot: nil, acknowledgement: nil)
    }

    static func paired(token: String) -> Self {
        .init(version: 1, type: "paired", message: nil, sessionToken: token, snapshot: nil, acknowledgement: nil)
    }

    static func snapshot(_ snapshot: MixPilotRemoteSnapshot) -> Self {
        .init(version: 1, type: "snapshot", message: nil, sessionToken: nil, snapshot: snapshot, acknowledgement: nil)
    }

    static func acknowledgement(_ acknowledgement: MixPilotRemoteCommandAcknowledgement) -> Self {
        .init(version: 1, type: "ack", message: nil, sessionToken: nil, snapshot: nil, acknowledgement: acknowledgement)
    }
}

public struct MixPilotRemoteCommandDecision: Sendable {
    public let accepted: Bool
    public let message: String

    public init(accepted: Bool, message: String) {
        self.accepted = accepted
        self.message = message
    }
}

@MainActor
public protocol MixPilotRemoteStateProvider: AnyObject {
    func makeRemoteSnapshot(sequence: Int, now: Date) -> MixPilotRemoteSnapshot
    func handleRemoteCommand(_ kind: MixPilotRemoteCommandKind) async -> MixPilotRemoteCommandDecision
}
#endif
