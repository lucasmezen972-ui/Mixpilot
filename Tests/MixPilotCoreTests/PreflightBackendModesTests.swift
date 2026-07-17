import Testing
@testable import MixPilotCore

@Test("Confirmed djay Automix can run without direct MIDI or mapping")
func confirmedAutomixDoesNotRequireDirectMapping() {
    let report = PreflightEvaluator().evaluate(automixInput())

    #expect(report.canStartLive)
    #expect(report.items.first { $0.id == "midi" }?.status == .warning)
    #expect(report.items.first { $0.id == "mapping" }?.status == .warning)
    #expect(report.items.first { $0.id == "power" }?.status == .warning)
    #expect(report.items.first { $0.id == "emergency" }?.status == .warning)
}

@Test("Pending Automix validation cannot enable Live")
func pendingAutomixCannotEnableLive() {
    let report = PreflightEvaluator().evaluate(automixInput(
        validation: .requiresDeviceValidation,
        confidence: .observed
    ))
    #expect(!report.canStartLive)
}

@Test("Direct Serato and rekordbox modes require MIDI and mapping")
func directBackendsRequireMapping() {
    for backend in [DJBackendIdentifier.serato, .rekordbox] {
        var input = confirmedDirectInput()
        input.backendIdentifier = backend
        input.backendEnvironment = DJBackendEnvironment(
            identifier: backend,
            isInstalled: true,
            isRunning: true,
            softwareVersion: "test"
        )
        input.midiAvailable = false
        input.mappingCompletion = 0

        let report = PreflightEvaluator().evaluate(input)
        #expect(!report.canStartLive)
        #expect(report.items.first { $0.id == "midi" }?.status == .failed)
        #expect(report.items.first { $0.id == "mapping" }?.status == .failed)
        #expect(report.items.first { $0.id == "dj-software" }?.title == backend.displayName)
    }
}

@Test("No selected backend is always a critical failure")
func noBackendBlocksLive() {
    var input = confirmedDirectInput()
    input.backendIdentifier = nil
    input.backendEnvironment = nil
    let report = PreflightEvaluator().evaluate(input)

    #expect(!report.canStartLive)
    #expect(report.items.first { $0.id == "dj-backend" }?.status == .failed)
}

private func automixInput(
    validation: DJValidationStatus = .automatedSuccess,
    confidence: DJCapabilityConfidence = .validated
) -> PreflightInput {
    var capabilities = DJBackendCapabilities()
    let automix = DJCapabilityStatus(
        availability: .available,
        confidence: confidence,
        validation: validation,
        method: .nativeAutomix
    )
    capabilities[.automix] = automix
    capabilities[.transitionTrigger] = automix
    capabilities[.trackStateReading] = DJCapabilityStatus(
        availability: .available,
        confidence: confidence,
        validation: validation,
        method: .accessibility
    )

    return PreflightInput(
        backendIdentifier: .djay,
        backendEnvironment: DJBackendEnvironment(
            identifier: .djay,
            isInstalled: true,
            isRunning: true,
            softwareVersion: "test"
        ),
        backendCapabilities: capabilities,
        accessibilityGranted: true,
        midiAvailable: false,
        mappingCompletion: 0,
        audioMonitorRunning: true,
        internetAvailable: true,
        connectedToPower: false,
        batteryLevel: 0.31,
        emergencyAudioReady: false,
        emergencyDuration: 0,
        projectPrepared: true,
        projectLocked: true,
        trackCount: 10,
        transitionCount: 9,
        lowConfidenceTransitionCount: 0
    )
}
