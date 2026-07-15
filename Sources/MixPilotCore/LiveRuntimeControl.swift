import Foundation

public enum LiveRuntimePhase: String, Codable, Hashable, Sendable {
    case idle
    case preflight
    case loading
    case playing
    case preloading
    case waitingForTransition
    case transitioning
    case paused
    case manualControl
    case completed
    case failed
}

public struct LiveRuntimeCommandDecision: Codable, Hashable, Sendable {
    public var accepted: Bool
    public var message: String

    public init(accepted: Bool, message: String) {
        self.accepted = accepted
        self.message = message
    }

    public static func accept(_ message: String) -> Self {
        .init(accepted: true, message: message)
    }

    public static func reject(_ message: String) -> Self {
        .init(accepted: false, message: message)
    }
}

public struct LiveRuntimeControlPolicy: Sendable {
    public init() {}

    public func pauseDecision(phase: LiveRuntimePhase) -> LiveRuntimeCommandDecision {
        switch phase {
        case .playing, .waitingForTransition:
            return .accept("Pause acceptée au prochain point sûr, sans couper le son en cours.")
        case .paused:
            return .accept("L’Autopilot est déjà en pause.")
        case .transitioning:
            return .reject("Pause refusée pendant une courbe MIDI active. Termine la transition ou reprends le contrôle manuel.")
        case .manualControl:
            return .reject("Le Mac est déjà en contrôle manuel.")
        case .idle, .preflight, .loading, .preloading, .completed, .failed:
            return .reject("La Pause n’est pas disponible dans l’état actuel du moteur.")
        }
    }

    public func resumeDecision(
        pausedFrom phase: LiveRuntimePhase?,
        seratoMatchesCheckpoint: Bool,
        deckMatchesCheckpoint: Bool,
        midiReady: Bool,
        audioWatchdogReady: Bool
    ) -> LiveRuntimeCommandDecision {
        guard let phase else {
            return .reject("Aucun checkpoint de pause n’est disponible.")
        }
        guard phase != .transitioning else {
            return .reject("Reprise refusée : une courbe MIDI avait été interrompue.")
        }
        guard seratoMatchesCheckpoint else {
            return .reject("Reprise refusée : le morceau visible dans Serato ne correspond pas au checkpoint.")
        }
        guard deckMatchesCheckpoint else {
            return .reject("Reprise refusée : le deck interne ne correspond plus au checkpoint.")
        }
        guard midiReady else {
            return .reject("Reprise refusée : le mapping MIDI n’est pas prêt.")
        }
        guard audioWatchdogReady else {
            return .reject("Reprise refusée : la surveillance audio n’est pas active.")
        }
        return .accept("Reprise autorisée depuis le dernier point de synchronisation sûr.")
    }

    public func skipDecision(
        phase: LiveRuntimePhase,
        incomingTrackVerified: Bool
    ) -> LiveRuntimeCommandDecision {
        guard phase == .waitingForTransition else {
            return .reject("Transition suivante non modifiable dans l’état actuel.")
        }
        guard incomingTrackVerified else {
            return .reject("Skip refusé : le titre entrant n’est pas confirmé dans Serato.")
        }
        return .accept("La transition planifiée sera remplacée par un Safe Fade contrôlé, sans changer de titre.")
    }

    public func safeReplacement(for plan: TransitionPlan) -> TransitionPlan {
        if plan.kind == .safeFade { return plan }
        if let safe = RehearsalEngine().variants(for: plan).first(where: { $0.plan.kind == .safeFade })?.plan {
            return TransitionPlan(
                outgoingTrackID: plan.outgoingTrackID,
                incomingTrackID: plan.incomingTrackID,
                kind: .safeFade,
                bars: safe.bars,
                targetBPM: plan.targetBPM,
                confidence: max(plan.confidence, safe.confidence),
                reasons: plan.reasons + ["Transition remplacée à distance par un Safe Fade contrôlé"],
                lanes: safe.lanes
            )
        }
        return TransitionPlan(
            outgoingTrackID: plan.outgoingTrackID,
            incomingTrackID: plan.incomingTrackID,
            kind: .safeFade,
            bars: max(4, min(8, plan.bars)),
            targetBPM: plan.targetBPM,
            confidence: max(78, plan.confidence),
            reasons: plan.reasons + ["Transition de secours sans modification de l’ordre du set"],
            lanes: plan.lanes
        )
    }
}
