#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotMIDI
import MixPilotSystem

public struct LiveRuntimeConfiguration: Codable, Hashable, Sendable {
    public var preloadLeadSeconds: TimeInterval
    public var loadSettleSeconds: TimeInterval
    public var framesPerSecond: Int
    public var speedMultiplier: Double
    public var strictTrackValidation: Bool

    public init(
        preloadLeadSeconds: TimeInterval = 90,
        loadSettleSeconds: TimeInterval = 4,
        framesPerSecond: Int = 30,
        speedMultiplier: Double = 1,
        strictTrackValidation: Bool = false
    ) {
        self.preloadLeadSeconds = max(5, preloadLeadSeconds)
        self.loadSettleSeconds = max(0.5, loadSettleSeconds)
        self.framesPerSecond = max(5, framesPerSecond)
        self.speedMultiplier = max(0.01, speedMultiplier)
        self.strictTrackValidation = strictTrackValidation
    }
}

public enum LiveRuntimeEvent: Hashable, Sendable {
    case preparing(projectName: String)
    case seratoObserved(SeratoWindowObservation)
    case loading(trackIndex: Int, track: Track, deck: DeckID)
    case loaded(trackIndex: Int, track: Track, deck: DeckID, verified: Bool)
    case playing(trackIndex: Int, track: Track, deck: DeckID)
    case preloading(trackIndex: Int, track: Track, deck: DeckID)
    case transitionStarted(index: Int, plan: TransitionPlan, outgoingDeck: DeckID)
    case transitionProgress(index: Int, progress: Double)
    case transitionCompleted(index: Int, summary: TransitionExecutionSummary)
    case warning(String)
    case emergency(String)
    case manualControl
    case completed
}

public enum LiveRuntimeError: Error, LocalizedError {
    case emptyProject
    case projectNotLocked
    case seratoUnavailable
    case accessibilityUnavailable
    case trackValidationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyProject: "Le projet ne contient aucun morceau."
        case .projectNotLocked: "Le plan du set doit être verrouillé avant le mode Live."
        case .seratoUnavailable: "Serato DJ Pro n'est pas disponible."
        case .accessibilityUnavailable: "La permission Accessibilité est nécessaire."
        case .trackValidationFailed(let title): "Le titre chargé n'a pas pu être confirmé : \(title)."
        }
    }
}

