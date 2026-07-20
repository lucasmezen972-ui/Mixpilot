#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotSystem
import UniformTypeIdentifiers

@MainActor
extension AppModel {
    func capturePlaylist() {
        guard let selectedBackend else {
            runtimeStatus = "Choisis ton logiciel DJ avant d’importer la playlist."
            return
        }

        runtimeStatus = "Lecture de la playlist visible dans \(selectedBackend.displayName)…"
        Task { @MainActor [weak self] in
            guard let self else { return }
            let rows = await self.accessibilityBridge.libraryRows(
                backend: selectedBackend,
                maxRows: 1_000
            )
            guard self.selectedBackend == selectedBackend else {
                self.runtimeStatus = "Le logiciel DJ a changé pendant l’import. Relance la lecture de la playlist."
                return
            }

            self.libraryRowCount = rows.count
            let result = VisiblePlaylistImporter().importRows(rows)
            self.playlistWarnings = result.warnings
            guard !result.tracks.isEmpty else {
                self.runtimeStatus = "Aucune playlist exploitable n’est visible. Ouvre la playlist souhaitée, puis relance l’import."
                return
            }
            self.preparedProject = SetPreparationEngine().prepare(
                name: "Playlist \(selectedBackend.displayName) — \(Date().formatted(date: .abbreviated, time: .shortened))",
                tracks: result.tracks,
                backend: selectedBackend
            )
            self.optimizationReport = SetOptimizer().analyze(tracks: result.tracks)
            self.runtimeStatus = "\(result.tracks.count) morceaux préparés pour \(selectedBackend.displayName)"
            self.updateSnapshotForProject()
            self.evaluatePreflight()
        }
    }

    @available(*, deprecated, message: "Use capturePlaylist()")
    func captureSeratoPlaylist() { capturePlaylist() }

    func createDemoProject() {
        let tracks = SetSimulator().makeTracks(count: 30)
        preparedProject = SetPreparationEngine().prepare(
            name: "Set de démonstration",
            tracks: tracks,
            backend: selectedBackend
        )
        optimizationReport = SetOptimizer().analyze(tracks: tracks)
        playlistWarnings = []
        runtimeStatus = selectedBackend.map {
            "Set de démonstration préparé pour \($0.displayName)"
        } ?? "Set de démonstration préparé • choisis le logiciel DJ avant le Live"
        updateSnapshotForProject()
        evaluatePreflight()
    }

    func lockPreparedProject() {
        guard var project = preparedProject else { return }
        guard let selectedBackend else {
            runtimeStatus = "Choisis le logiciel DJ avant de verrouiller le plan."
            return
        }

        project.selectBackend(selectedBackend)
        project.lock()
        runtimeStatus = "Verrouillage et sauvegarde du plan…"

        Task {
            do {
                _ = try await projectStore.save(project)
                preparedProject = project
                liveArmed = false
                runtimeStatus = "Plan verrouillé pour \(selectedBackend.displayName) • prêt pour la vérification"
                updateSnapshotForProject()
                evaluatePreflight()
            } catch {
                liveArmed = false
                runtimeStatus = "Le plan n’a pas pu être sauvegardé. Il reste déverrouillé et le Live ne peut pas être armé."
                evaluatePreflight()
            }
        }
    }

    func selectEmergencyAudio() {
        let panel = NSOpenPanel()
        panel.title = "Choisir au moins 30 minutes de musique locale de secours"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav, .aiff, .audio]
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        do {
            let summary = try emergencyPlayer.prepare(urls: panel.urls)
            emergencyDuration = summary.totalDuration
            emergencyStatus = "\(summary.fileCount) fichiers • \(Int(summary.totalDuration / 60)) min"
            if !summary.invalidFiles.isEmpty {
                emergencyStatus += " • \(summary.invalidFiles.count) fichier(s) ignoré(s)"
            }
        } catch {
            emergencyDuration = 0
            emergencyStatus = "La musique de secours n’a pas pu être préparée. Choisis des fichiers audio locaux lisibles."
        }
        evaluatePreflight()
    }

    func playEmergencyAudio() {
        emergencyPlayer.play()
        emergencyStatus = "Musique de secours en lecture"
    }

    func stopEmergencyAudio() {
        emergencyPlayer.stop()
        emergencyStatus = "Musique de secours arrêtée"
    }

    func startAudioMonitoring() {
        guard !audioMonitor.isRunning, audioStatus != "Démarrage de la surveillance…" else { return }
        audioMonitoringGeneration &+= 1
        let generation = audioMonitoringGeneration
        lastAudioLevelUIUpdateAt = 0
        audioStatus = "Démarrage de la surveillance…"

        Task { @MainActor [weak self] in
            guard let self, self.audioMonitoringGeneration == generation else { return }
            await self.audioWatchdog.reset()
            guard self.audioMonitoringGeneration == generation,
                  !self.audioMonitor.isRunning else { return }

            do {
                try self.audioMonitor.start { [weak self, audioWatchdog = self.audioWatchdog, generation] sample in
                    Task { @MainActor [weak self] in
                        guard let self,
                              self.audioMonitoringGeneration == generation else { return }
                        if sample.timestamp - self.lastAudioLevelUIUpdateAt >= 0.1 {
                            self.audioLevelDB = sample.rmsDB
                            self.lastAudioLevelUIUpdateAt = sample.timestamp
                        }
                        if let event = await audioWatchdog.ingest(sample) {
                            guard self.audioMonitoringGeneration == generation else { return }
                            self.applyAudioEvent(event)
                        }
                    }
                }
                guard self.audioMonitoringGeneration == generation else {
                    self.audioMonitor.stop()
                    return
                }
                self.audioStatus = "Surveillance active"
            } catch {
                guard self.audioMonitoringGeneration == generation else { return }
                self.audioStatus = "La surveillance audio n’a pas pu démarrer. Vérifie l’entrée sélectionnée et les permissions."
            }
            self.evaluatePreflight()
        }
    }

    func stopAudioMonitoring() {
        audioMonitoringGeneration &+= 1
        audioMonitor.stop()
        Task { await audioWatchdog.reset() }
        audioStatus = "Surveillance arrêtée"
        evaluatePreflight()
    }

    func updateSnapshotForProject() {
        guard let project = preparedProject else { return }
        snapshot = LiveSnapshot(
            state: .idle,
            currentTrack: project.tracks.first?.track,
            nextTrack: project.tracks.dropFirst().first?.track,
            activeDeck: .a,
            completedTransitions: 0,
            totalTransitions: project.transitions.count,
            progress: 0,
            incidents: [],
            statusMessage: "Set préparé"
        )
    }

    func applyAudioEvent(_ event: AudioWatchdogEvent) {
        switch event {
        case .healthy:
            audioStatus = "Surveillance active"
        case .silenceWarning(let duration):
            audioStatus = String(format: "Silence détecté %.1f s", duration)
        case .criticalSilence(let duration):
            audioStatus = String(format: "Silence critique %.1f s", duration)
            if isLiveRunning {
                if emergencyPlayer.currentURL != nil, !emergencyPlayer.isPlaying {
                    emergencyPlayer.play()
                    emergencyStatus = "Musique de secours déclenchée automatiquement"
                }
                takeManualControl()
            }
        case .clipping(let peakDB):
            audioStatus = String(format: "Saturation %.1f dB", peakDB)
        case .sourceUnavailable:
            audioStatus = "Source audio indisponible"
            if isLiveRunning {
                takeManualControl()
            }
        case .sourceRestored:
            audioStatus = "Source audio rétablie"
        }
    }
}
#endif
