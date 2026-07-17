#if os(macOS)
import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotRuntime

private actor QueueSafetyState {
    var executions = 0
    var verifications = 0
    var manualControls = 0
    var receiptStatus: DJCommandLifecycleStatus = .acknowledged
    var verificationStatus: DJCommandLifecycleStatus = .verified
    var confidence: DJCapabilityConfidence = .validated
    var delay: Duration = .zero

    func execute() async throws -> DJCommandLifecycleStatus {
        executions += 1
        if delay > .zero { try await Task.sleep(for: delay) }
        return receiptStatus
    }

    func verify() -> (DJCommandLifecycleStatus, DJCapabilityConfidence) {
        verifications += 1
        return (verificationStatus, confidence)
    }

    func takeManualControl() { manualControls += 1 }
}

private struct QueueSafetyBackend: DJBackend {
    let identifier: DJBackendIdentifier = .serato
    let displayName = "Queue Safety Backend"
    let state: QueueSafetyState

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
        DJCommandReceipt(commandID: command.id, status: try await state.execute())
    }

    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        let (status, confidence) = await state.verify()
        return DJCommandVerification(status: status, confidence: confidence, detail: "test")
    }

    func takeManualControl() async { await state.takeManualControl() }
}

@Test("A sent command proceeds to validated verification")
func sentCommandProceedsToVerification() async throws {
    let state = QueueSafetyState()
    await state.configure(receipt: .sent, verification: .verified, confidence: .validated)
    let queue = BackendCommandQueue(backend: QueueSafetyBackend(state: state))

    let receipt = try await queue.execute(
        DJBackendCommand(action: .playA),
        expectedEffect: .playback(true, deck: .a),
        requireVerification: true
    )

    #expect(receipt.status == .verified)
    #expect(await state.executions == 1)
    #expect(await state.verifications == 1)
}

@Test("A requested command is rejected before verification")
func requestedCommandIsRejected() async {
    let state = QueueSafetyState()
    await state.configure(receipt: .requested)
    let queue = BackendCommandQueue(backend: QueueSafetyBackend(state: state))

    do {
        _ = try await queue.execute(
            DJBackendCommand(action: .playA),
            expectedEffect: .playback(true, deck: .a),
            requireVerification: true
        )
        Issue.record("A requested receipt must not continue.")
    } catch let error as BackendCommandQueueError {
        guard case .executionNotAcknowledged(_, .requested, _) = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(await state.verifications == 0)
}

@Test("Observed evidence cannot verify a critical command")
func observedEvidenceCannotVerifyCriticalCommand() async {
    let state = QueueSafetyState()
    await state.configure(verification: .observed, confidence: .observed)
    let queue = BackendCommandQueue(backend: QueueSafetyBackend(state: state))

    do {
        _ = try await queue.execute(
            DJBackendCommand(action: .loadA),
            expectedEffect: .stateChanged,
            requireVerification: true
        )
        Issue.record("Observed evidence must remain insufficient.")
    } catch let error as BackendCommandQueueError {
        guard case .verificationRequired = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("Weak verified confidence cannot unlock a critical command")
func weakConfidenceCannotUnlockCriticalCommand() async {
    let state = QueueSafetyState()
    await state.configure(verification: .verified, confidence: .observed)
    let queue = BackendCommandQueue(backend: QueueSafetyBackend(state: state))

    do {
        _ = try await queue.execute(
            DJBackendCommand(action: .playA),
            expectedEffect: .playback(true, deck: .a),
            requireVerification: true
        )
        Issue.record("Weak confidence must remain insufficient.")
    } catch let error as BackendCommandQueueError {
        guard case .verificationRequired = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("An idempotency key is executed once")
func idempotencyKeyExecutesOnce() async throws {
    let state = QueueSafetyState()
    let queue = BackendCommandQueue(backend: QueueSafetyBackend(state: state))
    let command = DJBackendCommand(action: .playA, idempotencyKey: "same")

    _ = try await queue.execute(command, expectedEffect: .stateChanged, requireVerification: true)
    _ = try await queue.execute(command, expectedEffect: .stateChanged, requireVerification: true)

    #expect(await state.executions == 1)
}

@Test("Repeated verification failures open the circuit")
func repeatedFailuresOpenCircuit() async {
    let state = QueueSafetyState()
    await state.configure(verification: .unknown, confidence: .unverified)
    let queue = BackendCommandQueue(
        backend: QueueSafetyBackend(state: state),
        failureThreshold: 2
    )

    for index in 0..<2 {
        _ = try? await queue.execute(
            DJBackendCommand(action: .loadA, idempotencyKey: "failure-\(index)"),
            expectedEffect: .stateChanged,
            requireVerification: true
        )
    }

    #expect(await queue.currentStatus().circuitOpen)
}

@Test("Manual control opens the command circuit")
func manualControlOpensCommandCircuit() async {
    let state = QueueSafetyState()
    let queue = BackendCommandQueue(backend: QueueSafetyBackend(state: state))

    await queue.takeManualControl()

    #expect(await queue.currentStatus().circuitOpen)
    #expect(await state.manualControls == 1)
}

private extension QueueSafetyState {
    func configure(
        receipt: DJCommandLifecycleStatus? = nil,
        verification: DJCommandLifecycleStatus? = nil,
        confidence: DJCapabilityConfidence? = nil,
        delay: Duration? = nil
    ) {
        if let receipt { receiptStatus = receipt }
        if let verification { verificationStatus = verification }
        if let confidence { self.confidence = confidence }
        if let delay { self.delay = delay }
    }
}
#endif