public actor LiveAutopilotCoordinator {
    public typealias EventHandler = @Sendable (LiveRuntimeEvent) async -> Void

    private let controller: MappedSeratoController
    private let transitionExecutor: TransitionExecutor
    private let accessibilityBridge: SeratoAccessibilityBridge
    private let checkpointStore: LiveCheckpointStore?
    private let controlPolicy = LiveRuntimeControlPolicy()

    private var activeDeck: DeckID = .a
    private var phase: LiveRuntimePhase = .idle
    private var pausedFromPhase: LiveRuntimePhase?
    private var manualControlRequested = false
    private var skipTransitionRequested = false
    private var incomingTrackVerified = false

    private var currentProject: SetProject?
    private var currentTrackIndex = 0
    private var completedTransitions = 0
    private var nextTransitionIndex: Int?
    private var confirmedTrackID: UUID?
    private var lastCommand: String?
    private var eventHandler: EventHandler?

    public init(
        controller: MappedSeratoController,
        accessibilityBridge: SeratoAccessibilityBridge,
        checkpointStore: LiveCheckpointStore? = LiveAutopilotCoordinator.makeDefaultCheckpointStore()
    ) {
        self.controller = controller
        self.transitionExecutor = TransitionExecutor(sender: controller)
        self.accessibilityBridge = accessibilityBridge
        self.checkpointStore = checkpointStore
    }

    public func requestPause() async -> LiveRuntimeCommandDecision {
        let decision = controlPolicy.pauseDecision(phase: phase)
        guard decision.accepted else { return decision }
        if phase == .paused { return decision }

        pausedFromPhase = phase
        phase = .paused
        lastCommand = "remote:pause"
        await saveCurrentCheckpoint(state: .paused)
        await publishMirror(message: "Autopilot en pause au point sûr courant")
        return decision
    }

    public func requestResume(
        midiReady: Bool,
        audioWatchdogReady: Bool
    ) async -> LiveRuntimeCommandDecision {
        guard phase == .paused else {
            return .reject("L’Autopilot n’est pas en pause.")
        }
        guard let project = currentProject,
              project.tracks.indices.contains(currentTrackIndex) else {
            return .reject("Le projet actif ne permet pas de vérifier la reprise.")
        }

        let expected = project.tracks[currentTrackIndex].track
        let seratoMatches = await verify(track: expected)
        let checkpoint: LiveCheckpoint?
        if let checkpointStore {
            checkpoint = try? await checkpointStore.load()
        } else {
            checkpoint = nil
        }
        let deckMatches = checkpoint?.activeDeck == activeDeck
        let decision = controlPolicy.resumeDecision(
            pausedFrom: pausedFromPhase,
            seratoMatchesCheckpoint: seratoMatches,
            deckMatchesCheckpoint: deckMatches,
            midiReady: midiReady,
            audioWatchdogReady: audioWatchdogReady
        )
        guard decision.accepted else { return decision }

        phase = pausedFromPhase ?? .playing
        pausedFromPhase = nil
        lastCommand = "remote:resume"
        await saveCurrentCheckpoint(state: autopilotState(for: phase))
        await publishMirror(message: "Autopilot repris depuis un point sûr")
        return decision
    }

    public func requestSkipTransition() async -> LiveRuntimeCommandDecision {
        let decision = controlPolicy.skipDecision(
            phase: phase,
            incomingTrackVerified: incomingTrackVerified
        )
        guard decision.accepted else { return decision }
        skipTransitionRequested = true
        lastCommand = "remote:skip-transition-as-safe-fade"
        await saveCurrentCheckpoint(state: .waitingForTransition)
        await publishMirror(message: "La prochaine transition utilisera un Safe Fade contrôlé")
        return decision
    }

    public func requestManualControl() async -> LiveRuntimeCommandDecision {
        if manualControlRequested || phase == .manualControl {
            return .accept("Le contrôle manuel est déjà demandé ; aucune seconde action n’a été exécutée.")
        }

        manualControlRequested = true
        pausedFromPhase = nil
        lastCommand = "remote:manual-control"
        await saveCurrentCheckpoint(state: .manualControl)

        if phase == .transitioning {
            await publishMirror(message: "Contrôle manuel demandé ; la transition en cours se termine sans nouvelle automation ensuite")
            return .accept("Contrôle manuel demandé. La courbe en cours se termine pour éviter une coupure brutale.")
        }

        phase = .manualControl
        await publishMirror(message: "Contrôle manuel demandé")
        return .accept("Contrôle manuel repris ; aucune nouvelle commande automatique ne sera envoyée.")
    }

    public func currentCheckpoint() async -> LiveCheckpoint? {
        try? await checkpointStore?.load()
    }

    public func clearCheckpoint() async {
        try? await checkpointStore?.clear()
    }

    public func run(
        project: SetProject,
        configuration: LiveRuntimeConfiguration = LiveRuntimeConfiguration(),
        onEvent: @escaping EventHandler
    ) async throws {
        guard !project.tracks.isEmpty else { throw LiveRuntimeError.emptyProject }
        guard project.locked else { throw LiveRuntimeError.projectNotLocked }

        await LiveRuntimeCoordinatorRegistry.shared.attach(self)
        currentProject = project
        eventHandler = onEvent
        activeDeck = .a
        currentTrackIndex = 0
        completedTransitions = 0
        nextTransitionIndex = project.transitions.isEmpty ? nil : 0
        confirmedTrackID = nil
        lastCommand = nil
        manualControlRequested = false
        skipTransitionRequested = false
        incomingTrackVerified = false
        pausedFromPhase = nil
        await setPhase(.preflight, message: "Préflight du set")
        await saveCurrentCheckpoint(state: .preflight)

        await onEvent(.preparing(projectName: project.name))
        let initialObservation = await MainActor.run { accessibilityBridge.observe() }
        await onEvent(.seratoObserved(initialObservation))
        guard initialObservation.isRunning else { throw LiveRuntimeError.seratoUnavailable }
        guard initialObservation.accessibilityGranted else { throw LiveRuntimeError.accessibilityUnavailable }
        guard await waitForAutomationPermission() else {
            await finishManualControl()
            return
        }

        try await controller.trigger(.browserFocus)
        let first = project.tracks[0].track
        await setPhase(.loading, message: "Chargement du premier titre")
        await onEvent(.loading(trackIndex: 0, track: first, deck: .a))
        try await controller.trigger(.load(deck: .a))
        lastCommand = SeratoAction.loadA.rawValue
        await saveCurrentCheckpoint(state: .loadingInitialTrack)

        guard try await controlledSleep(
            configuration.loadSettleSeconds,
            multiplier: configuration.speedMultiplier
        ) else {
            await finishManualControl()
            return
        }

        let firstVerified = await verify(track: first)
        confirmedTrackID = firstVerified ? first.id : nil
        await onEvent(.loaded(trackIndex: 0, track: first, deck: .a, verified: firstVerified))
        if configuration.strictTrackValidation && !firstVerified {
            throw LiveRuntimeError.trackValidationFailed(first.title)
        }
        guard await waitForAutomationPermission() else {
            await finishManualControl()
            return
        }

        try await controller.trigger(.play(deck: .a))
        lastCommand = SeratoAction.playA.rawValue
        await setPhase(.playing, message: "Lecture du premier titre")
        await saveCurrentCheckpoint(state: .playing)
        await onEvent(.playing(trackIndex: 0, track: first, deck: .a))

        for index in project.transitions.indices {
            currentTrackIndex = index
            completedTransitions = index
            nextTransitionIndex = index
            incomingTrackVerified = false

            guard await waitForAutomationPermission() else {
                await finishManualControl()
                return
            }

            let currentPrepared = project.tracks[index]
            let incomingPrepared = project.tracks[index + 1]
            let incomingDeck = activeDeck.opposite
            let playDuration = max(5, currentPrepared.analysis.suggestedPlayDuration)
            let preloadLead = min(configuration.preloadLeadSeconds, max(5, playDuration * 0.45))
            let beforePreload = max(0, playDuration - preloadLead)

            await setPhase(.playing, message: "Lecture avant préchargement")
            guard try await controlledSleep(
                beforePreload,
                multiplier: configuration.speedMultiplier
            ) else {
                await finishManualControl()
                return
            }

            await setPhase(.preloading, message: "Préchargement du titre suivant")
            await onEvent(.preloading(
                trackIndex: index + 1,
                track: incomingPrepared.track,
                deck: incomingDeck
            ))
            guard await waitForAutomationPermission() else {
                await finishManualControl()
                return
            }
            try await controller.trigger(.browserDown)
            guard await waitForAutomationPermission() else {
                await finishManualControl()
                return
            }
            try await controller.trigger(.load(deck: incomingDeck))
            lastCommand = SeratoAction.load(deck: incomingDeck).rawValue
            await saveCurrentCheckpoint(state: .preloadingNextTrack)

            guard try await controlledSleep(
                configuration.loadSettleSeconds,
                multiplier: configuration.speedMultiplier
            ) else {
                await finishManualControl()
                return
            }

            incomingTrackVerified = await verify(track: incomingPrepared.track)
            await onEvent(.loaded(
                trackIndex: index + 1,
                track: incomingPrepared.track,
                deck: incomingDeck,
                verified: incomingTrackVerified
            ))
            if !incomingTrackVerified {
                await onEvent(.warning("Titre non confirmé par l'interface Serato : \(incomingPrepared.track.title)"))
                if configuration.strictTrackValidation {
                    throw LiveRuntimeError.trackValidationFailed(incomingPrepared.track.title)
                }
            }

            await setPhase(.waitingForTransition, message: "Titre entrant chargé et transition en attente")
            let remainingLead = max(0, preloadLead - configuration.loadSettleSeconds)
            guard try await controlledSleep(
                remainingLead,
                multiplier: configuration.speedMultiplier
            ) else {
                await finishManualControl()
                return
            }

            var plan = project.transitions[index]
            if skipTransitionRequested {
                plan = controlPolicy.safeReplacement(for: plan)
                skipTransitionRequested = false
                await onEvent(.warning("Transition \(index + 1) remplacée par un Safe Fade contrôlé, sans saut de titre."))
            }

            guard await waitForAutomationPermission() else {
                await finishManualControl()
                return
            }
            await setPhase(.transitioning, message: "Transition automatique en cours")
            lastCommand = "transition:\(plan.id.uuidString)"
            await saveCurrentCheckpoint(state: .transitioning)
            await onEvent(.transitionStarted(index: index, plan: plan, outgoingDeck: activeDeck))

            let summary = try await transitionExecutor.execute(
                plan: plan,
                outgoingDeck: activeDeck,
                framesPerSecond: configuration.framesPerSecond,
                speedMultiplier: configuration.speedMultiplier
            )

            activeDeck = activeDeck.opposite
            currentTrackIndex = index + 1
            completedTransitions = index + 1
            nextTransitionIndex = project.transitions.indices.contains(index + 1) ? index + 1 : nil
            confirmedTrackID = incomingTrackVerified ? incomingPrepared.id : nil
            incomingTrackVerified = false
            lastCommand = SeratoAction.play(deck: activeDeck).rawValue

            if manualControlRequested {
                await finishManualControl()
                return
            }

            await setPhase(.playing, message: "Transition terminée")
            await saveCurrentCheckpoint(state: .playing)
            await onEvent(.transitionCompleted(index: index, summary: summary))
            await onEvent(.playing(
                trackIndex: index + 1,
                track: incomingPrepared.track,
                deck: activeDeck
            ))
        }

        phase = .completed
        currentTrackIndex = max(0, project.tracks.count - 1)
        completedTransitions = project.transitions.count
        nextTransitionIndex = nil
        lastCommand = nil
        await saveCurrentCheckpoint(state: .completed)
        await publishMirror(message: "Set terminé")
        await onEvent(.completed)
    }

    public static func makeDefaultCheckpointStore() -> LiveCheckpointStore {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return LiveCheckpointStore(
            fileURL: root
                .appendingPathComponent("MixPilot Autopilot", isDirectory: true)
                .appendingPathComponent("live-checkpoint.json", isDirectory: false)
        )
    }

    private func setPhase(_ newPhase: LiveRuntimePhase, message: String) async {
        phase = newPhase
        await publishMirror(message: message)
    }

    private func publishMirror(message: String) async {
        let currentPhase = phase
        let pausedFrom = pausedFromPhase
        let incomingVerified = incomingTrackVerified
        await MainActor.run {
            LiveRuntimeControlMirror.shared.update(
                phase: currentPhase,
                pausedFromPhase: pausedFrom,
                incomingTrackVerified: incomingVerified,
                message: message
            )
        }
    }

    private func waitForAutomationPermission() async -> Bool {
        while phase == .paused && !manualControlRequested {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return !manualControlRequested
    }

    private func controlledSleep(
        _ seconds: TimeInterval,
        multiplier: Double
    ) async throws -> Bool {
        var remaining = max(0, seconds / max(0.01, multiplier))
        while remaining > 0 {
            guard await waitForAutomationPermission() else { return false }
            try Task.checkCancellation()
            let interval = min(0.25, remaining)
            try await Task.sleep(for: .seconds(interval))
            remaining -= interval
        }
        return !manualControlRequested
    }

    private func finishManualControl() async {
        phase = .manualControl
        pausedFromPhase = nil
        lastCommand = "manual-control"
        await saveCurrentCheckpoint(state: .manualControl)
        await publishMirror(message: "Contrôle manuel actif")
        await eventHandler?(.manualControl)
    }

    private func saveCurrentCheckpoint(state: AutopilotState) async {
        guard let project = currentProject, let checkpointStore else { return }
        let checkpoint = LiveCheckpoint(
            projectID: project.id,
            projectName: project.name,
            currentTrackIndex: currentTrackIndex,
            activeDeck: activeDeck,
            completedTransitionCount: completedTransitions,
            nextTransitionIndex: nextTransitionIndex,
            state: state,
            lastConfirmedTrackID: confirmedTrackID,
            lastCommand: lastCommand,
            emergencyPlaybackActive: false
        )
        try? await checkpointStore.save(checkpoint)
    }

    private func verify(track: Track) async -> Bool {
        let observation = await MainActor.run {
            accessibilityBridge.observe(maxDepth: 6, maximumStrings: 400)
        }
        let titleFound = observation.contains(text: track.title)
        let artistFound = track.artist.isEmpty || observation.contains(text: track.artist)
        return observation.isRunning && observation.accessibilityGranted && titleFound && artistFound
    }

    private func autopilotState(for phase: LiveRuntimePhase) -> AutopilotState {
        switch phase {
        case .idle: .idle
        case .preflight: .preflight
        case .loading: .loadingInitialTrack
        case .playing: .playing
        case .preloading: .preloadingNextTrack
        case .waitingForTransition: .waitingForTransition
        case .transitioning: .transitioning
        case .paused: .paused
        case .manualControl: .manualControl
        case .completed: .completed
        case .failed: .failed
        }
    }
}
#endif
