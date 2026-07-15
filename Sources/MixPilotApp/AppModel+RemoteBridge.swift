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
            currentTrack: current,
            nextTrack: next,
            elapsed: 0,
            duration: snapshot.currentTrack?.duration ?? 0,
            transitionLabel: transition.map { "\($0.kind.rawValue) • \($0.bars) mesures" },
            transitionConfidence: transition?.confidence,
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
                message: "Safe Fade distant verrouillé : REQUIRES_DEVICE_VALIDATION pour le routage audio réel."
            )
        }
        return .init(accepted: decision.accepted, message: decision.message)
    }

    private func remoteMode(
        for phase: LiveRuntimePhase,
        fallback state: AutopilotState
    ) -> MixPilotRemoteMode {
        switch phase {
        case .paused:
            return .paused
        case .manualControl:
            return .manualControl
        case .preflight, .loading:
            return .preflight
        case .playing, .preloading, .waitingForTransition, .transitioning:
            return .live
        case .failed:
            return .recovery
        case .idle, .completed:
            break
        }

        switch state {
        case .idle, .completed, .failed:
            return .idle
        case .preflight, .loadingInitialTrack, .validatingNextTrack:
            return .preflight
        case .paused:
            return .paused
        case .manualControl:
            return .manualControl
        case .recovering, .emergencyPlayback:
            return .recovery
        case .playing, .preloadingNextTrack, .waitingForTransition, .transitioning,
             .validatingTransition, .cleaningOutgoingDeck:
            return .live
        }
    }
}
#endif
