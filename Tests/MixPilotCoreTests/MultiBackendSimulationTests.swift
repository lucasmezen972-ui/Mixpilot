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

@Test("Losing the active backend blocks every planned transition")
func backendLossRequiresManualControl() {
    let report = MultiBackendSimulationSuite().run(
        backends: [.djay, .rekordbox, .serato],
        trackCount: 12
    )
    let results = report.results.filter { $0.scenario == .backendLost }

    #expect(results.count == 3)
    #expect(results.allSatisfy { $0.expectedDecision == .manualControl })
    #expect(results.allSatisfy { $0.plannedTransitions == 0 })
    #expect(results.allSatisfy { $0.blockedTransitions > 0 })
    #expect(results.allSatisfy(\.passed))
}

@Test("Unconfirmed critical commands cannot enter a Live plan")
func unconfirmedCriticalCommandsBlockPlanning() {
    let report = MultiBackendSimulationSuite().run(
        backends: [.serato],
        trackCount: 12
    )
    let result = report.results.first { $0.scenario == .unconfirmedCommand }

    #expect(result?.expectedDecision == .manualControl)
    #expect(result?.plannedTransitions == 0)
    #expect((result?.blockedTransitions ?? 0) > 0)
    #expect(result?.passed == true)
}

@Test("A software version change requires complete revalidation")
func softwareVersionChangeRequiresRevalidation() {
    let report = MultiBackendSimulationSuite().run(
        backends: [.djay, .rekordbox, .serato],
        trackCount: 12
    )
    let results = report.results.filter { $0.scenario == .softwareVersionChanged }

    #expect(results.count == 3)
    #expect(results.allSatisfy { $0.expectedDecision == .requireRevalidation })
    #expect(results.allSatisfy { $0.plannedTransitions == 0 })
    #expect(results.allSatisfy(\.passed))
}
