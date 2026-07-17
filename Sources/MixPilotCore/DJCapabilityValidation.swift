import Foundation

public extension DJCapabilityStatus {
    /// A capability may enter an unattended Live plan only after a successful
    /// validation with trustworthy evidence. Simulation and pending device
    /// validation never satisfy this rule.
    var isConfirmedForLive: Bool {
        guard availability == .available else { return false }
        guard validation == .automatedSuccess else { return false }
        return confidence == .validated || confidence == .documented
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
