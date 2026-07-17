import Foundation

public actor AutopilotEngine {
    private var tracks: [Track] = []
    private var plans: [TransitionPlan] = []
    private var currentIndex = 0
    private var activeDeck: DeckID = .a
    private var state: AutopilotState = .idle
    private var incidents: [Incident] = []
    private var pendingIncident: IncidentKind?

    public init() {}

    public func load(tracks: [Track], plans: [TransitionPlan]) throws {
        guard !tracks.isEmpty else { throw AutopilotError.emptySet }
        guard plans.count == max(0, tracks.count - 1) else {
            throw AutopilotError.invalidPlanCount(
                expected: max(0, tracks.count - 1),
                actual: plans.count
            )
        }
        self.tracks = tracks
        self.plans = plans
        currentIndex = 0
        activeDeck = .a
        state = .idle
        incidents = []
        pendingIncident = nil
    }

    public func start() throws {
        guard !tracks.isEmpty else { throw AutopilotError.emptySet }
        guard state == .idle || state == .paused else {
            throw AutopilotError.invalidState(state)
        }
        state = .preflight
    }

    public func pause() {
        if state != .completed && state != .failed { state = .paused }
    }

    public func resume() {
        if state == .paused { state = .playing }
    }

    public func takeManualControl() {
        state = .manualControl
    }

    public func inject(_ incident: IncidentKind) {
        pendingIncident = incident
    }

    @discardableResult
    public func advance() -> LiveSnapshot {
        if let pendingIncident {
            self.pendingIncident = nil
            handle(incident: pendingIncident)
            return snapshot()
        }

        switch state {
        case .idle, .paused, .manualControl, .completed, .failed:
            break
        case .preflight:
            state = .loadingInitialTrack
        case .loadingInitialTrack:
            state = .playing
        case .playing:
            state = currentIndex >= tracks.count - 1
                ? .completed
                : .preloadingNextTrack
        case .preloadingNextTrack:
            state = .validatingNextTrack
        case .validatingNextTrack:
            state = .waitingForTransition
        case .waitingForTransition:
            state = .transitioning
        case .transitioning:
            state = .validatingTransition
        case .validatingTransition:
            state = .cleaningOutgoingDeck
        case .cleaningOutgoingDeck:
            currentIndex += 1
            activeDeck = activeDeck.opposite
            state = .playing
        case .recovering:
            markLastIncidentRecovered()
            state = .playing
        case .emergencyPlayback:
            markLastIncidentRecovered()
            state = .playing
        }
        return snapshot()
    }

    public func snapshot() -> LiveSnapshot {
        let total = max(0, tracks.count - 1)
        let completed = min(currentIndex, total)
        let current = tracks.indices.contains(currentIndex) ? tracks[currentIndex] : nil
        let next = tracks.indices.contains(currentIndex + 1) ? tracks[currentIndex + 1] : nil
        let progress = total == 0
            ? (state == .completed ? 1 : 0)
            : Double(completed) / Double(total)

        return LiveSnapshot(
            state: state,
            currentTrack: current,
            nextTrack: next,
            activeDeck: activeDeck,
            completedTransitions: completed,
            totalTransitions: total,
            progress: progress,
            incidents: incidents,
            statusMessage: statusMessage(for: state)
        )
    }

    private func handle(incident kind: IncidentKind) {
        incidents.append(Incident(kind: kind, message: message(for: kind)))

        switch normalized(kind) {
        case .audioSilence, .audioSourceLost, .internetLoss, .backendUnavailable:
            state = .emergencyPlayback
        case .slowLoad, .loadTimeout, .wrongTrack, .transitionMismatch,
             .audioClipping, .midiUnavailable, .powerDisconnected:
            state = .recovering
        case .checkpointMismatch:
            state = .manualControl
        case .emergencyPlayerFailure:
            state = .failed
        case .seratoUnavailable:
            state = .emergencyPlayback
        }
    }

    private func normalized(_ incident: IncidentKind) -> IncidentKind {
        if incident == .seratoUnavailable { return .backendUnavailable }
        return incident
    }

    private func markLastIncidentRecovered() {
        guard !incidents.isEmpty else { return }
        incidents[incidents.count - 1].recovered = true
    }

    private func message(for incident: IncidentKind) -> String {
        switch normalized(incident) {
        case .slowLoad:
            "Chargement lent : prolongation et nouvelle tentative"
        case .loadTimeout:
            "Délai de chargement dépassé : variante de secours et nouvelle vérification"
        case .wrongTrack:
            "Mauvais morceau détecté : revalidation de la sélection"
        case .transitionMismatch:
            "Transition incohérente : annulation et retour au deck actif"
        case .internetLoss:
            "Internet indisponible : le Live local continue avec les ressources préparées"
        case .audioSilence:
            "Silence critique : déclenchement de la musique de secours"
        case .audioSourceLost:
            "Source audio perdue : bascule vers la musique de secours"
        case .audioClipping:
            "Saturation détectée : réduction contrôlée des niveaux"
        case .midiUnavailable:
            "Connexion MIDI perdue : contrôle automatique suspendu"
        case .backendUnavailable:
            "Logiciel DJ indisponible : musique de secours et reprise manuelle"
        case .powerDisconnected:
            "Alimentation débranchée : alerte et vérification de la batterie"
        case .checkpointMismatch:
            "Dernier état incompatible : reprise manuelle obligatoire"
        case .emergencyPlayerFailure:
            "Musique de secours indisponible : arrêt sécurisé"
        case .seratoUnavailable:
            "Logiciel DJ indisponible : musique de secours et reprise manuelle"
        }
    }

    private func statusMessage(for state: AutopilotState) -> String {
        switch state {
        case .idle: "Prêt à charger un set"
        case .preflight: "Vérification du système"
        case .loadingInitialTrack: "Chargement du premier morceau"
        case .playing: "Lecture en cours"
        case .preloadingNextTrack: "Préchargement du morceau suivant"
        case .validatingNextTrack: "Confirmation du morceau entrant"
        case .waitingForTransition: "Attente du point de transition"
        case .transitioning: "Transition automatique"
        case .validatingTransition: "Vérification de la transition"
        case .cleaningOutgoingDeck: "Préparation du deck suivant"
        case .recovering: "Récupération automatique"
        case .emergencyPlayback: "Musique de secours"
        case .paused: "Autopilote en pause"
        case .manualControl: "Contrôle manuel"
        case .completed: "Set terminé"
        case .failed: "Live arrêté en sécurité"
        }
    }
}

public enum AutopilotError: Error, Equatable, Sendable {
    case emptySet
    case invalidPlanCount(expected: Int, actual: Int)
    case invalidState(AutopilotState)
}
