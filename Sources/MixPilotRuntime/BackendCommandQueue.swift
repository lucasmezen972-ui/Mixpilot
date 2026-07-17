#if os(macOS)
import Foundation
import MixPilotCore

public enum BackendCommandQueueError: Error, LocalizedError, Sendable {
    case circuitOpen
    case commandInFlight
    case uncertainOutcome(DJControlAction)
    case executionNotAcknowledged(DJControlAction, DJCommandLifecycleStatus, String?)
    case verificationRequired(DJControlAction, String)

    public var errorDescription: String? {
        switch self {
        case .circuitOpen:
            "Le contrôle automatique a été suspendu après plusieurs réponses incertaines. Reprends la main et vérifie le logiciel DJ."
        case .commandInFlight:
            "Cette commande est déjà en cours. MixPilot n’envoie pas de doublon."
        case .uncertainOutcome:
            "Cette commande a peut-être déjà été exécutée. MixPilot refuse de la renvoyer sans vérification manuelle."
        case .executionNotAcknowledged(let action, let status, let detail):
            detail ?? "La commande \(action.rawValue) n’a pas été confirmée par le logiciel DJ (état \(status.rawValue)). MixPilot suspend cette étape."
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
    private let backendIdentifier: DJBackendIdentifier
    private let timeout: Duration
    private let failureThreshold: Int

    private var completed: [String: DJCommandReceipt] = [:]
    private var completedOrder: [String] = []
    private var inFlightKeys: Set<String> = []
    private var uncertainKeys: Set<String> = []
    private var sequence: UInt64 = 0
    private var status = BackendCommandQueueStatus()

    public init(
        backend: any DJBackend,
        timeout: Duration = .seconds(4),
        failureThreshold: Int = 3
    ) {
        self.backend = backend
        self.backendIdentifier = backend.identifier
        self.timeout = timeout
        self.failureThreshold = max(1, failureThreshold)
    }

    public func trigger(_ action: DJControlAction) async throws {
        _ = try await execute(
            DJBackendCommand(
                action: action,
                idempotencyKey: nextIdempotencyKey(action)
            ),
            expectedEffect: expectedEffect(for: action, value: nil),
            requireVerification: false
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

        if uncertainKeys.contains(command.idempotencyKey) {
            throw BackendCommandQueueError.uncertainOutcome(command.action)
        }

        if let existing = completed[command.idempotencyKey] {
            if !requireVerification || isStrictlyVerified(existing) {
                return existing
            }
            throw BackendCommandQueueError.verificationRequired(
                command.action,
                "Cette commande avait été envoyée auparavant sans preuve suffisante. Relance la validation du logiciel DJ avant de continuer."
            )
        }

        guard !inFlightKeys.contains(command.idempotencyKey) else {
            throw BackendCommandQueueError.commandInFlight
        }
        inFlightKeys.insert(command.idempotencyKey)
        defer { inFlightKeys.remove(command.idempotencyKey) }

        let backend = self.backend
        do {
            let receipt = try await withTimeout(timeout, action: command.action) {
                try await backend.execute(command)
            }
            status.lastCommandAt = Date()

            guard executionWasAcknowledged(receipt.status) else {
                throw BackendCommandQueueError.executionNotAcknowledged(
                    command.action,
                    receipt.status,
                    receipt.detail
                )
            }

            let verification: DJCommandVerification?
            do {
                verification = try await withTimeout(timeout, action: command.action) {
                    try await backend.verify(command: command, expectedEffect: expectedEffect)
                }
            } catch DJBackendError.stateUnavailable {
                verification = nil
            }

            if let verification,
               verification.status == .verified,
               verification.confidence == .validated {
                status.consecutiveFailures = 0
                status.lastVerifiedAt = Date()
                let verified = DJCommandReceipt(
                    commandID: command.id,
                    status: .verified,
                    detail: verification.detail
                )
                clearUncertain(command.idempotencyKey)
                remember(verified, key: command.idempotencyKey)
                return verified
            }

            if let verification,
               !requireVerification,
               verification.status == .observed || verification.status == .verified {
                status.consecutiveFailures = 0
                let observed = DJCommandReceipt(
                    commandID: command.id,
                    status: .observed,
                    detail: verification.detail
                )
                clearUncertain(command.idempotencyKey)
                remember(observed, key: command.idempotencyKey)
                return observed
            }

            guard !requireVerification else {
                remember(receipt, key: command.idempotencyKey)
                markUncertain(command.idempotencyKey)
                throw BackendCommandQueueError.verificationRequired(
                    command.action,
                    "La commande \(humanName(command.action)) n’a pas pu être confirmée par une preuve fiable. MixPilot suspend cette étape au lieu de continuer à l’aveugle."
                )
            }

            status.consecutiveFailures = 0
            clearUncertain(command.idempotencyKey)
            remember(receipt, key: command.idempotencyKey)
            return receipt
        } catch {
            markUncertain(command.idempotencyKey)
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

    private func executionWasAcknowledged(_ status: DJCommandLifecycleStatus) -> Bool {
        switch status {
        case .acknowledged, .observed, .verified:
            true
        case .requested, .sent, .failed, .unknown:
            false
        }
    }

    private func nextIdempotencyKey(_ action: DJControlAction) -> String {
        sequence &+= 1
        return "runtime|\(backendIdentifier.rawValue)|\(action.rawValue)|\(sequence)"
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
        return switch action {
        case .playA: .playback(true, deck: .a)
        case .playB: .playback(true, deck: .b)
        case .pauseA: .playback(false, deck: .a)
        case .pauseB: .playback(false, deck: .b)
        default: .stateChanged
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

    private func isStrictlyVerified(_ receipt: DJCommandReceipt) -> Bool {
        receipt.status == .verified
    }

    private func remember(_ receipt: DJCommandReceipt, key: String) {
        if completed[key] == nil {
            completedOrder.append(key)
        }
        completed[key] = receipt

        let overflow = completedOrder.count - 500
        guard overflow > 0 else { return }
        for expiredKey in completedOrder.prefix(overflow) {
            completed.removeValue(forKey: expiredKey)
        }
        completedOrder.removeFirst(overflow)
    }

    private func markUncertain(_ key: String) {
        uncertainKeys.insert(key)
    }

    private func clearUncertain(_ key: String) {
        uncertainKeys.remove(key)
    }

    private func withTimeout<T: Sendable>(
        _ duration: Duration,
        action: DJControlAction,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw DJBackendError.commandTimedOut(action)
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
