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

    func confirmedForLiveOnly() -> DJBackendCapabilities {
        var result = DJBackendCapabilities()
        for capability in DJCapability.allCases {
            let current = self[capability]
            result[capability] = current.isConfirmedForLive
                ? current
                : DJCapabilityStatus(
                    availability: .unavailable,
                    confidence: current.confidence,
                    validation: current.validation,
                    method: current.method,
                    lastValidatedAt: current.lastValidatedAt,
                    testedSoftwareVersion: current.testedSoftwareVersion,
                    mappingVersion: current.mappingVersion,
                    controllerName: current.controllerName,
                    reason: current.reason ?? "Cette fonction doit encore être confirmée sur ce Mac.",
                    userAction: current.userAction
                )
        }
        return result
    }
}
