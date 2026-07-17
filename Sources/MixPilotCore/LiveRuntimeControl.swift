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
            return .accept("La pause sera appliquée au prochain point sûr, sans couper le morceau en cours.")
        case .paused:
            return .accept("L’Autopilote est déjà en pause.")
        case .transitioning:
            return .reject("La pause n’est pas disponible pendant une transition. Attends sa fin ou reprends la main.")
        case .manualControl:
            return .reject("Tu as déjà repris la main sur le Mac.")
        case .idle, .preflight, .loading, .preloading, .completed, .failed:
            return .reject("La pause n’est pas disponible à cette étape du Live.")
        }
    }

    public func resumeDecision(
        pausedFrom phase: LiveRuntimePhase?,
        backendMatchesCheckpoint: Bool,
        deckMatchesCheckpoint: Bool,
        midiReady: Bool,
        audioWatchdogReady: Bool
    ) -> LiveRuntimeCommandDecision {
        guard let phase else {
            return .reject("Aucun point de reprise sûr n’est disponible.")
        }
        guard phase != .transitioning else {
            return .reject("La reprise automatique est bloquée car une transition avait été interrompue. Reprends la main et vérifie les decks.")
        }
        guard backendMatchesCheckpoint else {
            return .reject("Le morceau visible dans le logiciel DJ ne correspond plus au dernier état confirmé.")
        }
        guard deckMatchesCheckpoint else {
            return .reject("Le deck actif ne correspond plus au dernier état confirmé.")
        }
        guard midiReady else {
            return .reject("Les commandes du logiciel DJ ne sont plus prêtes. Relance le test de connexion.")
        }
        guard audioWatchdogReady else {
            return .reject("La surveillance audio n’est plus active. Réactive-la avant de reprendre.")
        }
        return .accept("La reprise est autorisée depuis le dernier point sûr.")
    }

    @available(*, deprecated, renamed: "resumeDecision(pausedFrom:backendMatchesCheckpoint:deckMatchesCheckpoint:midiReady:audioWatchdogReady:)")
    public func resumeDecision(
        pausedFrom phase: LiveRuntimePhase?,
        seratoMatchesCheckpoint: Bool,
        deckMatchesCheckpoint: Bool,
        midiReady: Bool,
        audioWatchdogReady: Bool
    ) -> LiveRuntimeCommandDecision {
        resumeDecision(
            pausedFrom: phase,
            backendMatchesCheckpoint: seratoMatchesCheckpoint,
            deckMatchesCheckpoint: deckMatchesCheckpoint,
            midiReady: midiReady,
            audioWatchdogReady: audioWatchdogReady
        )
    }

    public func skipDecision(
        phase: LiveRuntimePhase,
        incomingTrackVerified: Bool
    ) -> LiveRuntimeCommandDecision {
        guard phase == .waitingForTransition else {
            return .reject("La prochaine transition ne peut pas être modifiée à cette étape.")
        }
        guard incomingTrackVerified else {
            return .reject("Le morceau suivant n’a pas encore été confirmé dans le logiciel DJ.")
        }
        return .accept("La transition prévue sera remplacée par un fondu de secours, sans changer de morceau.")
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
                reasons: plan.reasons + ["Transition remplacée par un fondu de secours contrôlé"],
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
