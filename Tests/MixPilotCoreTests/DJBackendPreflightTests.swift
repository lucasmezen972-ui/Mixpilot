import Testing
@testable import MixPilotCore

private func readyInput(
    software: DJSoftware,
    midiAvailable: Bool,
    mappingCompletion: Double,
    connectedToPower: Bool = false,
    emergencyAudioReady: Bool = false
) -> PreflightInput {
    PreflightInput(
        seratoRunning: true,
        accessibilityGranted: true,
        midiAvailable: midiAvailable,
        mappingCompletion: mappingCompletion,
        audioMonitorRunning: true,
        internetAvailable: true,
        connectedToPower: connectedToPower,
        batteryLevel: 0.31,
        emergencyAudioReady: emergencyAudioReady,
        emergencyDuration: emergencyAudioReady ? 1_800 : 0,
        projectPrepared: true,
        projectLocked: true,
        trackCount: 10,
        transitionCount: 9,
        lowConfidenceTransitionCount: 0,
        djSoftware: software
    )
}

@Test("djay Automix can start without MIDI, power cable, or local rescue music")
func djayAutomixOptionalRequirementsDoNotBlock() {
    let report = PreflightEvaluator().evaluate(readyInput(
        software: .djay,
        midiAvailable: false,
        mappingCompletion: 0
    ))

    #expect(report.canStartLive)
    #expect(report.items.first { $0.id == "midi" }?.status == .warning)
    #expect(report.items.first { $0.id == "mapping" }?.status == .warning)
    #expect(report.items.first { $0.id == "power" }?.status == .warning)
    #expect(report.items.first { $0.id == "emergency" }?.status == .warning)
}

@Test("Serato direct control still requires MIDI and mapping")
func seratoStillRequiresDirectControlPrerequisites() {
    let report = PreflightEvaluator().evaluate(readyInput(
        software: .serato,
        midiAvailable: false,
        mappingCompletion: 0
    ))

    #expect(!report.canStartLive)
    #expect(report.items.first { $0.id == "midi" }?.status == .failed)
    #expect(report.items.first { $0.id == "mapping" }?.status == .failed)
}

@Test("Battery and local rescue remain warnings for Serato")
func optionalSafetyItemsNeverBlockSerato() {
    let report = PreflightEvaluator().evaluate(readyInput(
        software: .serato,
        midiAvailable: true,
        mappingCompletion: 1
    ))

    #expect(report.canStartLive)
    #expect(report.items.first { $0.id == "power" }?.severity == .warning)
    #expect(report.items.first { $0.id == "emergency" }?.severity == .warning)
}
