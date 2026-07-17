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
            runtimeStatus = AppLocalizedCopy.status("status.live.arm_choose_backend")
            return
        }
        guard let project = preparedProject else {
            liveArmed = false
            runtimeStatus = AppLocalizedCopy.status("status.live.arm_prepare_set")
            selectedSection = .studio
            return
        }
        guard project.locked else {
            liveArmed = false
            runtimeStatus = AppLocalizedCopy.status("status.live.arm_lock_plan")
            selectedSection = .studio
            return
        }
        guard let projectBackend = project.backend else {
            liveArmed = false
            runtimeStatus = AppLocalizedCopy.statusFormat(
                "status.live.legacy_project",
                selectedBackend.displayName
            )
            selectedSection = .studio
            return
        }
        guard projectBackend == selectedBackend else {
            liveArmed = false
            runtimeStatus = AppLocalizedCopy.statusFormat(
                "status.live.project_backend_mismatch",
                projectBackend.displayName,
                selectedBackend.displayName
            )
            selectedSection = .preflight
            return
        }
        guard preflightReport.canStartLive else {
            liveArmed = false
            runtimeStatus = AppLocalizedCopy.statusFormat(
                "status.live.blockers",
                preflightReport.failedItems.count
            )
            selectedSection = .preflight
            return
        }
        liveArmed.toggle()
        runtimeStatus = liveArmed
            ? AppLocalizedCopy.statusFormat("status.live.armed", selectedBackend.displayName)
            : AppLocalizedCopy.status("status.live.disarmed")
    }

    func startLive() {
        refreshEnvironment()
        guard liveArmed else {
            runtimeStatus = AppLocalizedCopy.status("status.live.start_arm_first")
            return
        }
        guard let selectedBackend else {
            liveArmed = false
            runtimeStatus = AppLocalizedCopy.status("status.live.start_choose_backend")
            return
        }
        guard preflightReport.canStartLive else {
            liveArmed = false
            runtimeStatus = AppLocalizedCopy.status("status.live.critical_errors")
            selectedSection = .preflight
            return
        }
        guard let project = preparedProject, project.locked else {
            liveArmed = false
            runtimeStatus = AppLocalizedCopy.status("status.live.prepare_and_lock")
            return
        }
        guard project.backend == selectedBackend else {
            liveArmed = false
            runtimeStatus = project.backend.map {
                AppLocalizedCopy.statusFormat(
                    "status.live.locked_backend_mismatch",
                    $0.displayName,
                    selectedBackend.displayName
                )
            } ?? AppLocalizedCopy.status("status.live.project_backend_missing")
            selectedSection = .preflight
            return
        }
        guard let coordinator = runtimeCoordinator, !isLiveRunning else { return }
        guard coordinator.backendIdentifier == selectedBackend else {
            liveArmed = false
            runtimeCoordinator = nil
            runtimeStatus = AppLocalizedCopy.statusFormat(
                "status.live.coordinator_mismatch",
                coordinator.backendDisplayName,
                selectedBackend.displayName
            )
            selectedSection = .preflight
            Task {
                try? await rebuildRuntimeCoordinator()
                await refreshEnvironmentNow()
            }
            return
        }

        do {
            try sleepAssertion.acquire()
        } catch {
            runtimeStatus = AppLocalizedCopy.status("status.live.sleep_warning")
        }

        isLiveRunning = true
        runtimeEvents = []
        runtimeStatus = AppLocalizedCopy.statusFormat(
            "status.live.system_check_backend",
            selectedBackend.displayName
        )
        Task { await backendRegistry?.setLiveActive(true) }
        startLiveReconciliation(expectedBackend: selectedBackend, coordinator: coordinator)

        liveTask = Task {
            do {
                try await coordinator.run(project: project) { [weak self] event in
                    await MainActor.run {
                        self?.applyRuntimeEvent(event, project: project)
                    }
                }
            } catch is CancellationError {
                runtimeStatus = AppLocalizedCopy.status("status.live.autopilot_stopped")
            } catch {
                runtimeStatus = humanMessage(for: error)
                snapshot.statusMessage = runtimeStatus
            }

            liveReconciliationTask?.cancel()
            liveReconciliationTask = nil
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
            runtimeStatus = AppLocalizedCopy.status("status.live.manual_already_active")
            return
        }

        liveArmed = false
        runtimeStatus = AppLocalizedCopy.status("status.live.manual_requested")
        snapshot.statusMessage = AppLocalizedCopy.status("status.live.manual_safe_point")

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
                snapshot.statusMessage = AppLocalizedCopy.status("status.live.transition_finishing")
            }
        }
    }

    private func startLiveReconciliation(
        expectedBackend: DJBackendIdentifier,
        coordinator: LiveAutopilotCoordinator
    ) {
        liveReconciliationTask?.cancel()
        liveReconciliationTask = Task { [weak self] in
            var reliabilityTracker = LiveStateReliabilityTracker(failureThreshold: 2)

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }

                guard let self, self.isLiveRunning else { return }
                guard let registry = self.backendRegistry else {
                    await self.requestSafeManualControl(
                        reason: AppLocalizedCopy.status("status.live.registry_unavailable"),
                        coordinator: coordinator
                    )
                    return
                }

                do {
                    let backend = try await registry.activeBackend()
                    let environment = await backend.detectEnvironment()
                    guard backend.identifier == expectedBackend,
                          environment.identifier == expectedBackend,
                          environment.isRunning else {
                        await self.requestSafeManualControl(
                            reason: AppLocalizedCopy.statusFormat(
                                "status.live.backend_lost",
                                expectedBackend.displayName
                            ),
                            coordinator: coordinator
                        )
                        return
                    }

                    let state = try? await backend.readState()
                    let stateIsReliable = state?.isReliable == true
                    if reliabilityTracker.record(isReliable: stateIsReliable) {
                        await self.requestSafeManualControl(
                            reason: AppLocalizedCopy.status("status.live.reconcile_state_lost"),
                            coordinator: coordinator
                        )
                        return
                    }
                    guard let state, state.isReliable else {
                        self.runtimeStatus = AppLocalizedCopy.status(
                            "status.live.state_temporarily_unavailable"
                        )
                        continue
                    }

                    if let observedDeck = state.activeDeck,
                       observedDeck != self.snapshot.activeDeck {
                        await self.requestSafeManualControl(
                            reason: AppLocalizedCopy.status("status.live.active_deck_changed"),
                            coordinator: coordinator
                        )
                        return
                    }
                    if let expectedTrack = self.snapshot.currentTrack,
                       let observedTrack = state.decks[self.snapshot.activeDeck]?.track,
                       !self.trackReference(observedTrack, matches: expectedTrack) {
                        await self.requestSafeManualControl(
                            reason: AppLocalizedCopy.status("status.live.visible_track_mismatch"),
                            coordinator: coordinator
                        )
                        return
                    }
                } catch {
                    await self.requestSafeManualControl(
                        reason: AppLocalizedCopy.status("status.live.reconcile_failed"),
                        coordinator: coordinator
                    )
                    return
                }
            }
        }
    }

    private func trackReference(_ observed: DJTrackReference, matches expected: Track) -> Bool {
        if observed.id == expected.id.uuidString { return true }
        guard let title = observed.title,
              title.compare(expected.title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame else {
            return false
        }
        guard let artist = observed.artist, !artist.isEmpty, !expected.artist.isEmpty else {
            return true
        }
        return artist.compare(expected.artist, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private func requestSafeManualControl(
        reason: String,
        coordinator: LiveAutopilotCoordinator
    ) async {
        guard isLiveRunning else { return }
        let decision = await coordinator.requestManualControl()
        runtimeStatus = reason
        snapshot.statusMessage = decision.accepted
            ? AppLocalizedCopy.statusFormat("status.live.safe_point_suffix", reason)
            : reason
        runtimeEvents.append(
            AppLocalizedCopy.statusFormat("status.live.security_event", reason)
        )
        if runtimeEvents.count > 100 {
            runtimeEvents.removeFirst(runtimeEvents.count - 100)
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
                snapshot.statusMessage = AppLocalizedCopy.status(
                    "status.live.simulation_interrupted"
                )
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
            snapshot.statusMessage = AppLocalizedCopy.status("status.event.system_check")
        case .backendObserved(let environment):
            backendStatus = AppLocalizedCopy.statusFormat(
                environment.isRunning
                    ? "status.event.backend_connected"
                    : "status.event.backend_offline",
                environment.identifier.displayName
            )
        case .loading(let index, let track, let deck),
             .preloading(let index, let track, let deck):
            snapshot.state = index == 0 ? .loadingInitialTrack : .preloadingNextTrack
            snapshot.nextTrack = track
            snapshot.statusMessage = AppLocalizedCopy.statusFormat(
                "status.event.loading",
                track.title,
                deck.rawValue
            )
        case .loaded(_, let track, _, let verified):
            runtimeStatus = verified
                ? AppLocalizedCopy.statusFormat("status.event.track_confirmed", track.title)
                : AppLocalizedCopy.status("status.event.track_confirmation_limited")
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
            snapshot.statusMessage = AppLocalizedCopy.statusFormat(
                "status.event.playing",
                track.title
            )
        case .transitionAdapted(_, _, let selected, let explanation):
            runtimeStatus = "\(selected.rawValue) • \(explanation)"
        case .transitionStarted(let index, let plan, _):
            snapshot.state = .transitioning
            snapshot.statusMessage = AppLocalizedCopy.statusFormat(
                "status.event.transition_started",
                plan.kind.rawValue,
                index + 1
            )
        case .transitionProgress(_, let progress):
            runtimeStatus = AppLocalizedCopy.statusFormat(
                "status.event.transition_progress",
                Int(progress * 100)
            )
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
            snapshot.statusMessage = AppLocalizedCopy.status("status.event.manual_active")
            runtimeStatus = AppLocalizedCopy.status("status.event.manual_taken")
        case .completed:
            snapshot.state = .completed
            snapshot.progress = 1
            snapshot.statusMessage = AppLocalizedCopy.status("status.event.set_completed")
            runtimeStatus = AppLocalizedCopy.status("status.event.completed")
        }
    }

    func describe(_ event: LiveRuntimeEvent) -> String {
        switch event {
        case .preparing(let name):
            AppLocalizedCopy.statusFormat("status.log.preparing", name)
        case .backendObserved(let environment):
            AppLocalizedCopy.statusFormat(
                "status.log.backend",
                environment.identifier.displayName
            )
        case .loading(_, let track, let deck):
            AppLocalizedCopy.statusFormat(
                "status.log.loading",
                track.title,
                deck.rawValue
            )
        case .loaded(_, let track, _, let verified):
            AppLocalizedCopy.statusFormat(
                "status.log.loaded",
                track.title,
                AppLocalizedCopy.status(
                    verified ? "status.log.confirmed" : "status.log.unconfirmed"
                )
            )
        case .playing(_, let track, let deck):
            AppLocalizedCopy.statusFormat(
                "status.log.playing",
                track.title,
                deck.rawValue
            )
        case .preloading(_, let track, let deck):
            AppLocalizedCopy.statusFormat(
                "status.log.preloading",
                track.title,
                deck.rawValue
            )
        case .transitionAdapted(_, let original, let selected, _):
            AppLocalizedCopy.statusFormat(
                "status.log.adapted",
                original.rawValue,
                selected.rawValue
            )
        case .transitionStarted(let index, let plan, _):
            AppLocalizedCopy.statusFormat(
                "status.log.transition_started",
                index + 1,
                plan.kind.rawValue
            )
        case .transitionProgress(let index, let progress):
            AppLocalizedCopy.statusFormat(
                "status.log.transition_progress",
                index + 1,
                Int(progress * 100)
            )
        case .transitionCompleted(let index, _):
            AppLocalizedCopy.statusFormat(
                "status.log.transition_completed",
                index + 1
            )
        case .warning(let message):
            AppLocalizedCopy.statusFormat("status.log.warning", message)
        case .emergency(let message):
            AppLocalizedCopy.statusFormat("status.log.emergency", message)
        case .manualControl:
            AppLocalizedCopy.status("status.log.manual")
        case .completed:
            AppLocalizedCopy.status("status.log.set_completed")
        }
    }
}
#endif
