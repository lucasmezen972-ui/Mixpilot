#if os(macOS)
import Foundation
import MixPilotCore
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
    case backendObserved(DJBackendEnvironment)
    case loading(trackIndex: Int, track: Track, deck: DeckID)
    case loaded(trackIndex: Int, track: Track, deck: DeckID, verified: Bool)
    case playing(trackIndex: Int, track: Track, deck: DeckID)
    case preloading(trackIndex: Int, track: Track, deck: DeckID)
    case transitionAdapted(index: Int, original: TransitionKind, selected: TransitionKind, explanation: String)
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
    case backendUnavailable(String)
    case configurationBlocked(String)
    case transitionUnavailable(String)
    case trackValidationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyProject:
            "Le projet ne contient aucun morceau."
        case .projectNotLocked:
            "Le plan du set doit être verrouillé avant le Live."
        case .backendUnavailable(let name):
            "La connexion avec \(name) n’est pas disponible. Lance le logiciel et relance la vérification."
        case .configurationBlocked(let detail):
            detail
        case .transitionUnavailable(let detail):
            detail
        case .trackValidationFailed(let title):
            "Le morceau chargé n’a pas pu être confirmé : \(title). Reprends la main et vérifie le deck avant de continuer."
        }
    }
}

public actor LiveAutopilotCoordinator {
    public typealias EventHandler = @Sendable (LiveRuntimeEvent) async -> Void

    private let backend: any DJBackend
    private let commandQueue: BackendCommandQueue
    private let transitionExecutor: TransitionExecutor
    private let capabilityNegotiator = TransitionCapabilityNegotiator()
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
        backend: any DJBackend,
        checkpointStore: LiveCheckpointStore? = LiveAutopilotCoordinator.makeDefaultCheckpointStore()
    ) {
        self.backend = backend
        let queue = BackendCommandQueue(backend: backend)
        self.commandQueue = queue
        self.transitionExecutor = TransitionExecutor(sender: queue)
        self.checkpointStore = checkpointStore
    }

    public nonisolated var backendIdentifier: DJBackendIdentifier { backend.identifier }

    public func requestPause() async -> LiveRuntimeCommandDecision {
        let decision = controlPolicy.pauseDecision(phase: phase)
        guard decision.accepted else { return decision }
        if phase == .paused { return decision }

        pausedFromPhase = phase
        phase = .paused
        lastCommand = "remote:pause"
        await saveCurrentCheckpoint(state: .paused)
        await publishMirror(message: "Autopilote en pause au point sûr courant")
        return decision
    }

    public func requestResume(
        midiReady: Bool,
        audioWatchdogReady: Bool
    ) async -> LiveRuntimeCommandDecision {
        guard phase == .paused else {
            return .reject("L’Autopilote n’est pas en pause.")
        }
        guard let project = currentProject,
              project.tracks.indices.contains(currentTrackIndex) else {
            return .reject("Le projet actif ne permet pas de vérifier la reprise.")
        }

        let expected = project.tracks[currentTrackIndex].track
        let backendMatches = await verify(track: expected, deck: activeDeck)
        let checkpoint = try? await checkpointStore?.load()
        let deckMatches = checkpoint?.activeDeck == activeDeck
        let decision = controlPolicy.resumeDecision(
            pausedFrom: pausedFromPhase,
            seratoMatchesCheckpoint: backendMatches,
            deckMatchesCheckpoint: deckMatches,
            midiReady: midiReady,
            audioWatchdogReady: audioWatchdogReady
        )
        guard decision.accepted else { return decision }

        await commandQueue.resetCircuitAfterManualValidation()
        phase = pausedFromPhase ?? .playing
        pausedFromPhase = nil
        lastCommand = "remote:resume"
        await saveCurrentCheckpoint(state: autopilotState(for: phase))
        await publishMirror(message: "Autopilote repris depuis un point sûr")
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
        await publishMirror(message: "La prochaine transition utilisera un fondu de secours")
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
            await publishMirror(message: "Contrôle manuel demandé ; la courbe en cours se termine sans nouvelle automation")
            return .accept("La transition en cours se termine pour éviter une coupure brutale, puis MixPilot rend la main.")
        }

        await commandQueue.takeManualControl()
        phase = .manualControl
        await publishMirror(message: "Contrôle manuel actif")
        return .accept("Tu as repris la main. Aucune nouvelle commande automatique ne sera envoyée.")
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
        resetRuntimeState(project: project)
        await setPhase(.preflight, message: "Vérification du système")
        await saveCurrentCheckpoint(state: .preflight)
        await onEvent(.preparing(projectName: project.name))

        let environment = await backend.detectEnvironment()
        await onEvent(.backendObserved(environment))
        guard environment.isRunning else {
            throw LiveRuntimeError.backendUnavailable(backend.displayName)
        }

        let validation = await backend.validateConfiguration()
        if validation.hasBlockingFailure {
            let failures = validation.items
                .filter { $0.status == .failed || $0.status == .blockedByPlatform }
                .map(\.detail)
                .joined(separator: " ")
            throw LiveRuntimeError.configurationBlocked(
                failures.isEmpty
                    ? "La configuration doit être terminée avant le Live."
                    : failures
            )
        }
        let capabilities = await backend.capabilities()

        guard await waitForAutomationPermission() else {
            await finishManualControl()
            return
        }

        if capabilities.supports(.visiblePlaylistReading) {
            try? await commandQueue.trigger(.browserFocus)
        }

        let first = project.tracks[0].track
        await setPhase(.loading, message: "Chargement du premier morceau")
        await onEvent(.loading(trackIndex: 0, track: first, deck: .a))
        let firstVerified = try await load(
            first,
            on: .a,
            index: 0,
            settleSeconds: configuration.loadSettleSeconds,
            speedMultiplier: configuration.speedMultiplier,
            strictValidation: configuration.strictTrackValidation,
            onEvent: onEvent
        )
        confirmedTrackID = firstVerified ? first.id : nil

        guard await waitForAutomationPermission() else {
            await finishManualControl()
            return
        }

        try await play(deck: .a, strictValidation: configuration.strictTrackValidation)
        lastCommand = DJControlAction.playA.rawValue
        await setPhase(.playing, message: "Lecture du premier morceau")
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

            await setPhase(.playing, message: "Lecture avant le préchargement")
            guard try await controlledSleep(beforePreload, multiplier: configuration.speedMultiplier) else {
                await finishManualControl()
                return
            }

            await setPhase(.preloading, message: "Préchargement du morceau suivant")
            await onEvent(.preloading(
                trackIndex: index + 1,
                track: incomingPrepared.track,
                deck: incomingDeck
            ))

            if capabilities.supports(.visiblePlaylistReading) {
                try? await commandQueue.trigger(.browserDown)
            }
            incomingTrackVerified = try await load(
                incomingPrepared.track,
                on: incomingDeck,
                index: index + 1,
                settleSeconds: configuration.loadSettleSeconds,
                speedMultiplier: configuration.speedMultiplier,
                strictValidation: configuration.strictTrackValidation,
                onEvent: onEvent
            )
            if !incomingTrackVerified {
                await onEvent(.warning(
                    "Le morceau suivant n’a pas pu être confirmé. MixPilot continue uniquement avec les protections compatibles."
                ))
            }

            await setPhase(.waitingForTransition, message: "Transition prête")
            let remainingLead = max(0, preloadLead - configuration.loadSettleSeconds)
            guard try await controlledSleep(remainingLead, multiplier: configuration.speedMultiplier) else {
                await finishManualControl()
                return
            }

            var sourcePlan = project.transitions[index]
            if skipTransitionRequested {
                sourcePlan = controlPolicy.safeReplacement(for: sourcePlan)
                skipTransitionRequested = false
                await onEvent(.warning("La transition a été remplacée par un fondu de secours, sans sauter de morceau."))
            }

            let adaptation = capabilityNegotiator.adapt(sourcePlan, to: capabilities)
            guard let plan = adaptation.selectedPlan else {
                throw LiveRuntimeError.transitionUnavailable(adaptation.explanation)
            }
            if adaptation.usedFallback {
                await onEvent(.transitionAdapted(
                    index: index,
                    original: sourcePlan.kind,
                    selected: plan.kind,
                    explanation: adaptation.explanation
                ))
            }

            guard await waitForAutomationPermission() else {
                await finishManualControl()
                return
            }
            await setPhase(.transitioning, message: "Transition en cours")
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
            lastCommand = DJControlAction.play(deck: activeDeck).rawValue

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

    private func resetRuntimeState(project: SetProject) {
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
    }

    private func load(
        _ track: Track,
        on deck: DeckID,
        index: Int,
        settleSeconds: TimeInterval,
        speedMultiplier: Double,
        strictValidation: Bool,
        onEvent: EventHandler
    ) async throws -> Bool {
        let action = DJControlAction.load(deck: deck)
        let reference = DJTrackReference(
            id: track.id.uuidString,
            title: track.title,
            artist: track.artist.isEmpty ? nil : track.artist
        )
        let command = DJBackendCommand(
            action: action,
            idempotencyKey: "load|\(backend.identifier.rawValue)|\(track.id.uuidString)|\(deck.rawValue)"
        )
        let receipt = try await commandQueue.execute(
            command,
            expectedEffect: .loadedTrack(reference, deck: deck),
            requireVerification: strictValidation
        )
        lastCommand = action.rawValue
        await saveCurrentCheckpoint(state: index == 0 ? .loadingInitialTrack : .preloadingNextTrack)

        guard try await controlledSleep(settleSeconds, multiplier: speedMultiplier) else {
            await finishManualControl()
            return false
        }

        let verified = receipt.status == .verified || receipt.status == .observed || await verify(track: track, deck: deck)
        await onEvent(.loaded(trackIndex: index, track: track, deck: deck, verified: verified))
        if strictValidation && !verified {
            throw LiveRuntimeError.trackValidationFailed(track.title)
        }
        return verified
    }

    private func play(deck: DeckID, strictValidation: Bool) async throws {
        let action = DJControlAction.play(deck: deck)
        let command = DJBackendCommand(
            action: action,
            idempotencyKey: "play|\(backend.identifier.rawValue)|\(deck.rawValue)|\(currentTrackIndex)"
        )
        _ = try await commandQueue.execute(
            command,
            expectedEffect: .playback(true, deck: deck),
            requireVerification: strictValidation
        )
    }

    private func verify(track: Track, deck: DeckID) async -> Bool {
        let reference = DJTrackReference(
            id: track.id.uuidString,
            title: track.title,
            artist: track.artist.isEmpty ? nil : track.artist
        )
        let command = DJBackendCommand(action: .load(deck: deck))
        guard let verification = try? await backend.verify(
            command: command,
            expectedEffect: .loadedTrack(reference, deck: deck)
        ) else { return false }
        return verification.status == .verified || verification.status == .observed
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
        await commandQueue.takeManualControl()
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
