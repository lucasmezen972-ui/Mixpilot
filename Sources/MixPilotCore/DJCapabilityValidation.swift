import Foundation

public extension DJCapabilityStatus {
    /// A capability may enter an unattended Live plan only after a successful
    /// validation with direct, trustworthy evidence. Documentation, observation,
    /// simulation and pending device validation never satisfy this rule.
    var isConfirmedForLive: Bool {
        availability == .available &&
            validation == .automatedSuccess &&
            confidence == .validated
    }
}

public extension DJBackendCapabilities {
    func confirmsForLive(_ capability: DJCapability) -> Bool {
        self[capability].isConfirmedForLive
    }

    func confirmsAllForLive(_ capabilities: Set<DJCapability>) -> Bool {
        capabilities.allSatisfy(confirmsForLive)
    }
}
