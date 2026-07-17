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

        let rows = accessibilityBridge.libraryRows(
            software: legacySoftware(selectedBackend),
            maxRows: 1_000
        )
        libraryRowCount = rows.count
        let result = SeratoPlaylistImporter().importRows(rows)
        playlistWarnings = result.warnings

        guard !result.tracks.isEmpty else {
            runtimeStatus = "Aucune playlist exploitable n’est visible. Ouvre la playlist souhaitée, puis relance l’import."
            return
        }

        preparedProject = SetPreparationEngine().prepare(
            name: "Playlist \(selectedBackend.displayName) — \(Date().formatted(date: .abbreviated, time: .shortened))",
            tracks: result.tracks
        )
        optimizationReport = SetOptimizer().analyze(tracks: result.tracks)
        runtimeStatus = "\(result.tracks.count) morceaux préparés"
        updateSnapshotForProject()
        evaluatePreflight()
    }

    @available(*, deprecated, message: "Use capturePlaylist()")
    func captureSeratoPlaylist() {
        capturePlaylist()
    }

    func createDemoProject() {
        let tracks = SetSimulator().makeTracks(count: 30)
        preparedProject = SetPreparationEngine().prepare(
            name: "Set de démonstration",
            tracks: tracks
        )
        optimizationReport = SetOptimizer().analyze(tracks: tracks)
        playlistWarnings = []
        runtimeStatus = "Set de démonstration préparé"
        updateSnapshotForProject()
        evaluatePreflight()
    }

    func lockPreparedProject() {
        guard var project = preparedProject else { return }
        project.lock()
        preparedProject = project
        Task { try? await projectStore.save(project) }
        runtimeStatus = "Plan verrouillé • prêt pour la vérification"
        evaluatePreflight()
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
            let minutes = Int(summary.totalDuration / 60)
            emergencyStatus = "\(summary.fileCount) fichiers • \(minutes) min"
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
        guard !audioMonitor.isRunning else { return }
        do {
            try audioMonitor.start { [weak self, audioWatchdog] sample in
                Task { @MainActor [weak self] in
                    let event = await audioWatchdog.ingest(sample)
                    self?.audioLevelDB = sample.rmsDB
                    self?.applyAudioEvent(event)
                    self?.evaluatePreflight()
                }
            }
            audioStatus = "Surveillance active"
        } catch {
            audioStatus = "La surveillance audio n’a pas pu démarrer. Vérifie l’entrée sélectionnée et les permissions."
        }
        evaluatePreflight()
    }

    func stopAudioMonitoring() {
        audioMonitor.stop()
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
            if isLiveRunning,
               emergencyPlayer.currentURL != nil,
               !emergencyPlayer.isPlaying {
                emergencyPlayer.play()
                emergencyStatus = "Musique de secours déclenchée automatiquement"
            }
        case .clipping(let peakDB):
            audioStatus = String(format: "Saturation %.1f dB", peakDB)
        case .sourceUnavailable:
            audioStatus = "Source audio indisponible"
        case .sourceRestored:
            audioStatus = "Source audio rétablie"
        }
    }
}
#endif
