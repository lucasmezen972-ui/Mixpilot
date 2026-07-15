import Foundation

public enum DeckID: String, Codable, CaseIterable, Sendable {
    case a = "A"
    case b = "B"

    public var opposite: DeckID { self == .a ? .b : .a }
}

public enum MusicalProfile: String, Codable, CaseIterable, Sendable {
    case family = "Soirée familiale"
    case rap = "Rap français"
    case afro = "Afro"
    case amapiano = "Amapiano"
    case zouk = "Zouk"
    case kompa = "Kompa"
    case dancehall = "Dancehall"
    case shatta = "Shatta"
    case bouyon = "Bouyon"
    case variety = "Variété"
    case safe = "Mode sécurisé"
}

public struct Track: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var artist: String
    public var bpm: Double
    public var duration: TimeInterval
    public var energy: Double
    public var vocalDensity: Double
    public var profile: MusicalProfile

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        bpm: Double,
        duration: TimeInterval,
        energy: Double,
        vocalDensity: Double,
        profile: MusicalProfile
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.bpm = bpm
        self.duration = duration
        self.energy = energy.clamped(to: 0...1)
        self.vocalDensity = vocalDensity.clamped(to: 0...1)
        self.profile = profile
    }
}

public enum TransitionKind: String, Codable, CaseIterable, Sendable {
    case smoothBlend = "Smooth Blend"
    case bassSwap = "Bass Swap"
    case rapSwitch = "Rap Switch"
    case shattaDrop = "Shatta Drop"
    case echoExit = "Echo Exit"
    case safeFade = "Safe Fade"
    case hardCut = "Hard Cut contrôlé"
}

public enum AutomationTarget: String, Codable, Sendable {
    case crossfader
    case outgoingVolume
    case incomingVolume
    case outgoingLowEQ
    case incomingLowEQ
    case outgoingFilter
    case echoAmount
}

public struct AutomationPoint: Codable, Hashable, Sendable {
    public var beat: Double
    public var value: Double

    public init(beat: Double, value: Double) {
        self.beat = beat
        self.value = value.clamped(to: 0...1)
    }
}

public struct AutomationLane: Codable, Hashable, Sendable {
    public var target: AutomationTarget
    public var points: [AutomationPoint]

    public init(target: AutomationTarget, points: [AutomationPoint]) {
        self.target = target
        self.points = points.sorted { $0.beat < $1.beat }
    }
}

public struct TransitionPlan: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var outgoingTrackID: UUID
    public var incomingTrackID: UUID
    public var kind: TransitionKind
    public var bars: Int
    public var targetBPM: Double
    public var confidence: Int
    public var reasons: [String]
    public var lanes: [AutomationLane]

    public init(
        id: UUID = UUID(),
        outgoingTrackID: UUID,
        incomingTrackID: UUID,
        kind: TransitionKind,
        bars: Int,
        targetBPM: Double,
        confidence: Int,
        reasons: [String],
        lanes: [AutomationLane]
    ) {
        self.id = id
        self.outgoingTrackID = outgoingTrackID
        self.incomingTrackID = incomingTrackID
        self.kind = kind
        self.bars = bars
        self.targetBPM = targetBPM
        self.confidence = confidence.clamped(to: 0...100)
        self.reasons = reasons
        self.lanes = lanes
    }
}

public enum AutopilotState: String, Codable, Sendable {
    case idle
    case preflight
    case loadingInitialTrack
    case playing
    case preloadingNextTrack
    case validatingNextTrack
    case waitingForTransition
    case transitioning
    case validatingTransition
    case cleaningOutgoingDeck
    case recovering
    case emergencyPlayback
    case paused
    case manualControl
    case completed
    case failed
}

public enum IncidentKind: String, Codable, CaseIterable, Sendable {
    case slowLoad
    case loadTimeout
    case wrongTrack
    case transitionMismatch
    case internetLoss
    case audioSilence
    case audioSourceLost
    case audioClipping
    case midiUnavailable
    case seratoUnavailable
    case powerDisconnected
    case checkpointMismatch
    case emergencyPlayerFailure
}

public struct Incident: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var kind: IncidentKind
    public var message: String
    public var recovered: Bool

    public init(id: UUID = UUID(), kind: IncidentKind, message: String, recovered: Bool = false) {
        self.id = id
        self.kind = kind
        self.message = message
        self.recovered = recovered
    }
}

public struct LiveSnapshot: Codable, Sendable {
    public var state: AutopilotState
    public var currentTrack: Track?
    public var nextTrack: Track?
    public var activeDeck: DeckID
    public var completedTransitions: Int
    public var totalTransitions: Int
    public var progress: Double
    public var incidents: [Incident]
    public var statusMessage: String

    public init(
        state: AutopilotState,
        currentTrack: Track?,
        nextTrack: Track?,
        activeDeck: DeckID,
        completedTransitions: Int,
        totalTransitions: Int,
        progress: Double,
        incidents: [Incident],
        statusMessage: String
    ) {
        self.state = state
        self.currentTrack = currentTrack
        self.nextTrack = nextTrack
        self.activeDeck = activeDeck
        self.completedTransitions = completedTransitions
        self.totalTransitions = totalTransitions
        self.progress = progress.clamped(to: 0...1)
        self.incidents = incidents
        self.statusMessage = statusMessage
    }
}

extension Comparable {
    fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
