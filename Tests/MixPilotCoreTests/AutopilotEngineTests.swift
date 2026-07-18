import Testing
@testable import MixPilotCore

@Test("A fifty-track simulated set completes")
func fiftyTrackSetCompletes() async throws {
    let report = try await SetSimulator().run(trackCount: 50)
    #expect(report.finalState == .completed)
    #expect(report.completedTransitions == 49)
    #expect(report.succeeded)
}

@Test("Injected incidents recover or hand control back safely")
func incidentsRecover() async throws {
    let report = try await SetSimulator().run(
        trackCount: 20,
        injectedIncidents: [5: .slowLoad, 20: .internetLoss, 40: .audioSilence]
    )
    #expect(report.finalState == .manualControl)
    #expect(report.incidentCount == 3)
    #expect(report.recoveredIncidentCount == 3)
    #expect(report.safeManualHandoff)
    #expect(report.succeeded)
}

@Test("Invalid plan count is rejected")
func invalidPlanCountRejected() async {
    let engine = AutopilotEngine()
    let tracks = SetSimulator().makeTracks(count: 3)
    do {
        try await engine.load(tracks: tracks, plans: [])
        Issue.record("Expected invalid plan count error")
    } catch let error as AutopilotError {
        #expect(error == .invalidPlanCount(expected: 2, actual: 0))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
