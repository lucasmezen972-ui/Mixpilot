#if os(macOS)
import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotRuntime

private actor ManualHandoffProbe {
    private(set) var manualControlCount = 0
    private(set) var events: [String] = []

    func recordManualControl() {
        manualControlCount += 1
    }

    func record(_ event: LiveRuntimeEvent) {
        switch event {
        case .transitionStarted:
            events.append("transition-started")
        case .transitionCompleted:
            events.append("transition-completed")
        case .manualControl:
            events.append("manual-control")
        default:
            break
        }
    }

    func hasTransitionStarted() -> Bool {
        events.contains("transition-started")
    }
}

private struct ManualHandoffBackend: DJBackend {
    let identifier: DJBackendIdentifier = .serato
    let displayName = "Manual Handoff Backend"
    let probe: ManualHandoffProbe

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(
            identifier: identifier,
            isInstalled: true,
            isRunning: true,
            softwareVersion: "test"
        )
    }

    func capabilities() async -> DJBackendCapabilities {
        var result = DJBackendCapabilities()
        let confirmed = DJCapabilityStatus(
            availability: .available,
            confidence: .validated,
            validation: .automatedSuccess,
            method: .coreMIDI
        )
        for capability in DJCapability.allCases {
            result[capability] = confirmed
        }
        return result
    }

    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(backend: identifier, items: [])
    }

    func readState() async throws -> DJBackendState {
        DJBackendState(isReliable: true)
    }

    func readDeckState(_ deck: DeckID) async throws -> DJDeckState {
        DJDeckState(deck: deck, isPlaying: true)
    }

    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        DJCommandReceipt(commandID: command.id, status: .acknowledged)
    }

    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        DJCommandVerification(
            status: .verified,
            confidence: .validated,
            detail: "Verified by the test backend"
        )
    }

    func takeManualControl() async {
        await probe.recordManualControl()
    }
}

@Test("Manual control requested during a transition waits for the safe boundary")
func manualControlDuringTransitionUsesCooperativeHandoff() async throws {
    var project = manualHandoffProject()
    project.lock()

    let probe = ManualHandoffProbe()
    let coordinator = LiveAutopilotCoordinator(
        backend: ManualHandoffBackend(probe: probe),
        checkpointStore: nil
    )
    let runTask = Task {
        try await coordinator.run(
            project: project,
            configuration: LiveRuntimeConfiguration(
                preloadLeadSeconds: 5,
                loadSettleSeconds: 0.5,
                framesPerSecond: 30,
                speedMultiplier: 80,
                strictTrackValidation: true
            ),
            onEvent: { event in await probe.record(event) }
        )
    }

    for _ in 0..<500 {
        if await probe.hasTransitionStarted() { break }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(await probe.hasTransitionStarted())

    let decision = await coordinator.requestManualControl()
    #expect(decision.accepted)

    try await runTask.value

    let events = await probe.events
    #expect(events == ["transition-started", "manual-control"])
    #expect(await probe.manualControlCount == 1)
}

private func manualHandoffProject() -> SetProject {
    let tracks = [
        Track(
            title: "Track A",
            artist: "Artist A",
            bpm: 120,
            duration: 30,
            energy: 0.5,
            vocalDensity: 0.2,
            profile: .afro
        ),
        Track(
            title: "Track B",
            artist: "Artist B",
            bpm: 122,
            duration: 30,
            energy: 0.7,
            vocalDensity: 0.2,
            profile: .afro
        )
    ]
    return SetPreparationEngine().prepare(
        name: "Manual handoff",
        tracks: tracks,
        backend: .serato
    )
}
#endif
