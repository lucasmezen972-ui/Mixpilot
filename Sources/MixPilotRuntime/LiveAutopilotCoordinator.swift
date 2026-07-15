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
    private var activeDeck: DeckID = .a
    private var manualControlRequested = false

    public init(
        controller: MappedSeratoController,
        accessibilityBridge: SeratoAccessibilityBridge
    ) {
        self.controller = controller
        self.transitionExecutor = TransitionExecutor(sender: controller)
        self.accessibilityBridge = accessibilityBridge
    }

    public func requestManualControl() {
        manualControlRequested = true
    }

    public func run(
        project: SetProject,
        configuration: LiveRuntimeConfiguration = LiveRuntimeConfiguration(),
        onEvent: @escaping EventHandler
    ) async throws {
        guard !project.tracks.isEmpty else { throw LiveRuntimeError.emptyProject }
        guard project.locked else { throw LiveRuntimeError.projectNotLocked }
        manualControlRequested = false
        activeDeck = .a

        await onEvent(.preparing(projectName: project.name))
        let initialObservation = await MainActor.run { accessibilityBridge.observe() }
        await onEvent(.seratoObserved(initialObservation))
        guard initialObservation.isRunning else { throw LiveRuntimeError.seratoUnavailable }
        guard initialObservation.accessibilityGranted else { throw LiveRuntimeError.accessibilityUnavailable }

        try await controller.trigger(.browserFocus)
        let first = project.tracks[0].track
        await onEvent(.loading(trackIndex: 0, track: first, deck: .a))
        try await controller.trigger(.load(deck: .a))
        try await scaledSleep(configuration.loadSettleSeconds, multiplier: configuration.speedMultiplier)
        let firstVerified = await verify(track: first)
        await onEvent(.loaded(trackIndex: 0, track: first, deck: .a, verified: firstVerified))
        if configuration.strictTrackValidation && !firstVerified {
            throw LiveRuntimeError.trackValidationFailed(first.title)
        }
        try await controller.trigger(.play(deck: .a))
        await onEvent(.playing(trackIndex: 0, track: first, deck: .a))

        for index in project.transitions.indices {
            try Task.checkCancellation()
            if manualControlRequested {
                await onEvent(.manualControl)
                return
            }

            let currentPrepared = project.tracks[index]
            let incomingPrepared = project.tracks[index + 1]
            let incomingDeck = activeDeck.opposite
            let playDuration = max(5, currentPrepared.analysis.suggestedPlayDuration)
            let preloadLead = min(configuration.preloadLeadSeconds, max(5, playDuration * 0.45))
            let beforePreload = max(0, playDuration - preloadLead)

            try await scaledSleep(beforePreload, multiplier: configuration.speedMultiplier)
            try Task.checkCancellation()
            if manualControlRequested {
                await onEvent(.manualControl)
                return
            }

            await onEvent(.preloading(
                trackIndex: index + 1,
                track: incomingPrepared.track,
                deck: incomingDeck
            ))
            try await controller.trigger(.browserDown)
            try await controller.trigger(.load(deck: incomingDeck))
            try await scaledSleep(configuration.loadSettleSeconds, multiplier: configuration.speedMultiplier)

            let verified = await verify(track: incomingPrepared.track)
            await onEvent(.loaded(
                trackIndex: index + 1,
                track: incomingPrepared.track,
                deck: incomingDeck,
                verified: verified
            ))
            if !verified {
                await onEvent(.warning("Titre non confirmé par l'interface Serato : \(incomingPrepared.track.title)"))
                if configuration.strictTrackValidation {
                    throw LiveRuntimeError.trackValidationFailed(incomingPrepared.track.title)
                }
            }

            let remainingLead = max(0, preloadLead - configuration.loadSettleSeconds)
            try await scaledSleep(remainingLead, multiplier: configuration.speedMultiplier)
            let plan = project.transitions[index]
            await onEvent(.transitionStarted(index: index, plan: plan, outgoingDeck: activeDeck))

            let summary = try await transitionExecutor.execute(
                plan: plan,
                outgoingDeck: activeDeck,
                framesPerSecond: configuration.framesPerSecond,
                speedMultiplier: configuration.speedMultiplier
            )
            activeDeck = activeDeck.opposite
            await onEvent(.transitionCompleted(index: index, summary: summary))
            await onEvent(.playing(
                trackIndex: index + 1,
                track: incomingPrepared.track,
                deck: activeDeck
            ))
        }

        await onEvent(.completed)
    }

    private func verify(track: Track) async -> Bool {
        let observation = await MainActor.run { accessibilityBridge.observe(maxDepth: 6, maximumStrings: 400) }
        let titleFound = observation.contains(text: track.title)
        let artistFound = track.artist.isEmpty || observation.contains(text: track.artist)
        return observation.isRunning && observation.accessibilityGranted && titleFound && artistFound
    }

    private func scaledSleep(_ seconds: TimeInterval, multiplier: Double) async throws {
        let scaled = max(0, seconds / max(0.01, multiplier))
        if scaled > 0 {
            try await Task.sleep(for: .seconds(scaled))
        }
    }
}
#endif
