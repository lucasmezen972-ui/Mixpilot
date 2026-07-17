#if os(macOS)
import Testing
@testable import MixPilotCore
@testable import MixPilotRuntime

private actor CadenceProbe {
    private(set) var executions = 0
    private(set) var verifications = 0

    func recordExecution() { executions += 1 }
    func recordVerification() { verifications += 1 }
}

private struct CadenceBackend: DJBackend {
    let identifier: DJBackendIdentifier = .serato
    let displayName = "Cadence Backend"
    let probe: CadenceProbe

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(identifier: identifier, isInstalled: true, isRunning: true)
    }

    func capabilities() async -> DJBackendCapabilities { DJBackendCapabilities() }

    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(backend: identifier, items: [])
    }

    func readState() async throws -> DJBackendState { DJBackendState(isReliable: true) }
    func readDeckState(_ deck: DeckID) async throws -> DJDeckState { DJDeckState(deck: deck) }

    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        await probe.recordExecution()
        return DJCommandReceipt(commandID: command.id, status: .sent)
    }

    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        await probe.recordVerification()
        return DJCommandVerification(
            status: .verified,
            confidence: .validated,
            detail: "verified"
        )
    }

    func takeManualControl() async {}
}

@Test("Continuous values do not inspect state on every frame")
func continuousValuesSkipImmediateVerification() async throws {
    let probe = CadenceProbe()
    let queue = BackendCommandQueue(backend: CadenceBackend(probe: probe))

    for step in 0..<20 {
        try await queue.set(.volumeA, value: Double(step) / 19)
    }

    #expect(await probe.executions == 20)
    #expect(await probe.verifications == 0)
}

@Test("Library navigation stays lightweight")
func libraryNavigationSkipsImmediateVerification() async throws {
    let probe = CadenceProbe()
    let queue = BackendCommandQueue(backend: CadenceBackend(probe: probe))

    try await queue.trigger(.browserDown)

    #expect(await probe.executions == 1)
    #expect(await probe.verifications == 0)
}

@Test("Playback commands still require immediate proof")
func playbackRequiresImmediateVerification() async throws {
    let probe = CadenceProbe()
    let queue = BackendCommandQueue(backend: CadenceBackend(probe: probe))

    try await queue.trigger(.playA)

    #expect(await probe.executions == 1)
    #expect(await probe.verifications == 1)
    #expect(await queue.currentStatus().lastVerifiedAt != nil)
}
#endif
