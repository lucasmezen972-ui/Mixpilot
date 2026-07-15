import Testing
@testable import MixPilotCore

@Test("Complete preflight allows live mode")
func completePreflightAllowsLive() {
    let report = PreflightEvaluator().evaluate(PreflightInput(
        seratoRunning: true,
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
        trackCount: 50,
        transitionCount: 49,
        lowConfidenceTransitionCount: 0
    ))

    #expect(report.canStartLive)
    #expect(report.failedItems.isEmpty)
}

@Test("Missing emergency library blocks unattended live mode")
func missingEmergencyLibraryBlocksLive() {
    let report = PreflightEvaluator().evaluate(PreflightInput(
        seratoRunning: true,
        accessibilityGranted: true,
        midiAvailable: true,
        mappingCompletion: 1,
        audioMonitorRunning: true,
        internetAvailable: true,
        connectedToPower: true,
        batteryLevel: 1,
        emergencyAudioReady: false,
        emergencyDuration: 0,
        projectPrepared: true,
        projectLocked: true,
        trackCount: 10,
        transitionCount: 9,
        lowConfidenceTransitionCount: 0
    ))

    #expect(!report.canStartLive)
    #expect(report.failedItems.contains { $0.id == "emergency" })
}

@Test("Low confidence transitions warn but do not block")
func lowConfidenceTransitionsOnlyWarn() {
    let report = PreflightEvaluator().evaluate(PreflightInput(
        seratoRunning: true,
        accessibilityGranted: true,
        midiAvailable: true,
        mappingCompletion: 1,
        audioMonitorRunning: true,
        internetAvailable: true,
        connectedToPower: true,
        batteryLevel: 1,
        emergencyAudioReady: true,
        emergencyDuration: 1_800,
        projectPrepared: true,
        projectLocked: true,
        trackCount: 10,
        transitionCount: 9,
        lowConfidenceTransitionCount: 3
    ))

    #expect(report.canStartLive)
    #expect(report.warningItems.contains { $0.id == "confidence" })
}
