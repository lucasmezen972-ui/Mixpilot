import Testing
@testable import MixPilotCore

private let cliFailureSchedule: [Int: IncidentKind] = [
    8: .slowLoad,
    27: .wrongTrack,
    61: .internetLoss,
    93: .audioClipping,
    118: .audioSilence,
    151: .backendUnavailable,
]

@Test("50-track failure simulation accepts safe backend handoff")
func fiftyTrackSimulationHandsOffSafely() async throws {
    let report = try await SetSimulator().run(
        trackCount: 50,
        injectedIncidents: cliFailureSchedule
    )

    #expect(report.succeeded)
    #expect(report.finalState == .manualControl)
    #expect(report.safeManualHandoff)
    #expect(report.completedTransitions < report.transitionCount)
}

@Test("250-track failure simulation accepts safe backend handoff")
func twoHundredFiftyTrackSimulationHandsOffSafely() async throws {
    let report = try await SetSimulator().run(
        trackCount: 250,
        injectedIncidents: cliFailureSchedule
    )

    #expect(report.succeeded)
    #expect(report.finalState == .manualControl)
    #expect(report.safeManualHandoff)
    #expect(report.completedTransitions < report.transitionCount)
}
