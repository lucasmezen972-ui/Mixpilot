import Testing
@testable import MixPilotCore

@Test("Legacy preflight without an explicit software never invents Serato")
func legacyPreflightDoesNotSelectBackend() {
    let report = PreflightEvaluator().evaluate(legacyInput())

    #expect(!report.canStartLive)
    #expect(report.items.first { $0.id == "dj-backend" }?.status == .failed)
}

@Test("Legacy direct control still requires device revalidation")
func legacyDirectControlCannotBecomeLiveReady() {
    let report = PreflightEvaluator().evaluate(legacyInput(software: .serato))

    #expect(!report.canStartLive)
    #expect(report.items.first { $0.id == "capability-playPause" }?.status == .failed)
}

@Test("Legacy Automix still requires device revalidation")
func legacyAutomixCannotBecomeLiveReady() {
    let report = PreflightEvaluator().evaluate(legacyInput(software: .djay))

    #expect(!report.canStartLive)
}

private func legacyInput(software: DJSoftware? = nil) -> PreflightInput {
    PreflightInput(
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
        trackCount: 10,
        transitionCount: 9,
        lowConfidenceTransitionCount: 0,
        djSoftware: software
    )
}
