#if os(macOS)
import AppKit
import Combine
import Foundation
import MixPilotCore
import MixPilotMIDI
import MixPilotRuntime
import MixPilotSystem
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot = LiveSnapshot(
        state: .idle,
        currentTrack: nil,
        nextTrack: nil,
        activeDeck: .a,
        completedTransitions: 0,
        totalTransitions: 0,
        progress: 0,
        incidents: [],
        statusMessage: "Prêt à préparer un set"
    )
    @Published private(set) var report: SimulationReport?
    @Published private(set) var isRunningSimulation = false
    @Published private(set) var midiStatus = "Non testé"
    @Published private(set) var seratoStatus = "Non détecté"
    @Published private(set) var accessibilityStatus = "Non autorisée"
    @Published private(set) var audioStatus = "Non testée"
    @Published private(set) var audioLevelDB = -160.0
    @Published private(set) var libraryRowCount = 0
    @Published private(set) var preparedProject: SetProject?
    @Published private(set) var playlistWarnings: [PlaylistImportWarning] = []
    @Published private(set) var mappingProfile = MIDIMappingProfile.developmentDefault
    @Published private(set) var emergencyStatus = "Aucun fichier sélectionné"
    @Published private(set) var emergencyDuration: TimeInterval = 0
    @Published private(set) var runtimeStatus = "Inactif"
    @Published private(set) var runtimeEvents: [String] = []
    @Published private(set) var isLiveRunning = false
    @Published private(set) var liveArmed = false
    @Published private(set) var connectivityStatus = ConnectivityStatus(
        isAvailable: false,
        isExpensive: false,
        interfaceDescription: "Initialisation"
    )
    @Published private(set) var powerStatus = PowerStatus(
        connectedToPower: false,
        batteryLevel: nil,
        lowPowerModeEnabled: false
    )
    @Published private(set) var preflightReport = PreflightReport(items: [])
    @Published private(set) var optimizationReport: SetOptimizationReport?
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published var selectedSection: SidebarSection = .dashboard

    private var midiController: CoreMIDIController?
    private var mappedController: MappedSeratoController?
    private var mappingStore: MIDIMappingProfileStore?
    private var runtimeCoordinator: LiveAutopilotCoordinator?
    private var liveTask: Task<Void, Never>?

    private let environmentProbe = SeratoEnvironmentProbe()
    private let accessibilityBridge = SeratoAccessibilityBridge()
    private let audioMonitor = AudioLevelMonitor()
    private let audioWatchdog = AudioWatchdog()
    private let emergencyPlayer = EmergencyAudioPlayer()
    private let connectivityMonitor = ConnectivityMonitor()
    private let powerProbe = PowerStatusProbe()
    private let sleepAssertion = SleepAssertionManager()
    private let projectStore: JSONProjectStore

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "MixPilotOnboardingCompleted")
        let supportRoot = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        projectStore = JSONProjectStore(
            directory: supportRoot
                .appendingPathComponent("MixPilot Autopilot", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
        )

        connectivityMonitor.start { [weak self] status in
            Task { @MainActor [weak self] in
                self?.connectivityStatus = status
                self?.evaluatePreflight()
            }
        }
        refreshEnvironment()
        configureMIDI()
    }

    deinit {
        liveTask?.cancel()
        audioMonitor.stop()
        connectivityMonitor.stop()
        sleepAssertion.release()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "MixPilotOnboardingCompleted")
        selectedSection = .studio
    }

    func restartOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "MixPilotOnboardingCompleted")
        selectedSection = .onboarding
    }

    func refreshEnvironment() {
        let result = environmentProbe.probe()
        let observation = accessibilityBridge.observe()
        seratoStatus = result.isRunning ? "Serato détecté" : "Serato non lancé"
        accessibilityStatus = result.accessibilityGranted ? "Autorisée" : "Action requise"
        audioStatus = audioMonitor.isRunning ? "Surveillance active" : result.audioPermission
        libraryRowCount = result.accessibilityGranted
            ? accessibilityBridge.libraryRows(maxRows: 1_000).count
            : 0
        powerStatus = powerProbe.read()

        if observation.isRunning && observation.accessibilityGranted {
            runtimeStatus = "Serato observable"
        }
        evaluatePreflight()
    }

    func requestAccessibility() {
        accessibilityBridge.requestAccessibilityPrompt()
        refreshEnvironment()
    }

    func configureMIDI() {
        guard midiController == nil else {
            evaluatePreflight()
            return
        }
        do {
            let controller = try CoreMIDIController()
            let store = MIDIMappingProfileStore()
            midiController = controller
            mappingStore = store
            midiStatus = "Port virtuel actif"

            Task {
                let profile = (try? await store.load()) ?? .developmentDefault
                mappingProfile = profile
                let mapped = MappedSeratoController(controller: controller, profile: profile)
                mappedController = mapped
                runtimeCoordinator = LiveAutopilotCoordinator(
                    controller: mapped,
                    accessibilityBridge: accessibilityBridge
                )
                midiStatus = "Port actif • \(Int(profile.completionRatio * 100)) % mappé"
                evaluatePreflight()
            }
        } catch {
            midiStatus = "Échec : \(error.localizedDescription)"
            evaluatePreflight()
        }
    }

    func resetDefaultMapping() {
        mappingProfile = .developmentDefault
        Task {
            await mappedController?.replaceProfile(mappingProfile)
            _ = try? await mappingStore?.save(mappingProfile)
            midiStatus = "Port actif • profil par défaut chargé"
            evaluatePreflight()
        }
    }

    func saveMapping() {
        Task {
            do {
                _ = try await mappingStore?.save(mappingProfile)
                await mappedController?.replaceProfile(mappingProfile)
                midiStatus = "Mapping sauvegardé"
                evaluatePreflight()
            } catch {
                midiStatus = "Échec sauvegarde : \(error.localizedDescription)"
            }
        }
    }

    func testMapping(_ action: SeratoAction) {
        Task {
            do {
                if let mapping = mappingProfile[action], mapping.kind == .controlChange {
                    try await mappedController?.set(action, value: 0.5)
                } else {
                    try await mappedController?.trigger(action)
                }
                midiStatus = "Test envoyé : \(action.rawValue)"
            } catch {
                midiStatus = "Échec test \(action.rawValue) : \(error.localizedDescription)"
            }
        }
    }

    func captureSeratoPlaylist() {
        let rows = accessibilityBridge.libraryRows(maxRows: 1_000)
        libraryRowCount = rows.count
        let result = SeratoPlaylistImporter().importRows(rows)
        playlistWarnings = result.warnings

        guard !result.tracks.isEmpty else {
            runtimeStatus = "Aucune ligne de playlist exploitable détectée"
            return
        }

        preparedProject = SetPreparationEngine().prepare(
            name: "Playlist Serato — \(Date().formatted(date: .abbreviated, time: .shortened))",
            tracks: result.tracks
        )
        optimizationReport = SetOptimizer().analyze(tracks: result.tracks)
        runtimeStatus = "\(result.tracks.count) titres préparés"
        updateSnapshotForProject()
        evaluatePreflight()
    }

    func createDemoProject() {
        let tracks = SetSimulator().makeTracks(count: 30)
        preparedProject = SetPreparationEngine().prepare(name: "Set de démonstration", tracks: tracks)
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
        runtimeStatus = "Plan verrouillé • prêt pour le préflight"
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
                emergencyStatus += " • \(summary.invalidFiles.count) invalide(s)"
            }
        } catch {
            emergencyDuration = 0
            emergencyStatus = "Erreur : \(error.localizedDescription)"
        }
        evaluatePreflight()
    }

    func playEmergencyAudio() {
        emergencyPlayer.play()
        emergencyStatus = "Secours en lecture"
    }

    func stopEmergencyAudio() {
        emergencyPlayer.stop()
        emergencyStatus = "Secours arrêté"
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
            audioStatus = "Échec : \(error.localizedDescription)"
        }
        evaluatePreflight()
    }

    func stopAudioMonitoring() {
        audioMonitor.stop()
        audioStatus = "Surveillance arrêtée"
        evaluatePreflight()
    }

    func evaluatePreflight() {
        let project = preparedProject
        preflightReport = PreflightEvaluator().evaluate(PreflightInput(
            seratoRunning: environmentProbe.probe().isRunning,
            accessibilityGranted: accessibilityStatus == "Autorisée",
            midiAvailable: midiController != nil,
            mappingCompletion: mappingProfile.completionRatio,
            audioMonitorRunning: audioMonitor.isRunning,
            internetAvailable: connectivityStatus.isAvailable,
            connectedToPower: powerStatus.connectedToPower,
            batteryLevel: powerStatus.batteryLevel,
            emergencyAudioReady: emergencyDuration >= 1_800,
            emergencyDuration: emergencyDuration,
            projectPrepared: project != nil,
            projectLocked: project?.locked == true,
            trackCount: project?.tracks.count ?? 0,
            transitionCount: project?.transitions.count ?? 0,
            lowConfidenceTransitionCount: project?.reviewTransitionCount ?? 0
        ))
    }

    func armLive() {
        refreshEnvironment()
        guard preflightReport.canStartLive else {
            liveArmed = false
            runtimeStatus = "Préflight incomplet : \(preflightReport.failedItems.count) blocage(s)"
            selectedSection = .preflight
            return
        }
        liveArmed.toggle()
        runtimeStatus = liveArmed ? "Mode Live armé" : "Mode Live désarmé"
    }

    func startLive() {
        refreshEnvironment()
        guard liveArmed else {
            runtimeStatus = "Arme le mode Live avant le lancement"
            return
        }
        guard preflightReport.canStartLive else {
            runtimeStatus = "Le préflight contient encore des erreurs critiques"
            selectedSection = .preflight
            return
        }
        guard let project = preparedProject, project.locked else {
            runtimeStatus = "Le projet doit être préparé et verrouillé"
            return
        }
        guard let coordinator = runtimeCoordinator, !isLiveRunning else { return }

        do {
            try sleepAssertion.acquire()
        } catch {
            runtimeStatus = "Avertissement veille : \(error.localizedDescription)"
        }
        isLiveRunning = true
        runtimeEvents = []
        runtimeStatus = "Démarrage du préflight"
        liveTask = Task {
            do {
                try await coordinator.run(project: project) { [weak self] event in
                    await MainActor.run {
                        self?.applyRuntimeEvent(event, project: project)
                    }
                }
            } catch is CancellationError {
                runtimeStatus = "Autopilot arrêté"
            } catch {
                runtimeStatus = "Erreur Live : \(error.localizedDescription)"
            }
            isLiveRunning = false
            liveArmed = false
            sleepAssertion.release()
        }
    }

    func takeManualControl() {
        liveTask?.cancel()
        liveTask = nil
        Task { await runtimeCoordinator?.requestManualControl() }
        sleepAssertion.release()
        isLiveRunning = false
        liveArmed = false
        snapshot.state = .manualControl
        snapshot.statusMessage = "Contrôle manuel repris"
        runtimeStatus = "Contrôle manuel"
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
                snapshot.statusMessage = "Simulation interrompue : \(error.localizedDescription)"
            }
            isRunningSimulation = false
        }
    }

    private func updateSnapshotForProject() {
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

    private func applyAudioEvent(_ event: AudioWatchdogEvent) {
        switch event {
        case .healthy:
            audioStatus = "Surveillance active"
        case .silenceWarning(let duration):
            audioStatus = String(format: "Silence détecté %.1f s", duration)
        case .criticalSilence(let duration):
            audioStatus = String(format: "Silence critique %.1f s", duration)
            if isLiveRunning, emergencyPlayer.currentURL != nil, !emergencyPlayer.isPlaying {
                emergencyPlayer.play()
                emergencyStatus = "Secours déclenché automatiquement"
            }
        case .clipping(let peakDB):
            audioStatus = String(format: "Saturation %.1f dB", peakDB)
        case .sourceUnavailable:
            audioStatus = "Source audio indisponible"
        case .sourceRestored:
            audioStatus = "Source audio rétablie"
        }
    }

    private func applyRuntimeEvent(_ event: LiveRuntimeEvent, project: SetProject) {
        runtimeEvents.append(describe(event))
        if runtimeEvents.count > 100 { runtimeEvents.removeFirst(runtimeEvents.count - 100) }

        switch event {
        case .preparing:
            snapshot.state = .preflight
            snapshot.statusMessage = "Préflight du set"
        case .loading(let index, let track, let deck), .preloading(let index, let track, let deck):
            snapshot.state = index == 0 ? .loadingInitialTrack : .preloadingNextTrack
            snapshot.nextTrack = track
            snapshot.statusMessage = "Chargement de \(track.title) sur le deck \(deck.rawValue)"
        case .loaded(_, let track, _, let verified):
            runtimeStatus = verified ? "Titre confirmé : \(track.title)" : "Titre chargé, confirmation en attente"
        case .playing(let index, let track, let deck):
            snapshot.state = .playing
            snapshot.currentTrack = track
            snapshot.nextTrack = project.tracks.indices.contains(index + 1) ? project.tracks[index + 1].track : nil
            snapshot.activeDeck = deck
            snapshot.completedTransitions = index
            snapshot.progress = project.transitions.isEmpty ? 1 : Double(index) / Double(project.transitions.count)
            snapshot.statusMessage = "Lecture : \(track.title)"
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
            runtimeStatus = "Avertissement : \(message)"
        case .emergency(let message):
            snapshot.state = .emergencyPlayback
            runtimeStatus = message
        case .manualControl:
            snapshot.state = .manualControl
            runtimeStatus = "Contrôle manuel"
        case .completed:
            snapshot.state = .completed
            snapshot.progress = 1
            snapshot.statusMessage = "Set terminé"
            runtimeStatus = "Terminé"
        case .seratoObserved:
            break
        }
    }

    private func describe(_ event: LiveRuntimeEvent) -> String {
        switch event {
        case .preparing(let name): "Préparation : \(name)"
        case .seratoObserved(let observation): observation.isRunning ? "Serato observé" : "Serato absent"
        case .loading(_, let track, let deck): "Chargement \(track.title) → deck \(deck.rawValue)"
        case .loaded(_, let track, _, let verified): "\(track.title) • \(verified ? "confirmé" : "non confirmé")"
        case .playing(_, let track, let deck): "Lecture \(track.title) • deck \(deck.rawValue)"
        case .preloading(_, let track, let deck): "Préchargement \(track.title) • deck \(deck.rawValue)"
        case .transitionStarted(let index, let plan, _): "Transition \(index + 1) : \(plan.kind.rawValue)"
        case .transitionProgress(let index, let progress): "Transition \(index + 1) : \(Int(progress * 100)) %"
        case .transitionCompleted(let index, _): "Transition \(index + 1) terminée"
        case .warning(let message): "Avertissement : \(message)"
        case .emergency(let message): "Secours : \(message)"
        case .manualControl: "Contrôle manuel"
        case .completed: "Set terminé"
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case onboarding = "Configuration"
    case dashboard = "Tableau de bord"
    case studio = "Studio"
    case mapping = "Mapping MIDI"
    case preflight = "Préflight"
    case live = "Live"
    case feasibility = "Feasibility Lab"
    case diagnostics = "Diagnostics"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .onboarding: "wand.and.stars"
        case .dashboard: "rectangle.grid.2x2"
        case .studio: "waveform.path.ecg"
        case .mapping: "slider.horizontal.3"
        case .preflight: "checkmark.shield"
        case .live: "play.circle"
        case .feasibility: "checklist"
        case .diagnostics: "stethoscope"
        }
    }
}
#endif
