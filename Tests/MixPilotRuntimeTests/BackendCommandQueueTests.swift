#if os(macOS)
import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotRuntime

private actor QueueTestState {
    var executionCount = 0
    var verificationCount = 0
    var receiptStatus: DJCommandLifecycleStatus = .acknowledged
    var verification: DJCommandLifecycleStatus = .verified
    var confidence: DJCapabilityConfidence = .validated
    var delay: Duration = .zero
    var manualControlCount = 0

    func execute() async throws -> DJCommandLifecycleStatus {
        executionCount += 1
        if delay > .zero { try await Task.sleep(for: delay) }
        return receiptStatus
    }

    func verificationResult() -> (DJCommandLifecycleStatus, DJCapabilityConfidence) {
        verificationCount += 1
        return (verification, confidence)
    }

    func manualControl() {
        manualControlCount += 1
    }
}

private struct QueueTestBackend: DJBackend {
    let identifier: DJBackendIdentifier = .serato
    let displayName = "Test Backend"
    let state: QueueTestState

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
        let status = try await state.execute()
        return DJCommandReceipt(commandID: command.id, status: status)
    }

    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        let (status, confidence) = await state.verificationResult()
        return DJCommandVerification(
            status: status,
            confidence: confidence,
            detail: "test"
        )
    }

    func takeManualControl() async {
        await state.manualControl()
    }
}

@Test("The command queue deduplicates an idempotency key")
func queueDeduplicatesCommands() async throws {
    let state = QueueTestState()
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state))
    let command = DJBackendCommand(action: .playA, idempotencyKey: "same-command")

    _ = try await queue.execute(
        command,
        expectedEffect: .playback(true, deck: .a),
        requireVerification: true
    )
    _ = try await queue.execute(
        command,
        expectedEffect: .playback(true, deck: .a),
        requireVerification: true
    )

    #expect(await state.executionCount == 1)
}

@Test("Concurrent calls never execute the same idempotency key twice")
func queueRejectsConcurrentDuplicate() async throws {
    let state = QueueTestState()
    await state.setDelay(.milliseconds(150))
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state))
    let command = DJBackendCommand(action: .playA, idempotencyKey: "concurrent-command")

    async let first = queue.execute(
        command,
        expectedEffect: .playback(true, deck: .a),
        requireVerification: true
    )
    try await Task.sleep(for: .milliseconds(20))

    do {
        _ = try await queue.execute(
            command,
            expectedEffect: .playback(true, deck: .a),
            requireVerification: true
        )
        Issue.record("A duplicate command must not execute while the first is in flight.")
    } catch let error as BackendCommandQueueError {
        guard case .commandInFlight = error else {
            Issue.record("Unexpected queue error: \(error)")
            return
        }
    }

    _ = try await first
    #expect(await state.executionCount == 1)
}

@Test("A cached unverified receipt cannot satisfy a stricter replay")
func queueDoesNotUpgradeUnverifiedCachedReceipt() async throws {
    let state = QueueTestState()
    await state.setVerification(.unknown)
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state))
    let command = DJBackendCommand(action: .loadA, idempotencyKey: "strict-replay")

    _ = try await queue.execute(
        command,
        expectedEffect: .stateChanged,
        requireVerification: false
    )
    await state.setVerification(.verified)

    do {
        _ = try await queue.execute(
            command,
            expectedEffect: .stateChanged,
            requireVerification: true
        )
        Issue.record("An unverified cached receipt must not become verified by replay.")
    } catch let error as BackendCommandQueueError {
        guard case .verificationRequired = error else {
            Issue.record("Unexpected queue error: \(error)")
            return
        }
    }

    #expect(await state.executionCount == 1)
}

