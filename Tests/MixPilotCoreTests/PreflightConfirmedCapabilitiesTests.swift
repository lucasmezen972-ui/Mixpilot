import Testing
@testable import MixPilotCore

@Test("Confirmed direct control allows Live")
func confirmedDirectPreflightAllowsLive() {
    let report = PreflightEvaluator().evaluate(confirmedDirectInput())
    #expect(report.canStartLive)
    #expect(report.failedItems.isEmpty)
}

@Test("A simulated critical command does not allow Live")
func simulatedCommandCannotEnableLive() {
    var input = confirmedDirectInput()
    input.backendCapabilities[.playPause] = DJCapabilityStatus(
        availability: .available,
        confidence: .observed,
        validation: .simulatedSuccess,
        method: .coreMIDI
    )
    let report = PreflightEvaluator().evaluate(input)
    #expect(!report.canStartLive)
    #expect(report.items.first { $0.id == "capability-playPause" }?.status == .failed)
}

@Test("Direct control without reliable state reading is blocked")
func directControlRequiresStateReading() {
    var input = confirmedDirectInput()
    input.backendCapabilities[.deckStateReading] = DJCapabilityStatus(
        availability: .partiallyAvailable,
        confidence: .observed,
        validation: .requiresDeviceValidation,
        method: .accessibility
    )
    let report = PreflightEvaluator().evaluate(input)
    #expect(!report.canStartLive)
    #expect(report.items.first { $0.id == "capability-state-reading" }?.status == .failed)
}

func confirmedDirectInput() -> PreflightInput {
    var capabilities = DJBackendCapabilities()
    let command = confirmedStatus(.coreMIDI)
    capabilities[.trackLoading] = command
    capabilities[.playPause] = command
    capabilities[.channelVolume] = command
    capabilities[.sync] = command
    capabilities[.mappingImport] = confirmedStatus(.importedMapping)
    capabilities[.deckStateReading] = confirmedStatus(.accessibility)
    return PreflightInput(
        backendIdentifier: .serato,
        backendEnvironment: DJBackendEnvironment(
            identifier: .serato,
            isInstalled: true,
            isRunning: true,
            softwareVersion: "test"
        ),
        backendCapabilities: capabilities,
        accessibilityGranted: true,
        midiAvailable: true,
        mappingCompletion: 1,
        audioMonitorRunning: true,
        internetAvailable: true,
        connectedToPower: true,
        batteryLevel: 1,
        emergencyAudioReady: true,
        emergencyDuration: 2_400,
        projectPrepared: true,
        projectLocked: true,
        trackCount: 10,
        transitionCount: 9,
        lowConfidenceTransitionCount: 0
    )
}

func confirmedStatus(_ method: DJIntegrationMethod) -> DJCapabilityStatus {
    DJCapabilityStatus(
        availability: .available,
        confidence: .validated,
        validation: .automatedSuccess,
        method: method
    )
}
