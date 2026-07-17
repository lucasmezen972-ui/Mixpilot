#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotRuntime

@MainActor
extension AppModel {
    func armLive() {
        refreshEnvironment()
        guard let selectedBackend else {
            liveArmed = false
            runtimeStatus = "Choisis le logiciel DJ avant d’armer le Live."
            return
        }
        guard let project = preparedProject else {
            liveArmed = false
            runtimeStatus = "Prépare un set avant d’armer le Live."
            selectedSection = .studio
            return
        }
        guard project.locked else {
            liveArmed = false
            runtimeStatus = "Verrouille le plan du set avant d’armer le Live."
            selectedSection = .studio
            return
        }
        guard let projectBackend = project.backend else {
            liveArmed = false
            runtimeStatus = "Ce projet ancien ne précise pas le logiciel DJ. Sélectionne \(selectedBackend.displayName), vérifie le set et verrouille-le de nouveau."
            selectedSection = .studio
            return
        }
        guard projectBackend == selectedBackend else {
            liveArmed = false
            runtimeStatus = "Ce projet est préparé pour \(projectBackend.displayName), pas pour \(selectedBackend.displayName). Relance la vérification après avoir choisi le bon backend."
            selectedSection = .preflight
            return
        }
        guard preflightReport.canStartLive else {
            liveArmed = false
            runtimeStatus = "La vérification contient encore \(preflightReport.failedItems.count) blocage(s)."
            selectedSection = .preflight
            return
        }
        liveArmed.toggle()
        runtimeStatus = liveArmed
            ? "Live armé pour \(selectedBackend.displayName)"
            : "Live désarmé"
    }

    func startLive() {
        refreshEnvironment()
        guard liveArmed else {
            runtimeStatus = "Arme le Live avant de le lancer."
            return
        }
        guard let selectedBackend else {
            liveArmed = false
            runtimeStatus = "Choisis le logiciel DJ avant de lancer le Live."
            return
        }
        guard preflightReport.canStartLive else {
            liveArmed = false
            runtimeStatus = "La vérification contient encore des erreurs critiques."
            selectedSection = .preflight
            return
        }
        guard let project = preparedProject, project.locked else {
            liveArmed = false
            runtimeStatus = "Prépare et verrouille le set avant le Live."
            return
        }
        guard project.backend == selectedBackend else {
            liveArmed = false
            runtimeStatus = project.backend.map {
                "Le set est verrouillé pour \($0.displayName), mais \(selectedBackend.displayName) est sélectionné."
            } ?? "Le set ne précise pas le logiciel DJ. Vérifie-le et verrouille-le de nouveau."
            selectedSection = .preflight
            return
        }
        guard let coordinator = runtimeCoordinator, !isLiveRunning else { return }

        do {
            try sleepAssertion.acquire()
        } catch {
            runtimeStatus = "Le Mac peut encore se mettre en veille. Garde-le branché et désactive la veille avant le Live."
        }

        isLiveRunning = true
        runtimeEvents = []
        runtimeStatus = "Vérification du système avec \(selectedBackend.displayName)"
        Task { await backendRegistry?.setLiveActive(true) }

        liveTask = Task {
            do {
                try await coordinator.run(project: project) { [weak self] event in
                    await MainActor.run {
                        self?.applyRuntimeEvent(event, project: project)
                    }
                }
            } catch is CancellationError {
                runtimeStatus = "Autopilote arrêté"
            } catch {
                runtimeStatus = humanMessage(for: error)
                snapshot.statusMessage = runtimeStatus
            }

            isLiveRunning = false
            liveArmed = false
            liveTask = nil
            await backendRegistry?.setLiveActive(false)
            sleepAssertion.release()
        }
    }

    func takeManualControl() {
        guard isLiveRunning, let coordinator = runtimeCoordinator else {
            liveArmed = false
            runtimeStatus = "Le contrôle manuel est déjà actif."
            return
        }

        liveArmed = false
        runtimeStatus = "Reprise manuelle demandée…"
        snapshot.statusMessage = "MixPilot termine le point sûr courant avant de rendre la main."

        Task {
            let decision = await coordinator.requestManualControl()
            runtimeStatus = decision.message
            guard decision.accepted else { return }

            // Do not cancel the Live task here. The coordinator owns the
            // transition boundary, opens the command circuit at the safe point,
            // publishes `.manualControl`, then lets the task finish. Releasing
            // the registry or sleep assertion earlier could allow a backend
            // change while a final transition command is still in flight.
            if snapshot.state == .transitioning {
                snapshot.statusMessage = "La transition en cours se termine sans nouvelle automation."
            }
        }
    }

