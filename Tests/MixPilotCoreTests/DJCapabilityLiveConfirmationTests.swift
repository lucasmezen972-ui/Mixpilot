import Testing
@testable import MixPilotCore

@Test("Only validated automated evidence confirms a Live capability")
func onlyValidatedEvidenceConfirmsLiveCapability() {
    let validated = status(confidence: .validated, validation: .automatedSuccess)
    let documented = status(confidence: .documented, validation: .automatedSuccess)
    let observed = status(confidence: .observed, validation: .automatedSuccess)
    let simulated = status(confidence: .validated, validation: .simulatedSuccess)
    let pending = status(confidence: .validated, validation: .requiresDeviceValidation)

    #expect(validated.isConfirmedForLive)
    #expect(!documented.isConfirmedForLive)
    #expect(!observed.isConfirmedForLive)
    #expect(!simulated.isConfirmedForLive)
    #expect(!pending.isConfirmedForLive)
}

@Test("Unavailable capabilities never enter a Live plan")
func unavailableCapabilityIsNeverConfirmed() {
    let value = DJCapabilityStatus(
        availability: .unavailable,
        confidence: .validated,
        validation: .automatedSuccess,
        method: .coreMIDI
    )
    #expect(!value.isConfirmedForLive)
}

private func status(
    confidence: DJCapabilityConfidence,
    validation: DJValidationStatus
) -> DJCapabilityStatus {
    DJCapabilityStatus(
        availability: .available,
        confidence: confidence,
        validation: validation,
        method: .coreMIDI
    )
}
