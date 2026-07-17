import Testing
@testable import MixPilotCore

@Test("The multi-backend simulation covers all official backends")
func simulationCoversOfficialBackends() {
    let report = MultiBackendSimulationSuite().run(trackCount: 20)

    #expect(report.succeeded)
    #expect(Set(report.results.map(\.backend)) == Set(DJBackendIdentifier.allCases))
    #expect(report.results.allSatisfy { $0.validationStatus == .simulatedSuccess })
}

@Test("Missing state reading blocks the full Autopilot in simulation")
func simulationBlocksStateBlindBackends() {
    let report = MultiBackendSimulationSuite().run(
        backends: [.djay, .rekordbox, .serato],
        trackCount: 12
    )
    let results = report.results.filter { $0.scenario == .noStateReading }

    #expect(results.count == 3)
    #expect(results.allSatisfy { $0.expectedDecision == .blockBeforeLive })
    #expect(results.allSatisfy(\.passed))
}

@Test("Internet and iPhone loss remain local non-blocking scenarios")
func cloudAndRemoteLossDoNotStopPreparedPlans() {
    let report = MultiBackendSimulationSuite().run(
        backends: [.serato],
        trackCount: 12
    )
    let localLossResults = report.results.filter {
        $0.scenario == .internetLost || $0.scenario == .iphoneLost
    }

    #expect(localLossResults.count == 2)
    #expect(localLossResults.allSatisfy { $0.expectedDecision == .continueLocally })
    #expect(localLossResults.allSatisfy { $0.blockedTransitions == 0 })
}

@Test("An incompatible mapping blocks transitions before Live")
func incompatibleMappingBlocksPlanning() {
    let report = MultiBackendSimulationSuite().run(
        backends: [.rekordbox],
        trackCount: 12
    )
    let result = report.results.first { $0.scenario == .mappingIncompatible }

    #expect(result?.expectedDecision == .blockBeforeLive)
    #expect((result?.blockedTransitions ?? 0) > 0)
    #expect(result?.passed == true)
}
