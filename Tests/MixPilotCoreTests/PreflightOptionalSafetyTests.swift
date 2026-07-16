import Foundation
import Testing
@testable import MixPilotCore

private func readyInput(
    connectedToPower: Bool,
    batteryLevel: Double?,
    emergencyAudioReady: Bool,
    emergencyDuration: TimeInterval,
    djSoftware: DJSoftware = .serato,
    midiAvailable: Bool = true,
    mappingCompletion: Double = 1
) -> PreflightInput {
    PreflightInput(
        seratoRunning: true,
        accessibilityGranted: true,
        midiAvailable: midiAvailable,
        mappingCompletion: mappingCompletion,
        audioMonitorRunning: true,
        internetAvailable: true,
        connectedToPower: connectedToPower,
        batteryLevel: batteryLevel,
        emergencyAudioReady: emergencyAudioReady,
        emergencyDuration: emergencyDuration,
        projectPrepared: true,
        projectLocked: true,
        trackCount: 10,
        transitionCount: 9,
        lowConfidenceTransitionCount: 0,
        djSoftware: djSoftware
    )
}

@Test("Battery operation and missing local fallback do not block Live")
func optionalSafetyChecksDoNotBlockLive() {
    let report = PreflightEvaluator().evaluate(readyInput(
        connectedToPower: false,
        batteryLevel: 0.31,
        emergencyAudioReady: false,
        emergencyDuration: 0
    ))

    #expect(report.canStartLive)
    #expect(report.failedItems.isEmpty)
    #expect(report.items.first(where: { $0.id == "power" })?.status == .warning)
    #expect(report.items.first(where: { $0.id == "emergency" })?.status == .warning)
}

@Test("djay Automix does not require MIDI mapping")
func djayAutomixDoesNotRequireMIDI() {
    let report = PreflightEvaluator().evaluate(readyInput(
        connectedToPower: false,
        batteryLevel: 0.31,
        emergencyAudioReady: false,
        emergencyDuration: 0,
        djSoftware: .djay,
        midiAvailable: false,
        mappingCompletion: 0
    ))

    #expect(report.canStartLive)
    #expect(report.items.first(where: { $0.id == "midi" })?.status == .warning)
    #expect(report.items.first(where: { $0.id == "mapping" })?.status == .warning)
}

@Test("A genuinely critical failure still blocks Live")
func criticalFailureStillBlocksLive() {
    var input = readyInput(
        connectedToPower: false,
        batteryLevel: 0.31,
        emergencyAudioReady: false,
        emergencyDuration: 0
    )
    input.seratoRunning = false

    let report = PreflightEvaluator().evaluate(input)

    #expect(!report.canStartLive)
    #expect(report.items.first(where: { $0.id == "dj-software" })?.status == .failed)
}
