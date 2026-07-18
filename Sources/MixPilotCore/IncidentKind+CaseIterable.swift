import Foundation

public extension IncidentKind {
    /// Only current incident kinds are offered to new runtime scenarios.
    /// `seratoUnavailable` remains decodable for historical checkpoints but is
    /// intentionally excluded from new-case iteration.
    static var allCases: [IncidentKind] {
        [
            .slowLoad,
            .loadTimeout,
            .wrongTrack,
            .transitionMismatch,
            .internetLoss,
            .audioSilence,
            .audioSourceLost,
            .audioClipping,
            .midiUnavailable,
            .backendUnavailable,
            .powerDisconnected,
            .checkpointMismatch,
            .emergencyPlayerFailure,
        ]
    }
}
