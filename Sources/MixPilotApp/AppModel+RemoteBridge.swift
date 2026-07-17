#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotRemoteBridge
import MixPilotRuntime

@MainActor
extension AppModel: MixPilotRemoteStateProvider {
    func makeRemoteSnapshot(sequence: Int, now: Date) -> MixPilotRemoteSnapshot {
        let current = snapshot.currentTrack.map {
            MixPilotRemoteTrackSummary(title: $0.title, artist: $0.artist, bpm: $0.bpm)
        }
        let next = snapshot.nextTrack.map {
            MixPilotRemoteTrackSummary(title: $0.title, artist: $0.artist, bpm: $0.bpm)
        }
        let transitionIndex = snapshot.completedTransitions
        let transition = preparedProject?.transitions.indices.contains(transitionIndex) == true
            ? preparedProject?.transitions[transitionIndex]
            : nil
        let control = LiveRuntimeControlMirror.shared
        let unresolvedIncident = snapshot.incidents.last(where: { !$0.recovered })?.message
        let controlMessage = control.phase == .paused || control.phase == .manualControl
            ? control.message
            : nil

        return MixPilotRemoteSnapshot(
            sequence: sequence,
            updatedAt: now,
            mode: remoteMode(for: control.phase, fallback: snapshot.state),
            setName: preparedProject?.name ?? "Aucun set préparé",
            backend: remoteBackendSummary,
            currentTrack: current,
            nextTrack: next,
            activeDeck: snapshot.activeDeck.rawValue,
            elapsed: 0,
            duration: snapshot.currentTrack?.duration ?? 0,
            transitionLabel: transition.map { "\($0.kind.rawValue) • \($0.bars) mesures" },
            transitionConfidence: transition?.confidence,
            audioStatus: audioStatus,
            alert: unresolvedIncident ?? controlMessage,
            canPause: isLiveRunning && [.playing, .waitingForTransition].contains(control.phase),
            canResume: isLiveRunning && control.phase == .paused,
            canSkipTransition: isLiveRunning && control.phase == .waitingForTransition && control.incomingTrackVerified,
            canSafeFade: false,
            canTakeManualControl: isLiveRunning && control.phase != .manualControl
        )
    }

    func handleRemoteCommand(_ kind: MixPilotRemoteCommandKind) async -> MixPilotRemoteCommandDecision {
        let decision: LiveRuntimeCommandDecision
        switch kind {
        case .takeManualControl:
            decision = await LiveRuntimeCoordinatorRegistry.shared.requestManualControl()

        case .pauseAutopilot:
            decision = await LiveRuntimeCoordinatorRegistry.shared.requestPause()

        case .resumeAutopilot:
            decision = await LiveRuntimeCoordinatorRegistry.shared.requestResume(
                midiReady: mappingProfile.completionRatio >= 0.95 && !midiStatus.localizedCaseInsensitiveContains("échec"),
                audioWatchdogReady: audioStatus.localizedCaseInsensitiveContains("active")
            )

        case .skipTransition:
            decision = await LiveRuntimeCoordinatorRegistry.shared.requestSkipTransition()

        case .safeFade:
            return .init(
                accepted: false,
                message: "La transition de secours à distance n’est pas encore autorisée avec cette configuration. Reprends la main depuis le Mac si la situation l’exige."
            )
        }
        return .init(accepted: decision.accepted, message: decision.message)
    }

    private var remoteBackendSummary: MixPilotRemoteBackendSummary? {
        guard let selectedBackend,
              let descriptor = backendDescriptors.first(where: { $0.identifier == selectedBackend }) else {
            return nil
        }
        let degraded = descriptor.capabilities.degradedCapabilities
            .map(humanCapabilityName)
            .sorted()
        let modeLabel: String
        if selectedBackend == .djay,
           descriptor.capabilities[.automix].isVerifiedForLive {
            modeLabel = "Automix supervisé"
        } else {
            modeLabel = "MixPilot avancé"
        }
        return MixPilotRemoteBackendSummary(
            identifier: remoteIdentifier(selectedBackend),
            softwareVersion: descriptor.environment.softwareVersion,
            modeLabel: modeLabel,
            degradedCapabilities: degraded
        )
    }

    private func remoteIdentifier(_ identifier: DJBackendIdentifier) -> MixPilotRemoteBackendIdentifier {
        switch identifier {
        case .djay: .djay
        case .rekordbox: .rekordbox
        case .serato: .serato
        }
    }

    private func humanCapabilityName(_ capability: DJCapability) -> String {
        switch capability {
        case .trackLoading: "Chargement des morceaux"
        case .playPause: "Lecture / Pause"
        case .cue: "Points Cue"
        case .sync: "Synchronisation"
        case .tempo: "Tempo"
        case .channelVolume: "Volumes des decks"
        case .eqLow, .eqMid, .eqHigh: "Égalisation"
        case .filter: "Filtres"
        case .crossfader: "Crossfader"
        case .loop: "Boucles"
        case .effects: "Effets"
        case .automix: "Automix"
        case .deckStateReading, .trackStateReading: "Lecture de l’état des decks"
        default: capability.rawValue
        }
    }

    private func remoteMode(
        for phase: LiveRuntimePhase,
        fallback state: AutopilotState
    ) -> MixPilotRemoteMode {
        switch phase {
        case .paused: return .paused
        case .manualControl: return .manualControl
        case .preflight, .loading: return .preflight
        case .playing, .preloading, .waitingForTransition, .transitioning: return .live
        case .failed: return .recovery
        case .idle, .completed: break
        }

        switch state {
        case .idle, .completed, .failed: return .idle
        case .preflight, .loadingInitialTrack, .validatingNextTrack: return .preflight
        case .paused: return .paused
        case .manualControl: return .manualControl
        case .recovering, .emergencyPlayback: return .recovery
        case .playing, .preloadingNextTrack, .waitingForTransition, .transitioning,
             .validatingTransition, .cleaningOutgoingDeck:
            return .live
        }
    }
}
#endif
