#if os(macOS)
import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotRuntime

private actor UncertainBackendState {
    var executions = 0
    var executionDelay: Duration = .zero
    var verification: DJCommandLifecycleStatus = .unknown

    func execute() async throws {
        executions += 1
        if executionDelay > .zero {
            try await Task.sleep(for: executionDelay)
        }
    }
}

private struct UncertainBackend: DJBackend {
    let identifier: DJBackendIdentifier = .rekordbox
    let displayName = "Uncertain Backend"
    let state: UncertainBackendState

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(identifier: identifier, isInstalled: true, isRunning: true)
    }
    func capabilities() async -> DJBackendCapabilities { DJBackendCapabilities() }
    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(backend: identifier, items: [])
    }
    func readState() async throws -> DJBackendState { DJBackendState(isReliable: false) }
    func readDeckState(_ deck: DeckID) async throws -> DJDeckState { DJDeckState(deck: deck) }
    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        try await state.execute()
        return DJCommandReceipt(commandID: command.id, status: .sent)
    }
    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        let value = await state.verification
        return DJCommandVerification(status: value, confidence: .unverified, detail: "test")
    }
    func takeManualControl() async {}
}

@Test("A failed critical verification makes the idempotency key uncertain")
func failedVerificationCannotBeReplayed() async {
    let state = UncertainBackendState()
    let queue = BackendCommandQueue(backend: UncertainBackend(state: state))
    let command = DJBackendCommand(action: .loadA, idempotencyKey: "uncertain-verification")

    _ = try? await queue.execute(
        command,
        expectedEffect: .stateChanged,
        requireVerification: true
    )

    do {
        _ = try await queue.execute(
            command,
            expectedEffect: .stateChanged,
            requireVerification: false
        )
        Issue.record("An uncertain command must never be replayed.")
    } catch let error as BackendCommandQueueError {
        guard case .uncertainOutcome = error else {
            Issue.record("Unexpected queue error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(await state.executions == 1)
}

@Test("A timed-out send cannot be replayed with the same key")
func timedOutSendCannotBeReplayed() async {
    let state = UncertainBackendState()
    await state.setDelay(.milliseconds(150))
    let queue = BackendCommandQueue(
        backend: UncertainBackend(state: state),
        timeout: .milliseconds(20),
        failureThreshold: 3
    )
    let command = DJBackendCommand(action: .playA, idempotencyKey: "uncertain-timeout")

    _ = try? await queue.execute(
        command,
        expectedEffect: .playback(true, deck: .a),
        requireVerification: true
    )

    do {
        _ = try await queue.execute(
            command,
            expectedEffect: .playback(true, deck: .a),
            requireVerification: false
        )
        Issue.record("A timed-out command must never be replayed.")
    } catch let error as BackendCommandQueueError {
        guard case .uncertainOutcome = error else {
            Issue.record("Unexpected queue error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(await state.executions == 1)
}

private extension UncertainBackendState {
    func setDelay(_ value: Duration) {
        executionDelay = value
    }
}
#endif
