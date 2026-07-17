#if os(macOS)
import Foundation
import MixPilotRemoteProtocol

public typealias MixPilotRemoteMode = RemoteMode
public typealias MixPilotRemoteTrackSummary = RemoteTrackSummary
public typealias MixPilotRemoteBackendSummary = RemoteBackendSummary
public typealias MixPilotRemoteSnapshot = RemoteSnapshot
public typealias MixPilotRemoteCommandKind = RemoteCommandKind
public typealias MixPilotRemoteCommand = RemoteCommand
public typealias MixPilotRemoteClientMessage = RemoteClientMessage
public typealias MixPilotRemoteCommandAcknowledgement = RemoteCommandAcknowledgement
public typealias MixPilotRemoteServerMessage = RemoteServerMessage

public struct MixPilotRemoteCommandDecision: Sendable {
    public let accepted: Bool
    public let message: String

    public init(accepted: Bool, message: String) {
        self.accepted = accepted
        self.message = message
    }
}

@MainActor
public protocol MixPilotRemoteStateProvider: AnyObject {
    func makeRemoteSnapshot(sequence: Int, now: Date) -> MixPilotRemoteSnapshot
    func handleRemoteCommand(_ kind: MixPilotRemoteCommandKind) async -> MixPilotRemoteCommandDecision
}
#endif
