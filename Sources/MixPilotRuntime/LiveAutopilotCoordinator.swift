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
        strictTrackValidation: Bool = true
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
        case .configurationBlocked(let detail), .transitionUnavailable(let detail):
            detail
        case .trackValidationFailed(let title):
            "Le morceau chargé n’a pas pu être confirmé : \(title). Reprends la main et vérifie le deck avant de continuer."
        }
    }
}

public actor LiveAutopilotCoordinator {
    public typealias EventHandler = @Sendable (LiveRuntimeEvent) async -> Void

    public nonisolated let backendIdentifier: DJBackendIdentifier
    public nonisolated let backendDisplayName: String

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
        self.backendIdentifier = backend.identifier
        self.backendDisplayName = backend.displayName
        let queue = BackendCommandQueue(backend: backend)
        self.commandQueue = queue
        self.transitionExecutor = TransitionExecutor(sender: queue)
        self.checkpointStore = checkpointStore
    }

    public func requestPause() async -> LiveRuntimeCommandDecision {
        let decision = controlPolicy.pauseDecision(phase: phase)
        guard decision.accepted, phase != .paused else { return decision }
        pausedFromPhase = phase
        phase = .paused
        lastCommand = "remote:pause"
        await saveCheckpoint(state: .paused)
        await publishMirror("Autopilote en pause au point sûr courant")
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

        let backendMatches = await verify(
            track: project.tracks[currentTrackIndex].track,
            deck: activeDeck
        )
        let checkpoint = try? await checkpointStore?.load()
        let decision = controlPolicy.resumeDecision(
            pausedFrom: pausedFromPhase,
            backendMatchesCheckpoint: backendMatches && checkpoint?.backend == backendIdentifier,
            deckMatchesCheckpoint: checkpoint?.activeDeck == activeDeck,
            midiReady: midiReady,
            audioWatchdogReady: audioWatchdogReady
        )
        guard decision.accepted else { return decision }

        await commandQueue.resetCircuitAfterManualValidation()
        phase = pausedFromPhase ?? .playing
        pausedFromPhase = nil
        lastCommand = "remote:resume"
        await saveCheckpoint(state: autopilotState(for: phase))
        await publishMirror("Autopilote repris depuis un point sûr")
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
        await saveCheckpoint(state: .waitingForTransition)
        await publishMirror("La prochaine transition utilisera un fondu de secours")
        return decision
    }

    public func requestManualControl() async -> LiveRuntimeCommandDecision {
        if manualControlRequested || phase == .manualControl {
            return .accept("Le contrôle manuel est déjà actif.")
        }

        manualControlRequested = true
        pausedFromPhase = nil
        lastCommand = "remote:manual-control"
        await saveCheckpoint(state: .manualControl)

        if phase == .transitioning {
            await publishMirror("Contrôle manuel demandé ; la transition en cours se termine sans nouvelle automation")
            return .accept("La transition en cours se termine sans nouvelle automation, puis MixPilot rend la main.")
        }

        await finishManualControl()
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
        guard let projectBackend = project.backend else {
            throw LiveRuntimeError.configurationBlocked(
                "Ce projet ne précise pas le logiciel DJ à utiliser. Choisis le backend, relance la vérification et verrouille de nouveau le plan."
            )
        }
        guard projectBackend == backendIdentifier else {
            throw LiveRuntimeError.configurationBlocked(
                "Ce projet est verrouillé pour \(projectBackend.displayName), mais le Live utilise \(backendDisplayName). Sélectionne le bon logiciel DJ et relance la vérification."
            )
        }

        await LiveRuntimeCoordinatorRegistry.shared.attach(self)
        do {
            try await runPreparedProject(project, configuration: configuration, onEvent: onEvent)
            await LiveRuntimeCoordinatorRegistry.shared.detach(self)
        } catch {
            phase = .failed
            await publishMirror("Le Live a été arrêté en sécurité")
            await LiveRuntimeCoordinatorRegistry.shared.detach(self)
            throw error
        }
    }

    private func runPreparedProject(
        _ project: SetProject,
        configuration: LiveRuntimeConfiguration,
        onEvent: @escaping EventHandler
    ) async throws {
        currentProject = project
        eventHandler = onEvent
        reset(project: project)
        await setPhase(.preflight, message: "Vérification du système")
        await saveCheckpoint(state: .preflight)
        await onEvent(.preparing(projectName: project.name))

        let environment = await backend.detectEnvironment()
        await onEvent(.backendObserved(environment))
        guard environment.isRunning else {
            throw LiveRuntimeError.backendUnavailable(backendDisplayName)
        }

        let validation = await backend.validateConfiguration()
        if validation.hasBlockingFailure {
            let details = validation.items
                .filter { $0.status == .failed || $0.status == .blockedByPlatform }
                .map(\.detail)
                .joined(separator: " ")
            throw LiveRuntimeError.configurationBlocked(
                details.isEmpty ? "La configuration doit être terminée avant le Live." : details
            )
        }

        let reportedCapabilities = await backend.capabilities()
        let liveCapabilities = confirmedCapabilities(from: reportedCapabilities)
        guard liveCapabilities.confirmsAllForLive([.trackLoading, .playPause, .channelVolume]) else {
            throw LiveRuntimeError.configurationBlocked(
                "Les commandes de chargement, lecture et volume ne sont pas toutes confirmées. Termine le test de connexion avant de lancer l’Autopilote."
            )
        }
        if configuration.strictTrackValidation && !hasReliableStateReading(liveCapabilities) {
            throw LiveRuntimeError.configurationBlocked(
                "MixPilot ne peut pas encore confirmer l’état réel des decks avec cette configuration. La préparation et le contrôle manuel restent disponibles, mais l’Autopilote complet est bloqué pour éviter des commandes aveugles."
            )
        }

        if liveCapabilities.confirmsForLive(.visiblePlaylistReading) {
            try? await commandQueue.trigger(.browserFocus)
        }

        let first = project.tracks[0].track
        await setPhase(.loading, message: "Chargement du premier morceau")
        await onEvent(.loading(trackIndex: 0, track: first, deck: .a))
        confirmedTrackID = try await load(
            first,
            on: .a,
            index: 0,
            configuration: configuration,
            onEvent: onEvent
        ) ? first.id : nil

        try await play(deck: .a, requireVerification: configuration.strictTrackValidation)
        lastCommand = DJControlAction.playA.rawValue
        await setPhase(.playing, message: "Lecture du premier morceau")
        await saveCheckpoint(state: .playing)
        await onEvent(.playing(trackIndex: 0, track: first, deck: .a))

        for index in project.transitions.indices {
            guard await automationAllowed() else {
                await finishManualControl()
                return
            }

            currentTrackIndex = index
            completedTransitions = index
            nextTransitionIndex = index
            incomingTrackVerified = false

            let outgoing = project.tracks[index]
            let incoming = project.tracks[index + 1]
            let incomingDeck = activeDeck.opposite
            let playDuration = max(5, outgoing.analysis.suggestedPlayDuration)
            let preloadLead = min(configuration.preloadLeadSeconds, max(5, playDuration * 0.45))

            await setPhase(.playing, message: "Lecture avant le préchargement")
            guard try await controlledSleep(
                max(0, playDuration - preloadLead),
                multiplier: configuration.speedMultiplier
            ) else {
                await finishManualControl()
                return
            }

            await setPhase(.preloading, message: "Préchargement du morceau suivant")
            await onEvent(.preloading(trackIndex: index + 1, track: incoming.track, deck: incomingDeck))
            if liveCapabilities.confirmsForLive(.visiblePlaylistReading) {
                try? await commandQueue.trigger(.browserDown)
            }
            incomingTrackVerified = try await load(
                incoming.track,
                on: incomingDeck,
                index: index + 1,
                configuration: configuration,
                onEvent: onEvent
            )

            await setPhase(.waitingForTransition, message: "Transition prête")
            guard try await controlledSleep(
                max(0, preloadLead - configuration.loadSettleSeconds),
                multiplier: configuration.speedMultiplier
            ) else {
                await finishManualControl()
                return
            }

            var requestedPlan = project.transitions[index]
            if skipTransitionRequested {
                requestedPlan = controlPolicy.safeReplacement(for: requestedPlan)
                skipTransitionRequested = false
                await onEvent(.warning("La prochaine transition utilisera une variante de secours sans changer l’ordre du set."))
            }

            let adaptation = capabilityNegotiator.adapt(requestedPlan, to: liveCapabilities)
            guard let plan = adaptation.selectedPlan else {
                throw LiveRuntimeError.transitionUnavailable(adaptation.explanation)
            }
            if adaptation.usedFallback {
                await onEvent(.transitionAdapted(
                    index: index,
                    original: requestedPlan.kind,
                    selected: plan.kind,
                    explanation: adaptation.explanation
                ))
            }

            await setPhase(.transitioning, message: "Transition en cours")
            lastCommand = "transition:\(plan.id.uuidString)"
            await saveCheckpoint(state: .transitioning)
            await onEvent(.transitionStarted(index: index, plan: plan, outgoingDeck: activeDeck))

            let summary = try await transitionExecutor.execute(
                plan: plan,
                outgoingDeck: activeDeck,
                framesPerSecond: configuration.framesPerSecond,
                speedMultiplier: configuration.speedMultiplier
            )

            activeDeck = incomingDeck
            currentTrackIndex = index + 1
            completedTransitions = index + 1
            nextTransitionIndex = project.transitions.indices.contains(index + 1) ? index + 1 : nil
            confirmedTrackID = incoming.id
            incomingTrackVerified = false

            if manualControlRequested {
                await finishManualControl()
                return
            }

            await setPhase(.playing, message: "Transition terminée")
            await saveCheckpoint(state: .playing)
            await onEvent(.transitionCompleted(index: index, summary: summary))
            await onEvent(.playing(trackIndex: index + 1, track: incoming.track, deck: activeDeck))
        }

        phase = .completed
        currentTrackIndex = max(0, project.tracks.count - 1)
        completedTransitions = project.transitions.count
        nextTransitionIndex = nil
        lastCommand = nil
        await saveCheckpoint(state: .completed)
        await publishMirror("Set terminé")
        await onEvent(.completed)
    }

    private func confirmedCapabilities(from reported: DJBackendCapabilities) -> DJBackendCapabilities {
        var result = DJBackendCapabilities()
        for capability in DJCapability.allCases {
            let status = reported[capability]
            result[capability] = status.isConfirmedForLive
                ? status
                : DJCapabilityStatus(
                    availability: .unavailable,
                    confidence: status.confidence,
                    validation: status.validation,
                    method: status.method,
                    reason: status.reason ?? "Cette fonction doit encore être testée sur ce Mac."
                )
        }
        return result
    }

    private func hasReliableStateReading(_ capabilities: DJBackendCapabilities) -> Bool {
        capabilities.confirmsForLive(.deckStateReading) ||
            capabilities.confirmsForLive(.trackStateReading) ||
            (capabilities.confirmsForLive(.automix) && capabilities.confirmsForLive(.transitionTrigger))
    }

    private func load(
        _ track: Track,
        on deck: DeckID,
        index: Int,
        configuration: LiveRuntimeConfiguration,
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
            idempotencyKey: "load|\(backendIdentifier.rawValue)|\(track.id.uuidString)|\(deck.rawValue)"
        )
        let receipt = try await commandQueue.execute(
            command,
            expectedEffect: .loadedTrack(reference, deck: deck),
            requireVerification: configuration.strictTrackValidation
        )
        lastCommand = action.rawValue
        await saveCheckpoint(state: index == 0 ? .loadingInitialTrack : .preloadingNextTrack)

        guard try await controlledSleep(
            configuration.loadSettleSeconds,
            multiplier: configuration.speedMultiplier
        ) else { return false }

        var verified = receipt.status == .verified || receipt.status == .observed
        if !verified {
            verified = await verify(track: track, deck: deck)
        }
        await onEvent(.loaded(trackIndex: index, track: track, deck: deck, verified: verified))
        if configuration.strictTrackValidation && !verified {
            throw LiveRuntimeError.trackValidationFailed(track.title)
        }
        return verified
    }

    private func play(deck: DeckID, requireVerification: Bool) async throws {
        let action = DJControlAction.play(deck: deck)
        let command = DJBackendCommand(
            action: action,
            idempotencyKey: "play|\(backendIdentifier.rawValue)|\(deck.rawValue)|\(currentTrackIndex)"
        )
        _ = try await commandQueue.execute(
            command,
            expectedEffect: .playback(true, deck: deck),
            requireVerification: requireVerification
        )
    }

    private func verify(track: Track, deck: DeckID) async -> Bool {
        let reference = DJTrackReference(
            id: track.id.uuidString,
            title: track.title,
            artist: track.artist.isEmpty ? nil : track.artist
        )
        guard let result = try? await backend.verify(
            command: DJBackendCommand(action: .load(deck: deck)),
            expectedEffect: .loadedTrack(reference, deck: deck)
        ) else { return false }
        return result.status == .verified || result.status == .observed
    }

    private func reset(project: SetProject) {
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

    private func setPhase(_ newPhase: LiveRuntimePhase, message: String) async {
        phase = newPhase
        await publishMirror(message)
    }

    private func publishMirror(_ message: String) async {
        let currentPhase = phase
        let pausedFrom = pausedFromPhase
        let verified = incomingTrackVerified
        await MainActor.run {
            LiveRuntimeControlMirror.shared.update(
                phase: currentPhase,
                pausedFromPhase: pausedFrom,
                incomingTrackVerified: verified,
                message: message
            )
        }
    }

    private func automationAllowed() async -> Bool {
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
            guard await automationAllowed() else { return false }
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
        await saveCheckpoint(state: .manualControl)
        await publishMirror("Contrôle manuel actif")
        await eventHandler?(.manualControl)
    }

    private func saveCheckpoint(state: AutopilotState) async {
        guard let project = currentProject, let checkpointStore else { return }
        try? await checkpointStore.save(LiveCheckpoint(
            projectID: project.id,
            projectName: project.name,
            backend: backendIdentifier,
            currentTrackIndex: currentTrackIndex,
            activeDeck: activeDeck,
            completedTransitionCount: completedTransitions,
            nextTransitionIndex: nextTransitionIndex,
            state: state,
            lastConfirmedTrackID: confirmedTrackID,
            lastCommand: lastCommand,
            emergencyPlaybackActive: false
        ))
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
}
#endif
