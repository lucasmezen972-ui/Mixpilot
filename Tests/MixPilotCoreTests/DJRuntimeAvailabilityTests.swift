import Testing
@testable import MixPilotCore

@Test("Revoking Accessibility invalidates only AX-backed capabilities")
func revokedAccessibilityInvalidatesAXCapabilities() {
    var capabilities = DJBackendCapabilities()
    capabilities[.deckStateReading] = confirmedStatus(method: .accessibility)
    capabilities[.playPause] = confirmedStatus(method: .coreMIDI)

    let runtime = capabilities.applyingRuntimeAvailability(accessibilityGranted: false)

    #expect(!runtime[.deckStateReading].isConfirmedForLive)
    #expect(runtime[.deckStateReading].availability == .unavailable)
    #expect(runtime[.deckStateReading].validation == .requiresDeviceValidation)
    #expect(runtime[.deckStateReading].lastValidatedAt == capabilities[.deckStateReading].lastValidatedAt)
    #expect(runtime[.playPause].isConfirmedForLive)
}

@Test("Granted Accessibility preserves validated capabilities")
func grantedAccessibilityPreservesCapabilities() {
    var capabilities = DJBackendCapabilities()
    capabilities[.trackStateReading] = confirmedStatus(method: .accessibility)

    let runtime = capabilities.applyingRuntimeAvailability(accessibilityGranted: true)

    #expect(runtime[.trackStateReading] == capabilities[.trackStateReading])
    #expect(runtime[.trackStateReading].isConfirmedForLive)
}

private func confirmedStatus(method: DJIntegrationMethod) -> DJCapabilityStatus {
    DJCapabilityStatus(
        availability: .available,
        confidence: .validated,
        validation: .automatedSuccess,
        method: method,
        lastValidatedAt: .distantPast,
        testedSoftwareVersion: "test"
    )
}
