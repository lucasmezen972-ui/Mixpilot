import Foundation
import MixPilotHelp
import MixPilotRemoteProtocol

@MainActor
enum RemotePresentationCopy {
    static func statusTitle(_ status: RemoteConnectionStatus) -> String {
        switch status {
        case .idle:
            return RemoteLocalizedCopy.text("remote.status.offline")
        case .discovering:
            return RemoteLocalizedCopy.text("remote.status.searching")
        case .connecting(let name):
            return RemoteLocalizedCopy.format("remote.status.connecting", name)
        case .pairingRequired(let name):
            return RemoteLocalizedCopy.format("remote.status.pairing", name)
        case .authenticated(let name):
            return RemoteLocalizedCopy.format("remote.status.connected", name)
        case .disconnected(let reason):
            return RemoteLocalizedCopy.format("remote.status.disconnected", reason)
        case .failed:
            return RemoteLocalizedCopy.text("remote.status.failed")
        }
    }

    static var demoSnapshot: RemoteSnapshot {
        RemoteSnapshot(
            sequence: 1,
            updatedAt: Date(),
            mode: .live,
            setName: RemoteLocalizedCopy.text("remote.demo.set_name"),
            backend: RemoteBackendSummary(
                identifier: .djay,
                softwareVersion: "5.2",
                modeLabel: RemoteLocalizedCopy.text("remote.demo.mode_label"),
                degradedCapabilities: [RemoteLocalizedCopy.text("remote.demo.degraded")]
            ),
            currentTrack: RemoteTrackSummary(
                title: RemoteLocalizedCopy.text("remote.demo.current_track"),
                artist: RemoteLocalizedCopy.text("remote.demo.artist"),
                bpm: 117
            ),
            nextTrack: RemoteTrackSummary(
                title: RemoteLocalizedCopy.text("remote.demo.next_track"),
                artist: RemoteLocalizedCopy.text("remote.demo.artist"),
                bpm: 116
            ),
            activeDeck: "A",
            elapsed: 74,
            duration: 201,
            transitionLabel: RemoteLocalizedCopy.text("remote.demo.transition"),
            transitionConfidence: 91,
            audioStatus: RemoteLocalizedCopy.text("remote.demo.audio"),
            alert: RemoteLocalizedCopy.text("remote.demo.alert"),
            canPause: true,
            canResume: false,
            canSkipTransition: true,
            canSafeFade: false,
            canTakeManualControl: true
        )
    }
}
