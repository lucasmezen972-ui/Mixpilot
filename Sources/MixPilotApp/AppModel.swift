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
    @Published private(set) var backendStatus = "Choisis ton logiciel DJ"
    @Published private(set) var selectedBackend: DJBackendIdentifier?
    @Published private(set) var backendDescriptors: [DJBackendDescriptor] = []
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

    /// Temporary source-compatibility for views not migrated yet. It now
    /// reflects the selected backend and is no longer Serato-specific.
    var seratoStatus: String { backendStatus }

    private var midiController: CoreMIDIController?
    private var mappedController: MappedMIDIController?
    private var mappingStore: MIDIMappingProfileStore?
    private var backendRegistry: DJBackendRegistry?
    private var runtimeCoordinator: LiveAutopilotCoordinator?
    private var liveTask: Task<Void, Never>?

    private let accessibilityBridge = SeratoAccessibilityBridge()
    private let commandValidationStore = UserDefaultsDJCommandValidationStore()
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
        configureMIDI()
        refreshEnvironment()
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

    func selectBackend(_ identifier: DJBackendIdentifier) {
        guard !isLiveRunning else {
            runtimeStatus = "Le logiciel DJ ne peut pas être changé pendant le Live. Reprends la main avant de changer."
            return
        }
        Task {
            do {
                guard let backendRegistry else { throw DJBackendError.unavailable(identifier) }
                try await backendRegistry.select(identifier)
                selectedBackend = identifier
                DJSoftwareSelectionStore.current = legacySoftware(identifier)
                try await rebuildRuntimeCoordinator()
                await refreshEnvironmentNow()
            } catch {
                runtimeStatus = humanMessage(for: error)
            }
        }
    }

    func refreshEnvironment() {
        powerStatus = powerProbe.read()
        Task { await refreshEnvironmentNow() }
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
            midiStatus = "Contrôleur virtuel actif"

            Task {
                let profile = (try? await store.load()) ?? .developmentDefault
                mappingProfile = profile
                let mapped = MappedMIDIController(controller: controller, profile: profile)
                mappedController = mapped
                let registry = DJBackendRegistry(
                    backends: [
                        DjayBackend(midi: mapped, validationStore: commandValidationStore),
                        RekordboxBackend(midi: mapped, validationStore: commandValidationStore),
                        SeratoBackend(midi: mapped, validationStore: commandValidationStore),
                    ]
                )
                backendRegistry = registry
                selectedBackend = await registry.restoreSelection()
                if let selectedBackend {
                    DJSoftwareSelectionStore.current = legacySoftware(selectedBackend)
                    try? await rebuildRuntimeCoordinator()
                }
                midiStatus = "Contrôleur actif • \(Int(profile.completionRatio * 100)) % configuré"
                await refreshEnvironmentNow()
            }
        } catch {
            midiStatus = "Le contrôleur MIDI n’a pas pu être créé. Ferme les autres outils MIDI, puis réessaie."
            runtimeStatus = humanMessage(for: error)
            evaluatePreflight()
        }
    }

    func resetDefaultMapping() {
        mappingProfile = .developmentDefault
        Task {
            await mappedController?.replaceProfile(mappingProfile)
            _ = try? await mappingStore?.save(mappingProfile)
            midiStatus = "Profil par défaut chargé"
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
                midiStatus = "Le mapping n’a pas pu être sauvegardé. Vérifie l’espace disponible, puis réessaie."
            }
        }
    }

    func testMapping(_ action: DJControlAction) {
        Task {
            do {
                if let mapping = mappingProfile[action], mapping.kind == .controlChange {
                    try await mappedController?.set(action, value: 0.5)
                } else {
                    try await mappedController?.trigger(action)
                }
                midiStatus = "Commande envoyée. Confirme maintenant la réaction du logiciel DJ."
            } catch {
                midiStatus = "La commande n’a pas pu être envoyée. Vérifie le mapping et la connexion MIDI."
                runtimeStatus = humanMessage(for: error)
            }
        }
    }

    func recordMappingValidation(_ action: DJControlAction, succeeded: Bool) {
        guard let selectedBackend else {
            midiStatus = "Choisis d’abord le logiciel DJ à tester."
            return
        }
        Task {
            let environment = await backendRegistry?.availableBackends()
                .first { $0.identifier == selectedBackend }?.environment
            let key = DJCommandValidationKey(
                backend: selectedBackend,
                softwareVersion: environment?.softwareVersion,
                controllerName: "MixPilot Virtual Controller",
                mappingVersion: "profile-\(mappingProfile.schemaVersion)",
                action: action
            )
            let record = DJCommandValidationRecord(
                key: key,
                status: succeeded ? .automatedSuccess : .failed,
                detail: succeeded ? "DEVICE_CONFIRMED" : "DEVICE_REJECTED"
            )
            try? await commandValidationStore.record(record)
            midiStatus = succeeded
                ? "Commande confirmée avec \(selectedBackend.displayName)."
                : "Commande marquée comme non fonctionnelle. MixPilot ne l’utilisera pas en Live."
            await refreshEnvironmentNow()
        }
    }

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

    func captureSeratoPlaylist() {
        capturePlaylist()
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

    func evaluatePreflight() {
        let project = preparedProject
        let environment = selectedBackend.flatMap { identifier in
            backendDescriptors.first { $0.identifier == identifier }?.environment
        }
        preflightReport = PreflightEvaluator().evaluate(PreflightInput(
            seratoRunning: environment?.isRunning == true,
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
            await runtimeCoordinator?.requestManualControl()
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

    private func refreshEnvironmentNow() async {
        guard let backendRegistry else {
            backendStatus = "Initialisation des logiciels DJ"
            evaluatePreflight()
            return
        }

        backendDescriptors = await backendRegistry.availableBackends()
        selectedBackend = await backendRegistry.selectedBackend()
        guard let selectedBackend,
              let descriptor = backendDescriptors.first(where: { $0.identifier == selectedBackend }) else {
            backendStatus = "Choisis djay Pro, rekordbox ou Serato DJ Pro"
            accessibilityStatus = "En attente du choix"
            libraryRowCount = 0
            runtimeCoordinator = nil
            evaluatePreflight()
            return
        }

        backendStatus = descriptor.environment.isRunning
            ? "\(descriptor.displayName) connecté\(descriptor.environment.softwareVersion.map { " • v\($0)" } ?? "")"
            : descriptor.environment.isInstalled
                ? "\(descriptor.displayName) est installé mais fermé"
                : "\(descriptor.displayName) n’est pas installé"

        let observation = accessibilityBridge.observe(software: legacySoftware(selectedBackend))
        accessibilityStatus = observation.accessibilityGranted ? "Autorisée" : "Action requise"
        audioStatus = audioMonitor.isRunning ? "Surveillance active" : "Surveillance arrêtée"
        libraryRowCount = observation.accessibilityGranted
            ? accessibilityBridge.libraryRows(software: legacySoftware(selectedBackend), maxRows: 1_000).count
            : 0
        if observation.isRunning && observation.accessibilityGranted {
            runtimeStatus = "\(descriptor.displayName) observable"
        }
        try? await rebuildRuntimeCoordinator()
        evaluatePreflight()
    }

    private func rebuildRuntimeCoordinator() async throws {
        guard !isLiveRunning else { throw DJBackendError.liveChangeForbidden }
        guard let backendRegistry else { return }
        let backend = try await backendRegistry.activeBackend()
        runtimeCoordinator = LiveAutopilotCoordinator(backend: backend)
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

    private func applyRuntimeEvent(_ event: LiveRuntimeEvent, project: SetProject) {
        runtimeEvents.append(describe(event))
        if runtimeEvents.count > 100 { runtimeEvents.removeFirst(runtimeEvents.count - 100) }

        switch event {
        case .preparing:
            snapshot.state = .preflight
            snapshot.statusMessage = "Vérification du système"
        case .backendObserved(let environment):
            backendStatus = environment.isRunning
                ? "\(environment.identifier.displayName) connecté"
                : "\(environment.identifier.displayName) hors ligne"
        case .loading(let index, let track, let deck), .preloading(let index, let track, let deck):
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
            snapshot.nextTrack = project.tracks.indices.contains(index + 1) ? project.tracks[index + 1].track : nil
            snapshot.activeDeck = deck
            snapshot.completedTransitions = index
            snapshot.progress = project.transitions.isEmpty ? 1 : Double(index) / Double(project.transitions.count)
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

    private func describe(_ event: LiveRuntimeEvent) -> String {
        switch event {
        case .preparing(let name): "Préparation : \(name)"
        case .backendObserved(let environment): "Backend : \(environment.identifier.displayName)"
        case .loading(_, let track, let deck): "Chargement \(track.title) → deck \(deck.rawValue)"
        case .loaded(_, let track, _, let verified): "\(track.title) • \(verified ? "confirmé" : "non confirmé")"
        case .playing(_, let track, let deck): "Lecture \(track.title) • deck \(deck.rawValue)"
        case .preloading(_, let track, let deck): "Préchargement \(track.title) • deck \(deck.rawValue)"
        case .transitionAdapted(_, let original, let selected, _): "Transition adaptée : \(original.rawValue) → \(selected.rawValue)"
        case .transitionStarted(let index, let plan, _): "Transition \(index + 1) : \(plan.kind.rawValue)"
        case .transitionProgress(let index, let progress): "Transition \(index + 1) : \(Int(progress * 100)) %"
        case .transitionCompleted(let index, _): "Transition \(index + 1) terminée"
        case .warning(let message): "Avertissement : \(message)"
        case .emergency(let message): "Secours : \(message)"
        case .manualControl: "Contrôle manuel"
        case .completed: "Set terminé"
        }
    }

    private func legacySoftware(_ identifier: DJBackendIdentifier) -> DJSoftware {
        switch identifier {
        case .djay: .djay
        case .rekordbox: .rekordbox
        case .serato: .serato
        }
    }

    private func humanMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let message = localized.errorDescription,
           !message.isEmpty {
            return message
        }
        return "Une étape n’a pas pu être terminée. Le Live reste arrêté et le contrôle manuel est disponible."
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case onboarding = "Configuration"
    case dashboard = "Tableau de bord"
    case studio = "Studio"
    case mapping = "Mapping MIDI"
    case preflight = "Vérification"
    case live = "Live"
    case feasibility = "Avancé"
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
        case .feasibility: "gearshape.2"
        case .diagnostics: "stethoscope"
        }
    }
}
#endif
