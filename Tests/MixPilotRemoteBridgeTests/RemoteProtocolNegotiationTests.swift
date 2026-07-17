#if os(macOS)
import Testing
@testable import MixPilotRemoteBridge
import MixPilotRemoteProtocol

@Test("The Mac bridge accepts every supported Remote protocol version")
func bridgeAcceptsSupportedProtocolVersions() {
    #expect(MixPilotRemoteProtocolVersion.supports(1))
    #expect(MixPilotRemoteProtocolVersion.supports(2))
    #expect(!MixPilotRemoteProtocolVersion.supports(0))
    #expect(!MixPilotRemoteProtocolVersion.supports(3))
}

@Test("New Remote messages default to the current protocol version")
func newMessagesUseCurrentProtocolVersion() {
    let client = RemoteClientMessage.ping()
    let server = RemoteServerMessage.simple("hello")

    #expect(client.version == MixPilotRemoteProtocolVersion.current)
    #expect(server.version == MixPilotRemoteProtocolVersion.current)
}
#endif
