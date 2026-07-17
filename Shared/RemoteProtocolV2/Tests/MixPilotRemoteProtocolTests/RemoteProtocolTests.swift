import Foundation
import Testing
@testable import MixPilotRemoteProtocol

@Test("Remote v2 snapshots preserve backend context")
func snapshotCarriesBackendContext() throws {
    let snapshot = RemoteSnapshot(
        sequence: 4,
        updatedAt: Date(timeIntervalSince1970: 100),
        mode: .live,
        setName: "Set",
        backend: RemoteBackendSummary(
            identifier: .djay,
            softwareVersion: "5.2",
            modeLabel: "Automix supervisé",
            degradedCapabilities: ["Filtre du deck B"]
        ),
        currentTrack: nil,
        nextTrack: nil,
        activeDeck: "A",
        elapsed: 20,
        duration: 100,
        transitionLabel: "Fondu doux",
        transitionConfidence: 85,
        audioStatus: "Audio stable",
        alert: nil,
        canPause: true,
        canResume: false,
        canSkipTransition: true,
        canSafeFade: true,
        canTakeManualControl: true
    )

    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(RemoteSnapshot.self, from: data)

    #expect(decoded.backend?.identifier == .djay)
    #expect(decoded.backend?.degradedCapabilities == ["Filtre du deck B"])
    #expect(decoded.activeDeck == "A")
}

@Test("Remote v2 decodes legacy v1 snapshots")
func legacySnapshotStillDecodes() throws {
    let json = """
    {
      "sequence": 1,
      "updatedAt": 0,
      "mode": "live",
      "setName": "Ancien set",
      "currentTrack": null,
      "nextTrack": null,
      "elapsed": 4,
      "duration": 50,
      "transitionLabel": null,
      "transitionConfidence": null,
      "alert": null,
      "canPause": true,
      "canResume": false,
      "canSkipTransition": true,
      "canSafeFade": true,
      "canTakeManualControl": true
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let decoded = try decoder.decode(RemoteSnapshot.self, from: Data(json.utf8))

    #expect(decoded.backend == nil)
    #expect(decoded.activeDeck == nil)
    #expect(decoded.audioStatus == nil)
}

@Test("The bridge accepts the documented Remote protocol range")
func supportedProtocolVersionRangeIsExplicit() {
    #expect(MixPilotRemoteProtocolVersion.supports(1))
    #expect(MixPilotRemoteProtocolVersion.supports(2))
    #expect(!MixPilotRemoteProtocolVersion.supports(0))
    #expect(!MixPilotRemoteProtocolVersion.supports(3))
    #expect(RemoteClientMessage.hello(deviceID: "device", deviceName: "iPhone").version == 2)
    #expect(RemoteServerMessage.simple("hello").version == 2)
}

@Test("Remote commands remain high-level intentions")
func commandsAreHighLevel() {
    #expect(RemoteCommandKind.allCases.map(\.displayName) == [
        "Mettre en pause",
        "Reprendre",
        "Changer la prochaine transition",
        "Transition de secours",
        "Reprendre la main"
    ])
}