@Test("A failed execution receipt stops before verification")
func failedReceiptStopsBeforeVerification() async {
    let state = QueueTestState()
    await state.setReceiptStatus(.failed)
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state))

    do {
        _ = try await queue.execute(
            DJBackendCommand(action: .playA, idempotencyKey: "failed-receipt"),
            expectedEffect: .playback(true, deck: .a),
            requireVerification: true
        )
        Issue.record("A failed receipt must not continue to verification.")
    } catch let error as BackendCommandQueueError {
        guard case .executionNotAcknowledged(_, .failed, _) = error else {
            Issue.record("Unexpected queue error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    let executionCount = await state.executionCount
    let verificationCount = await state.verificationCount
    #expect(executionCount == 1)
    #expect(verificationCount == 0)
}

@Test("A sent receipt remains uncertain and is not replayed")
func sentReceiptRemainsUncertain() async {
    let state = QueueTestState()
    await state.setReceiptStatus(.sent)
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state))
    let command = DJBackendCommand(action: .browserDown, idempotencyKey: "sent-receipt")

    do {
        _ = try await queue.execute(
            command,
            expectedEffect: .stateChanged,
            requireVerification: false
        )
        Issue.record("A sent receipt must not count as an acknowledged success.")
    } catch let error as BackendCommandQueueError {
        guard case .executionNotAcknowledged(_, .sent, _) = error else {
            Issue.record("Unexpected queue error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    do {
        _ = try await queue.execute(
            command,
            expectedEffect: .stateChanged,
            requireVerification: false
        )
        Issue.record("An uncertain command must not be resent automatically.")
    } catch let error as BackendCommandQueueError {
        guard case .uncertainOutcome = error else {
            Issue.record("Unexpected replay error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected replay error: \(error)")
    }

    let executionCount = await state.executionCount
    let verificationCount = await state.verificationCount
    #expect(executionCount == 1)
    #expect(verificationCount == 0)
}

@Test("An observed effect cannot verify a critical command")
func observedEffectDoesNotVerifyCriticalCommand() async {
    let state = QueueTestState()
    await state.setVerification(.observed)
    await state.setConfidence(.observed)
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state))

    do {
        _ = try await queue.execute(
            DJBackendCommand(action: .loadA),
            expectedEffect: .stateChanged,
            requireVerification: true
        )
        Issue.record("A visible observation must not verify a critical command.")
    } catch let error as BackendCommandQueueError {
        guard case .verificationRequired = error else {
            Issue.record("Unexpected queue error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("Verified status without validated confidence remains insufficient")
func weakVerifiedConfidenceDoesNotUnlockCriticalCommand() async {
    let state = QueueTestState()
    await state.setVerification(.verified)
    await state.setConfidence(.observed)
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state))

    do {
        _ = try await queue.execute(
            DJBackendCommand(action: .playA),
            expectedEffect: .playback(true, deck: .a),
            requireVerification: true
        )
        Issue.record("VERIFIED without validated confidence must remain insufficient.")
    } catch let error as BackendCommandQueueError {
        guard case .verificationRequired = error else {
            Issue.record("Unexpected queue error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("Observed evidence may be returned for a non-critical command without becoming verified")
func observedEvidenceRemainsNonCritical() async throws {
    let state = QueueTestState()
    await state.setVerification(.observed)
    await state.setConfidence(.observed)
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state))

    let receipt = try await queue.execute(
        DJBackendCommand(action: .browserDown),
        expectedEffect: .stateChanged,
        requireVerification: false
    )

    #expect(receipt.status == .observed)
    #expect(await queue.currentStatus().lastVerifiedAt == nil)
}

@Test("An unverified critical command is refused")
func queueRequiresCriticalVerification() async {
    let state = QueueTestState()
    await state.setVerification(.unknown)
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state), failureThreshold: 2)
    let command = DJBackendCommand(action: .loadA)

    do {
        _ = try await queue.execute(command, expectedEffect: .stateChanged, requireVerification: true)
        Issue.record("The queue must refuse an unverified critical command.")
    } catch let error as BackendCommandQueueError {
        guard case .verificationRequired = error else {
            Issue.record("Unexpected queue error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("Repeated failures open the circuit breaker")
func queueOpensCircuitBreaker() async {
    let state = QueueTestState()
    await state.setVerification(.unknown)
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state), failureThreshold: 2)

    for index in 0..<2 {
        let command = DJBackendCommand(action: .loadA, idempotencyKey: "failure-\(index)")
        _ = try? await queue.execute(command, expectedEffect: .stateChanged, requireVerification: true)
    }

    #expect(await queue.currentStatus().circuitOpen)

    do {
        try await queue.trigger(.playA)
        Issue.record("An open circuit must refuse new commands.")
    } catch let error as BackendCommandQueueError {
        guard case .circuitOpen = error else {
            Issue.record("Unexpected queue error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("Taking manual control stops future automatic commands")
func manualControlOpensCircuit() async {
    let state = QueueTestState()
    let queue = BackendCommandQueue(backend: QueueTestBackend(state: state))

    await queue.takeManualControl()

    #expect(await queue.currentStatus().circuitOpen)
    #expect(await state.manualControlCount == 1)
}

private extension QueueTestState {
    func setReceiptStatus(_ value: DJCommandLifecycleStatus) {
        receiptStatus = value
    }

    func setVerification(_ value: DJCommandLifecycleStatus) {
        verification = value
    }

    func setConfidence(_ value: DJCapabilityConfidence) {
        confidence = value
    }

    func setDelay(_ value: Duration) {
        delay = value
    }
}
#endif
