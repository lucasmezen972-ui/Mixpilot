#if os(macOS)
import Foundation
import MixPilotCore

public enum BackendCommandQueueError: Error, LocalizedError, Sendable {
    case circuitOpen
    case verificationRequired(DJControlAction, String)

    public var errorDescription: String? {
        switch self {
        case .circuitOpen:
            "Le contrôle automatique a été suspendu après plusieurs réponses incertaines. Reprends la main et vérifie le logiciel DJ."
        case .verificationRequired(_, let detail):
            detail
        }
    }
}

public struct BackendCommandQueueStatus: Codable, Hashable, Sendable {
    public var consecutiveFailures: Int
    public var circuitOpen: Bool
    public var lastCommandAt: Date?
    public var lastVerifiedAt: Date?

    public init(
        consecutiveFailures: Int = 0,
        circuitOpen: Bool = false,
        lastCommandAt: Date? = nil,
        lastVerifiedAt: Date? = nil
    ) {
        self.consecutiveFailures = consecutiveFailures
        self.circuitOpen = circuitOpen
        self.lastCommandAt = lastCommandAt
        self.lastVerifiedAt = lastVerifiedAt
    }
}

public actor BackendCommandQueue: DJCommandSending {
    private let backend: any DJBackend
    private let timeout: Duration
    private let failureThreshold: Int

    private var completed: [String: DJCommandReceipt] = [:]
    private var sequence: UInt64 = 0
    private var status = BackendCommandQueueStatus()

    public init(
        backend: any DJBackend,
        timeout: Duration = .seconds(4),
        failureThreshold: Int = 3
    ) {
        self.backend = backend
        self.timeout = timeout
        self.failureThreshold = max(1, failureThreshold)
    }

    public func trigger(_ action: DJControlAction) async throws {
        let expected = expectedEffect(for: action, value: nil)
        _ = try await execute(
            DJBackendCommand(
                action: action,
                idempotencyKey: nextIdempotencyKey(action)
            ),
            expectedEffect: expected,
            requireVerification: requiresImmediateVerification(action)
        )
    }

    public func set(_ action: DJControlAction, value: Double) async throws {
        _ = try await execute(
            DJBackendCommand(
                action: action,
                normalizedValue: value,
                idempotencyKey: nextIdempotencyKey(action)
            ),
            expectedEffect: expectedEffect(for: action, value: value),
            requireVerification: false
        )
    }

    @discardableResult
    public func execute(
        _ command: DJBackendCommand,
        expectedEffect: DJExpectedEffect,
        requireVerification: Bool
    ) async throws -> DJCommandReceipt {
        guard !status.circuitOpen else { throw BackendCommandQueueError.circuitOpen }
        if let existing = completed[command.idempotencyKey] {
            return existing
        }

        do {
            let receipt = try await withTimeout(timeout) {
                try await self.backend.execute(command)
            }
            status.lastCommandAt = Date()

            let verification = try await withTimeout(timeout) {
                try await self.backend.verify(command: command, expectedEffect: expectedEffect)
            }

            if verification.status == .verified || verification.status == .observed {
                status.consecutiveFailures = 0
                status.lastVerifiedAt = Date()
                let verified = DJCommandReceipt(
                    commandID: command.id,
                    status: verification.status,
                    detail: verification.detail
                )
                completed[command.idempotencyKey] = verified
                trimCompletedCommands()
                return verified
            }

            if requireVerification {
                registerFailure()
                throw BackendCommandQueueError.verificationRequired(
                    command.action,
                    "La commande \(humanName(command.action)) n’a pas pu être confirmée. MixPilot suspend cette étape au lieu de continuer à l’aveugle."
                )
            }

            status.consecutiveFailures = 0
            completed[command.idempotencyKey] = receipt
            trimCompletedCommands()
            return receipt
        } catch {
            registerFailure()
            throw error
        }
    }

    public func currentStatus() -> BackendCommandQueueStatus { status }

    public func resetCircuitAfterManualValidation() {
        status.consecutiveFailures = 0
        status.circuitOpen = false
    }

    public func takeManualControl() async {
        status.circuitOpen = true
        await backend.takeManualControl()
    }

    private func registerFailure() {
        status.consecutiveFailures += 1
        if status.consecutiveFailures >= failureThreshold {
            status.circuitOpen = true
        }
    }

    private func nextIdempotencyKey(_ action: DJControlAction) -> String {
        sequence &+= 1
        return "runtime|\(backend.identifier.rawValue)|\(action.rawValue)|\(sequence)"
    }

    private func expectedEffect(
        for action: DJControlAction,
        value: Double?
    ) -> DJExpectedEffect {
        if let value {
            return .normalizedValue(
                value,
                capability: action.requiredCapability,
                deck: deck(for: action)
            )
        }
        switch action {
        case .playA: .playback(true, deck: .a)
        case .playB: .playback(true, deck: .b)
        case .pauseA: .playback(false, deck: .a)
        case .pauseB: .playback(false, deck: .b)
        default: .stateChanged
        }
    }

    private func requiresImmediateVerification(_ action: DJControlAction) -> Bool {
        switch action {
        case .playA, .playB, .pauseA, .pauseB, .loadA, .loadB:
            true
        default:
            false
        }
    }

    private func deck(for action: DJControlAction) -> DeckID? {
        switch action {
        case .playA, .pauseA, .cueA, .syncA, .loadA, .volumeA,
             .lowEQA, .midEQA, .highEQA, .filterA, .pitchA,
             .echoA, .echoAmountA, .loopA, .exitLoopA:
            .a
        case .playB, .pauseB, .cueB, .syncB, .loadB, .volumeB,
             .lowEQB, .midEQB, .highEQB, .filterB, .pitchB,
             .echoB, .echoAmountB, .loopB, .exitLoopB:
            .b
        case .browserUp, .browserDown, .browserFocus, .crossfader:
            nil
        }
    }

    private func humanName(_ action: DJControlAction) -> String {
        switch action.requiredCapability {
        case .playPause: "Lecture / Pause"
        case .trackLoading: "Chargement"
        case .cue: "Cue"
        case .sync: "Synchronisation"
        case .channelVolume: "Volume"
        case .eqLow, .eqMid, .eqHigh: "Égalisation"
        case .filter: "Filtre"
        case .crossfader: "Crossfader"
        case .tempo: "Tempo"
        case .loop: "Boucle"
        case .effects: "Effet"
        default: action.rawValue
        }
    }

    private func trimCompletedCommands() {
        guard completed.count > 500 else { return }
        completed.removeAll(keepingCapacity: true)
    }

    private func withTimeout<T: Sendable>(
        _ duration: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw DJBackendError.commandTimedOut(.browserFocus)
            }
            guard let result = try await group.next() else {
                throw DJBackendError.stateUnavailable("La commande n’a renvoyé aucun résultat.")
            }
            group.cancelAll()
            return result
        }
    }
}
#endif
