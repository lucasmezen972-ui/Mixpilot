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
            runtimeStatus = AppLocalizedCopy.status("status.preparation.choose_backend_import")
            return
        }
        let rows = accessibilityBridge.libraryRows(backend: selectedBackend, maxRows: 1_000)
        libraryRowCount = rows.count
        let result = VisiblePlaylistImporter().importRows(rows)
        playlistWarnings = result.warnings
        guard !result.tracks.isEmpty else {
            runtimeStatus = AppLocalizedCopy.status("status.preparation.no_visible_playlist")
            return
        }
        let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
        preparedProject = SetPreparationEngine().prepare(
            name: AppLocalizedCopy.statusFormat(
                "status.preparation.project_name",
                selectedBackend.displayName,
                timestamp
            ),
            tracks: result.tracks,
            backend: selectedBackend
        )
        optimizationReport = SetOptimizer().analyze(tracks: result.tracks)
        runtimeStatus = AppLocalizedCopy.statusFormat(
            "status.preparation.tracks_prepared",
            result.tracks.count,
            selectedBackend.displayName
        )
        updateSnapshotForProject()
        evaluatePreflight()
    }

    @available(*, deprecated, message: "Use capturePlaylist()")
    func captureSeratoPlaylist() { capturePlaylist() }

    func createDemoProject() {
        let tracks = SetSimulator().makeTracks(count: 30)
        preparedProject = SetPreparationEngine().prepare(
            name: AppLocalizedCopy.status("status.preparation.demo_name"),
            tracks: tracks,
            backend: selectedBackend
        )
        optimizationReport = SetOptimizer().analyze(tracks: tracks)
        playlistWarnings = []
        runtimeStatus = selectedBackend.map {
            AppLocalizedCopy.statusFormat("status.preparation.demo_for_backend", $0.displayName)
        } ?? AppLocalizedCopy.status("status.preparation.demo_choose_backend")
        updateSnapshotForProject()
        evaluatePreflight()
    }

    func lockPreparedProject() {
        guard var project = preparedProject else { return }
        guard let selectedBackend else {
            runtimeStatus = AppLocalizedCopy.status("status.preparation.choose_backend_lock")
            return
        }
        project.selectBackend(selectedBackend)
        project.lock()
        preparedProject = project
        Task { try? await projectStore.save(project) }
        runtimeStatus = AppLocalizedCopy.statusFormat(
            "status.preparation.plan_locked",
            selectedBackend.displayName
        )
        evaluatePreflight()
    }

    func selectEmergencyAudio() {
        let panel = NSOpenPanel()
        panel.title = AppLocalizedCopy.status("status.preparation.emergency_panel_title")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav, .aiff, .audio]
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        do {
            let summary = try emergencyPlayer.prepare(urls: panel.urls)
            emergencyDuration = summary.totalDuration
            emergencyStatus = AppLocalizedCopy.statusFormat(
                "status.preparation.emergency_summary",
                summary.fileCount,
                Int(summary.totalDuration / 60)
            )
            if !summary.invalidFiles.isEmpty {
                emergencyStatus += AppLocalizedCopy.statusFormat(
                    "status.preparation.emergency_invalid",
                    summary.invalidFiles.count
                )
            }
        } catch {
            emergencyDuration = 0
            emergencyStatus = AppLocalizedCopy.status("status.preparation.emergency_failed")
        }
        evaluatePreflight()
    }

    func playEmergencyAudio() {
        emergencyPlayer.play()
        emergencyStatus = AppLocalizedCopy.status("status.preparation.emergency_playing")
    }

    func stopEmergencyAudio() {
        emergencyPlayer.stop()
        emergencyStatus = AppLocalizedCopy.status("status.preparation.emergency_stopped")
    }

    func startAudioMonitoring() {
        guard !audioMonitor.isRunning, !audioMonitoringStarting else { return }
        audioMonitoringStarting = true
        audioMonitoringGeneration &+= 1
        let generation = audioMonitoringGeneration
        lastAudioLevelUIUpdateAt = 0
        audioStatus = AppLocalizedCopy.status("status.preparation.audio_starting")

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.audioMonitoringGeneration == generation else {
                self.audioMonitoringStarting = false
                return
            }
            await self.audioWatchdog.reset()
            guard self.audioMonitoringGeneration == generation,
                  !self.audioMonitor.isRunning else {
                self.audioMonitoringStarting = false
                return
            }

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
                    self.audioMonitoringStarting = false
                    return
                }
                self.audioMonitoringStarting = false
                self.audioStatus = AppLocalizedCopy.status("status.preparation.audio_active")
            } catch {
                guard self.audioMonitoringGeneration == generation else {
                    self.audioMonitoringStarting = false
                    return
                }
                self.audioMonitoringStarting = false
                self.audioStatus = AppLocalizedCopy.status("status.preparation.audio_start_failed")
            }
            self.evaluatePreflight()
        }
    }

    func stopAudioMonitoring() {
        audioMonitoringGeneration &+= 1
        audioMonitoringStarting = false
        audioMonitor.stop()
        Task { await audioWatchdog.reset() }
        audioStatus = AppLocalizedCopy.status("status.preparation.audio_stopped")
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
            statusMessage: AppLocalizedCopy.status("status.preparation.set_prepared")
        )
    }

    func applyAudioEvent(_ event: AudioWatchdogEvent) {
        switch event {
        case .healthy:
            audioStatus = AppLocalizedCopy.status("status.preparation.audio_active")
        case .silenceWarning(let duration):
            audioStatus = AppLocalizedCopy.statusFormat(
                "status.preparation.silence_warning",
                duration
            )
        case .criticalSilence(let duration):
            audioStatus = AppLocalizedCopy.statusFormat(
                "status.preparation.critical_silence",
                duration
            )
            if isLiveRunning {
                if emergencyPlayer.currentURL != nil, !emergencyPlayer.isPlaying {
                    emergencyPlayer.play()
                    emergencyStatus = AppLocalizedCopy.status("status.preparation.emergency_auto")
                }
                takeManualControl()
            }
        case .clipping(let peakDB):
            audioStatus = AppLocalizedCopy.statusFormat(
                "status.preparation.clipping",
                peakDB
            )
        case .sourceUnavailable:
            audioStatus = AppLocalizedCopy.status("status.preparation.source_unavailable")
            if isLiveRunning {
                takeManualControl()
            }
        case .sourceRestored:
            audioStatus = AppLocalizedCopy.status("status.preparation.source_restored")
        }
    }
}
#endif