    func runSimulation() {
        guard !isRunningSimulation else { return }
        isRunningSimulation = true
        report = nil

        Task {
            do {
                let tracks = SetSimulator().makeTracks(count: 50)
                let plans = TransitionPlanner().planSet(tracks)
                let engine = AutopilotEngine()
                try await engine.load(tracks: tracks, plans: plans)
                try await engine.start()

                var step = 0
                var latest = await engine.snapshot()
                while latest.state != .completed && latest.state != .failed {
                    if step == 18 { await engine.inject(.slowLoad) }
                    if step == 77 { await engine.inject(.internetLoss) }
                    latest = await engine.advance()
                    snapshot = latest
                    try? await Task.sleep(for: .milliseconds(35))
                    step += 1
                }

                report = SimulationReport(
                    trackCount: tracks.count,
                    transitionCount: plans.count,
                    completedTransitions: latest.completedTransitions,
                    finalState: latest.state,
                    incidentCount: latest.incidents.count,
                    recoveredIncidentCount: latest.incidents.filter(\.recovered).count,
                    minimumConfidence: plans.map(\.confidence).min() ?? 100
                )
            } catch {
                snapshot.statusMessage = "La simulation a été interrompue. Consulte le diagnostic avancé pour les détails."
            }
            isRunningSimulation = false
        }
    }

    func applyRuntimeEvent(_ event: LiveRuntimeEvent, project: SetProject) {
        runtimeEvents.append(describe(event))
        if runtimeEvents.count > 100 {
            runtimeEvents.removeFirst(runtimeEvents.count - 100)
        }

        switch event {
        case .preparing:
            snapshot.state = .preflight
            snapshot.statusMessage = "Vérification du système"
        case .backendObserved(let environment):
            backendStatus = environment.isRunning
                ? "\(environment.identifier.displayName) connecté"
                : "\(environment.identifier.displayName) hors ligne"
        case .loading(let index, let track, let deck),
             .preloading(let index, let track, let deck):
            snapshot.state = index == 0 ? .loadingInitialTrack : .preloadingNextTrack
            snapshot.nextTrack = track
            snapshot.statusMessage = "Chargement de \(track.title) sur le deck \(deck.rawValue)"
        case .loaded(_, let track, _, let verified):
            runtimeStatus = verified
                ? "Morceau confirmé : \(track.title)"
                : "Morceau chargé, confirmation limitée"
        case .playing(let index, let track, let deck):
            snapshot.state = .playing
            snapshot.currentTrack = track
            snapshot.nextTrack = project.tracks.indices.contains(index + 1)
                ? project.tracks[index + 1].track
                : nil
            snapshot.activeDeck = deck
            snapshot.completedTransitions = index
            snapshot.progress = project.transitions.isEmpty
                ? 1
                : Double(index) / Double(project.transitions.count)
            snapshot.statusMessage = "Lecture : \(track.title)"
        case .transitionAdapted(_, _, let selected, let explanation):
            runtimeStatus = "\(selected.rawValue) • \(explanation)"
        case .transitionStarted(let index, let plan, _):
            snapshot.state = .transitioning
            snapshot.statusMessage = "\(plan.kind.rawValue) • transition \(index + 1)"
        case .transitionProgress(_, let progress):
            runtimeStatus = "Transition \(Int(progress * 100)) %"
        case .transitionCompleted(let index, _):
            snapshot.state = .validatingTransition
            snapshot.completedTransitions = index + 1
            snapshot.progress = Double(index + 1) / Double(max(1, project.transitions.count))
        case .warning(let message):
            runtimeStatus = message
        case .emergency(let message):
            snapshot.state = .emergencyPlayback
            runtimeStatus = message
        case .manualControl:
            snapshot.state = .manualControl
            snapshot.statusMessage = "Contrôle manuel actif"
            runtimeStatus = "Tu as repris la main"
        case .completed:
            snapshot.state = .completed
            snapshot.progress = 1
            snapshot.statusMessage = "Set terminé"
            runtimeStatus = "Terminé"
        }
    }

    func describe(_ event: LiveRuntimeEvent) -> String {
        switch event {
        case .preparing(let name):
            "Préparation : \(name)"
        case .backendObserved(let environment):
            "Backend : \(environment.identifier.displayName)"
        case .loading(_, let track, let deck):
            "Chargement \(track.title) → deck \(deck.rawValue)"
        case .loaded(_, let track, _, let verified):
            "\(track.title) • \(verified ? "confirmé" : "non confirmé")"
        case .playing(_, let track, let deck):
            "Lecture \(track.title) • deck \(deck.rawValue)"
        case .preloading(_, let track, let deck):
            "Préchargement \(track.title) • deck \(deck.rawValue)"
        case .transitionAdapted(_, let original, let selected, _):
            "Transition adaptée : \(original.rawValue) → \(selected.rawValue)"
        case .transitionStarted(let index, let plan, _):
            "Transition \(index + 1) : \(plan.kind.rawValue)"
        case .transitionProgress(let index, let progress):
            "Transition \(index + 1) : \(Int(progress * 100)) %"
        case .transitionCompleted(let index, _):
            "Transition \(index + 1) terminée"
        case .warning(let message):
            "Avertissement : \(message)"
        case .emergency(let message):
            "Secours : \(message)"
        case .manualControl:
            "Contrôle manuel"
        case .completed:
            "Set terminé"
        }
    }
}
#endif
