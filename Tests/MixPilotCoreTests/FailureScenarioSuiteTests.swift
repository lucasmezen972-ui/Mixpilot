import Testing
@testable import MixPilotCore

@Test("Release candidate failure matrix recovers or fails safely")
func releaseCandidateFailureMatrix() async {
    let report = await FailureScenarioSuite().run(trackCount: 12)
    #expect(report.results.count == IncidentKind.allCases.count)
    #expect(report.succeeded)
    #expect(report.failedCount == 0)
    #expect(report.results.contains { $0.scenario.incident == .checkpointMismatch && $0.finalState == .manualControl })
    #expect(report.results.contains { $0.scenario.incident == .emergencyPlayerFailure && $0.finalState == .failed })
    let recoveredResults = report.results.filter { $0.scenario.expectedOutcome == .recovered }
    #expect(recoveredResults.allSatisfy { $0.incidentRecovered })
}
