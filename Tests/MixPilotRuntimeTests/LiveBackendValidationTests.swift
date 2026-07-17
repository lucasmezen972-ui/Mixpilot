#if os(macOS)
import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotRuntime

private actor LiveValidationProbe {
    private(set) var commandCount = 0

    func recordCommand() {
        commandCount += 1
    }
}

private struct StateBlindBackend: DJBackend {
    let identifier: DJBackendIdentifier = .rekordbox
    let displayName = "State Blind Backend"
    let probe: LiveValidationProbe

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
        result[.trackLoading] = confirmed
        result[.playPause] = confirmed
        result[.channelVolume] = confirmed
        result[.sync] = confirmed
        result[.deckStateReading] = DJCapabilityStatus(
            availability: .partiallyAvailable,
            confidence: .observed,
            validation: .requiresDeviceValidation,
            method: .accessibility
        )
        result[.trackStateReading] = DJCapabilityStatus(
            availability: .partiallyAvailable,
            confidence: .observed,
            validation: .requiresDeviceValidation,
            method: .accessibility
        )
        return result
    }

    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(
            backend: identifier,
            items: [
                DJBackendValidationItem(
                    id: "commands",
                    title: "Commandes",
                    detail: "Les commandes sont configurées.",
                    status: .automatedSuccess
                )
            ]
        )
    }

    func readState() async throws -> DJBackendState {
        DJBackendState(isReliable: false)
    }

    func readDeckState(_ deck: DeckID) async throws -> DJDeckState {
        throw DJBackendError.stateUnavailable("État non vérifié")
    }

    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        await probe.recordCommand()
        return DJCommandReceipt(commandID: command.id, status: .sent)
    }

    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        DJCommandVerification(
            status: .unknown,
            confidence: .unverified,
            detail: "État non vérifié"
        )
    }

    func takeManualControl() async {}
}

@Test("Full Autopilot sends no command without reliable state reading")
func fullAutopilotBlocksBeforeFirstCommandWithoutReliableState() async throws {
    let tracks = [
        Track(
            title: "Track A",
            artist: "Artist A",
            bpm: 120,
            duration: 180,
            energy: 0.5,
            vocalDensity: 0.2,
            profile: .afro
        ),
        Track(
            title: "Track B",
            artist: "Artist B",
            bpm: 121,
            duration: 180,
            energy: 0.6,
            vocalDensity: 0.2,
            profile: .afro
        )
    ]
    var project = SetPreparationEngine().prepare(name: "Test", tracks: tracks)
    project.lock()

    let probe = LiveValidationProbe()
    let coordinator = LiveAutopilotCoordinator(
        backend: StateBlindBackend(probe: probe),
        checkpointStore: nil
    )

    do {
        try await coordinator.run(
            project: project,
            configuration: LiveRuntimeConfiguration(
                preloadLeadSeconds: 5,
                loadSettleSeconds: 0.5,
                framesPerSecond: 5,
                speedMultiplier: 100,
                strictTrackValidation: true
            ),
            onEvent: { _ in }
        )
        Issue.record("The Live should be blocked before sending a command.")
    } catch let error as LiveRuntimeError {
        guard case .configurationBlocked(let detail) = error else {
            Issue.record("Unexpected Live error: \(error)")
            return
        }
        #expect(detail.contains("état réel des decks"))
    }

    #expect(await probe.commandCount == 0)
}
#endif
