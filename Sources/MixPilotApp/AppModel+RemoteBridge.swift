#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotRemoteBridge

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
        let alert = snapshot.incidents.last(where: { !$0.recovered })?.message

        return MixPilotRemoteSnapshot(
            sequence: sequence,
            updatedAt: now,
            mode: remoteMode(for: snapshot.state),
            setName: preparedProject?.name ?? "Aucun set préparé",
            currentTrack: current,
            nextTrack: next,
            elapsed: 0,
            duration: snapshot.currentTrack?.duration ?? 0,
            transitionLabel: transition.map { "\($0.kind.rawValue) • \($0.bars) mesures" },
            transitionConfidence: transition?.confidence,
            alert: alert,
            canPause: false,
            canResume: false,
            canSkipTransition: false,
            canSafeFade: false,
            canTakeManualControl: isLiveRunning && snapshot.state != .manualControl
        )
    }

    func handleRemoteCommand(_ kind: MixPilotRemoteCommandKind) async -> MixPilotRemoteCommandDecision {
        switch kind {
        case .takeManualControl:
            guard isLiveRunning else {
                return .init(accepted: false, message: "Aucun Live actif à reprendre.")
            }
            takeManualControl()
            return .init(accepted: true, message: "Contrôle manuel repris sur le Mac.")

        case .pauseAutopilot:
            return .init(
                accepted: false,
                message: "Pause distante verrouillée tant que la reprise exacte n’est pas validée."
            )

        case .resumeAutopilot:
            return .init(
                accepted: false,
                message: "Reprise distante verrouillée tant que la restauration du checkpoint n’est pas validée."
            )

        case .skipTransition:
            return .init(
                accepted: false,
                message: "Passage de transition verrouillé pour éviter une commande de deck incohérente."
            )

        case .safeFade:
            return .init(
                accepted: false,
                message: "Safe Fade distant verrouillé jusqu’à validation du routage audio réel."
            )
        }
    }

    private func remoteMode(for state: AutopilotState) -> MixPilotRemoteMode {
        switch state {
        case .idle, .completed, .failed:
            .idle
        case .preflight, .loadingInitialTrack, .validatingNextTrack:
            .preflight
        case .paused:
            .paused
        case .manualControl:
            .manualControl
        case .recovering, .emergencyPlayback:
            .recovery
        case .playing, .preloadingNextTrack, .waitingForTransition, .transitioning,
             .validatingTransition, .cleaningOutgoingDeck:
            .live
        }
    }
}
#endif
