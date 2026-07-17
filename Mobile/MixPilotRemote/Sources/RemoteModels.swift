import Foundation
import MixPilotRemoteProtocol

enum RemoteConnectionStatus: Equatable {
    case idle
    case discovering
    case connecting(String)
    case pairingRequired(String)
    case authenticated(String)
    case disconnected(String)
    case failed(String)

    var title: String {
        switch self {
        case .idle: "Hors ligne"
        case .discovering: "Recherche du Mac…"
        case .connecting(let name): "Connexion à \(name)…"
        case .pairingRequired(let name): "Appairage avec \(name)"
        case .authenticated(let name): "Connecté à \(name)"
        case .disconnected(let reason): "Déconnecté • \(reason)"
        case .failed: "Connexion impossible"
        }
    }

    var detail: String? {
        switch self {
        case .failed(let reason), .disconnected(let reason): reason
        default: nil
        }
    }

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}

struct RemoteEndpoint: Identifiable, Hashable {
    let name: String
    let host: String
    let port: Int

    var id: String { "\(host):\(port)" }
}

extension RemoteSnapshot {
    static let demo = RemoteSnapshot(
        sequence: 1,
        updatedAt: Date(),
        mode: .live,
        setName: "Set principal",
        backend: RemoteBackendSummary(
            identifier: .djay,
            softwareVersion: "5.2",
            modeLabel: "Automix supervisé",
            degradedCapabilities: []
        ),
        currentTrack: RemoteTrackSummary(title: "Morceau actuel", artist: "Artiste", bpm: 117),
        nextTrack: RemoteTrackSummary(title: "Morceau suivant", artist: "Artiste", bpm: 116),
        activeDeck: "A",
        elapsed: 74,
        duration: 201,
        transitionLabel: "Fondu doux dans 1 min 12",
        transitionConfidence: 91,
        audioStatus: "Audio stable",
        alert: nil,
        canPause: true,
        canResume: false,
        canSkipTransition: true,
        canSafeFade: true,
        canTakeManualControl: true
    )
}
