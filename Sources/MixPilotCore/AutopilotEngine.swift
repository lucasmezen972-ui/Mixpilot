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
            throw AutopilotError.invalidPlanCount(expected: max(0, tracks.count - 1), actual: plans.count)
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
        guard state == .idle || state == .paused else { throw AutopilotError.invalidState(state) }
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
            if currentIndex >= tracks.count - 1 {
                state = .completed
            } else {
                state = .preloadingNextTrack
            }
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
        let progress = total == 0 ? (state == .completed ? 1 : 0) : Double(completed) / Double(total)

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
        let incident = Incident(kind: kind, message: message(for: kind))
        incidents.append(incident)

        switch kind {
        case .audioSilence, .audioSourceLost, .internetLoss, .seratoUnavailable:
            state = .emergencyPlayback
        case .slowLoad, .loadTimeout, .wrongTrack, .transitionMismatch,
             .audioClipping, .midiUnavailable, .powerDisconnected:
            state = .recovering
        case .checkpointMismatch:
            state = .manualControl
        case .emergencyPlayerFailure:
            state = .failed
        }
    }

    private func markLastIncidentRecovered() {
        guard !incidents.isEmpty else { return }
        incidents[incidents.count - 1].recovered = true
    }

    private func message(for incident: IncidentKind) -> String {
        switch incident {
        case .slowLoad: "Chargement lent : prolongation et nouvelle tentative"
        case .loadTimeout: "Timeout de chargement : boucle de sécurité et titre alternatif"
        case .wrongTrack: "Mauvais titre détecté : revalidation de la sélection"
        case .transitionMismatch: "Transition incohérente : annulation et retour au deck actif"
        case .internetLoss: "Internet indisponible : bascule vers le secours local"
        case .audioSilence: "Silence critique : déclenchement du lecteur de secours"
        case .audioSourceLost: "Source audio perdue : bascule vers le secours local"
        case .audioClipping: "Saturation détectée : réduction contrôlée des niveaux"
        case .midiUnavailable: "Port MIDI indisponible : récupération contrôlée"
        case .seratoUnavailable: "Serato indisponible : lecture locale de secours"
        case .powerDisconnected: "Alimentation débranchée : alerte et vérification batterie"
        case .checkpointMismatch: "Checkpoint incompatible : reprise manuelle obligatoire"
        case .emergencyPlayerFailure: "Lecteur de secours indisponible : arrêt sécurisé"
        }
    }

    private func statusMessage(for state: AutopilotState) -> String {
        switch state {
        case .idle: "Prêt à charger un set"
        case .preflight: "Vérifications avant lecture"
        case .loadingInitialTrack: "Chargement du premier titre"
        case .playing: "Lecture en cours"
        case .preloadingNextTrack: "Préchargement du titre suivant"
        case .validatingNextTrack: "Validation du titre entrant"
        case .waitingForTransition: "Attente du point de transition"
        case .transitioning: "Transition automatique"
        case .validatingTransition: "Validation de la transition"
        case .cleaningOutgoingDeck: "Nettoyage du deck sortant"
        case .recovering: "Récupération automatique"
        case .emergencyPlayback: "Musique locale de secours"
        case .paused: "Autopilot en pause"
        case .manualControl: "Contrôle manuel"
        case .completed: "Set terminé"
        case .failed: "Échec du set"
        }
    }
}

public enum AutopilotError: Error, Equatable, Sendable {
    case emptySet
    case invalidPlanCount(expected: Int, actual: Int)
    case invalidState(AutopilotState)
}
