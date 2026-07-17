#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotRuntime

@MainActor
extension AppModel {
    func armLive() {
        refreshEnvironment()
        guard selectedBackend != nil else {
            liveArmed = false
            runtimeStatus = "Choisis le logiciel DJ avant d’armer le Live."
            return
        }
        guard preflightReport.canStartLive else {
            liveArmed = false
            runtimeStatus = "La vérification contient encore \(preflightReport.failedItems.count) blocage(s)."
            selectedSection = .preflight
            return
        }
        liveArmed.toggle()
        runtimeStatus = liveArmed ? "Live armé" : "Live désarmé"
    }

    func startLive() {
        refreshEnvironment()
        guard liveArmed else {
            runtimeStatus = "Arme le Live avant de le lancer."
            return
        }
        guard preflightReport.canStartLive else {
            runtimeStatus = "La vérification contient encore des erreurs critiques."
            selectedSection = .preflight
            return
        }
        guard let project = preparedProject, project.locked else {
            runtimeStatus = "Prépare et verrouille le set avant le Live."
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
        runtimeStatus = "Vérification du système"
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
            await backendRegistry?.setLiveActive(false)
            sleepAssertion.release()
        }
    }

    func takeManualControl() {
        liveTask?.cancel()
        liveTask = nil
        Task {
            _ = await runtimeCoordinator?.requestManualControl()
            await backendRegistry?.setLiveActive(false)
        }
        sleepAssertion.release()
        isLiveRunning = false
        liveArmed = false
        snapshot.state = .manualControl
        snapshot.statusMessage = "Contrôle manuel repris"
        runtimeStatus = "Tu as repris la main"
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
