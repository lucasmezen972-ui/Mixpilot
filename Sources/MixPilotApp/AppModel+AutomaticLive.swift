#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotRuntime
import MixPilotSystem

private enum AutomaticLiveStartError: Error, LocalizedError {
    case noDJSoftware
    case launchFailed(DJBackendIdentifier)
    case mappingUnavailable
    case audioMonitoringUnavailable
    case alreadyStarting

    var errorDescription: String? {
        switch self {
        case .noDJSoftware:
            "Aucun logiciel DJ compatible n’est installé. Installe Rekordbox, Serato DJ Pro ou djay Pro."
        case .launchFailed(let backend):
            "MixPilot n’a pas réussi à lancer \(backend.displayName). Ouvre-le une fois manuellement, puis relance le mode automatique."
        case .mappingUnavailable:
            "Le contrôleur MIDI MixPilot ou son mapping n’est pas prêt. Relance MixPilot puis réessaie."
        case .audioMonitoringUnavailable:
            "La surveillance audio n’a pas pu démarrer. Autorise le microphone ou l’entrée audio dans les réglages macOS."
        case .alreadyStarting:
            "Le lancement automatique est déjà en cours."
        }
    }
}

@MainActor
extension AppModel {
    /// One-click Spotify-only path for the normal user flow.
    ///
    /// MixPilot chooses or launches the DJ application, rebuilds the set from
    /// the last selected Spotify playlist, supplements it from Liked Songs only
    /// when fewer than two playable tracks remain, locks the plan, starts the
    /// audio watchdog and launches the runtime without a separate Arm step.
    func startLiveAutomatically() {
        guard !isLiveRunning, liveTask == nil else {
            runtimeStatus = isLiveRunning ? "Le Live automatique est déjà en cours." : "Le lancement automatique est déjà en cours."
            selectedSection = .live
            return
        }

        runtimeEvents = []
        runtimeStatus = "Synchronisation Spotify et préparation automatique du Live…"
        snapshot.statusMessage = "Préparation Spotify 100 %"
        selectedSection = .live

        Task { @MainActor in
            do {
                guard liveTask == nil, !isLiveRunning else {
                    throw AutomaticLiveStartError.alreadyStarting
                }

                let backendIdentifier = try await resolveAutomaticLiveBackend()
                try await ensureDJApplicationRunning(backendIdentifier)
                await refreshEnvironmentNow()

                guard let mappedController else {
                    throw AutomaticLiveStartError.mappingUnavailable
                }
                let profile = await mappedController.currentProfile()
                guard DJControlAction.automaticPresetCriticalActions.allSatisfy({ profile[$0] != nil }) else {
                    throw AutomaticLiveStartError.mappingUnavailable
                }

                let spotify = SpotifyLibraryCoordinator()
                var project = try await spotify.makeAutomaticSpotifyProject(
                    backend: backendIdentifier,
                    maximumTrackCount: 25
                )
                if !project.locked {
                    project.lock()
                }
                preparedProject = project
                playlistWarnings = []
                updateSnapshotForProject()
                try await projectStore.save(project)
                appendAutomaticLiveEvent(
                    "Set Spotify prêt : \(project.name) • \(project.tracks.count) titres • aucun fichier local."
                )

                try await ensureAutomaticAudioMonitoring()

                let observation = accessibilityBridge.observe(
                    backend: backendIdentifier,
                    maxDepth: 4,
                    maximumStrings: 120
                )
                if !observation.accessibilityGranted {
                    accessibilityBridge.requestAccessibilityPrompt()
                    appendAutomaticLiveEvent(
                        "Accessibilité non autorisée : MixPilot continue avec la surveillance audio et demandera l’autorisation macOS une seule fois."
                    )
                }

                let backend = AutomaticLiveDJBackend(
                    identifier: backendIdentifier,
                    midi: mappedController
                )
                let coordinator = LiveAutopilotCoordinator(backend: backend)
                runtimeCoordinator = coordinator
                liveArmed = true

                do {
                    try sleepAssertion.acquire()
                } catch {
                    appendAutomaticLiveEvent(
                        "Le verrouillage anti-veille n’a pas été obtenu. Garde le Mac branché pendant le set."
                    )
                }

                isLiveRunning = true
                runtimeStatus = "Live Spotify automatique supervisé • \(backendIdentifier.displayName)"
                snapshot.statusMessage = "Initialisation du set Spotify"
                await backendRegistry?.setLiveActive(true)

                let automaticConfiguration = LiveRuntimeConfiguration(
                    preloadLeadSeconds: 90,
                    loadSettleSeconds: 4,
                    framesPerSecond: 30,
                    speedMultiplier: 1,
                    strictTrackValidation: false
                )

                liveTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    do {
                        try await coordinator.run(
                            project: project,
                            configuration: automaticConfiguration
                        ) { [weak self] event in
                            await MainActor.run {
                                self?.applyRuntimeEvent(event, project: project)
                            }
                        }
                    } catch is CancellationError {
                        self.runtimeStatus = "Autopilote arrêté"
                    } catch {
                        self.runtimeStatus = self.humanMessage(for: error)
                        self.snapshot.statusMessage = self.runtimeStatus
                    }

                    self.isLiveRunning = false
                    self.liveArmed = false
                    self.liveTask = nil
                    await self.backendRegistry?.setLiveActive(false)
                    self.sleepAssertion.release()
                }
            } catch {
                liveArmed = false
                isLiveRunning = false
                runtimeStatus = humanMessage(for: error)
                snapshot.statusMessage = runtimeStatus
                selectedSection = .studio
                await backendRegistry?.setLiveActive(false)
                sleepAssertion.release()
            }
        }
    }

    private func resolveAutomaticLiveBackend() async throws -> DJBackendIdentifier {
        guard let backendRegistry else { throw AutomaticLiveStartError.noDJSoftware }
        backendDescriptors = await backendRegistry.availableBackends()

        let selectedInstalled = selectedBackend.flatMap { selected in
            backendDescriptors.first {
                $0.identifier == selected && $0.environment.isInstalled
            }
        }
        let chosen = selectedInstalled
            ?? backendDescriptors.first(where: { $0.environment.isRunning })
            ?? backendDescriptors.first(where: { $0.environment.isInstalled })

        guard let chosen else { throw AutomaticLiveStartError.noDJSoftware }
        if selectedBackend != chosen.identifier {
            try await backendRegistry.select(chosen.identifier)
            selectedBackend = chosen.identifier
        }
        return chosen.identifier
    }

    private func ensureDJApplicationRunning(_ identifier: DJBackendIdentifier) async throws {
        let detector = DJApplicationEnvironmentDetector()
        if detector.detect(identifier).isRunning {
            try? accessibilityBridge.activate(identifier)
            return
        }

        guard let applicationURL = installedDJApplicationURL(identifier) else {
            throw AutomaticLiveStartError.noDJSoftware
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: configuration
        )

        for _ in 0..<80 {
            if detector.detect(identifier).isRunning {
                try? accessibilityBridge.activate(identifier)
                return
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw AutomaticLiveStartError.launchFailed(identifier)
    }

    private func installedDJApplicationURL(_ identifier: DJBackendIdentifier) -> URL? {
        let names: [String]
        switch identifier {
        case .serato:
            names = ["Serato DJ Pro.app", "Serato DJ.app"]
        case .rekordbox:
            names = ["rekordbox.app"]
        case .djay:
            names = ["djay Pro.app", "djay Pro AI.app", "djay.app"]
        }

        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true),
        ]
        for root in roots {
            for name in names {
                let candidate = root.appendingPathComponent(name, isDirectory: true)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        return nil
    }

    private func ensureAutomaticAudioMonitoring() async throws {
        if !audioMonitor.isRunning {
            startAudioMonitoring()
        }
        for _ in 0..<50 {
            if audioMonitor.isRunning { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw AutomaticLiveStartError.audioMonitoringUnavailable
    }

    private func appendAutomaticLiveEvent(_ message: String) {
        runtimeEvents.append("Automatique : \(message)")
        if runtimeEvents.count > 100 {
            runtimeEvents.removeFirst(runtimeEvents.count - 100)
        }
    }
}
#endif
