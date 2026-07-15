#if os(macOS)
import Foundation
@testable import MixPilotRemoteBridge
import XCTest

final class RemoteProtocolContractTests: XCTestCase {
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testClientFixturesDecodeWithExactVersionAndEnums() throws {
        let hello = try decodeClient("hello")
        XCTAssertEqual(hello.version, 1)
        XCTAssertEqual(hello.type, "hello")
        XCTAssertEqual(hello.deviceID, "11111111-1111-1111-1111-111111111111")

        let pair = try decodeClient("pair")
        XCTAssertEqual(pair.pin, "482913")

        let authenticate = try decodeClient("authenticate")
        XCTAssertEqual(authenticate.token, "fixture-token-not-a-real-secret")

        let subscribe = try decodeClient("subscribe")
        XCTAssertEqual(subscribe.lastSequence, 41)

        let command = try decodeClient("command")
        XCTAssertEqual(command.command?.kind, .takeManualControl)
        XCTAssertEqual(command.command?.id.uuidString.lowercased(), "22222222-2222-2222-2222-222222222222")
        let issuedAt = try XCTUnwrap(command.command?.issuedAt)
        XCTAssertEqual(issuedAt.timeIntervalSince1970, 1_784_154_665, accuracy: 1)
    }

    func testServerFixturesDecodeWithExactFields() throws {
        XCTAssertEqual(try decodeServer("pairing_required").type, "pairing_required")
        XCTAssertEqual(try decodeServer("paired").sessionToken, "fixture-token-not-a-real-secret")
        XCTAssertEqual(try decodeServer("authenticated").type, "authenticated")
        XCTAssertEqual(try decodeServer("error").type, "error")
        XCTAssertEqual(try decodeServer("pong").type, "pong")

        let snapshotMessage = try decodeServer("snapshot")
        XCTAssertEqual(snapshotMessage.snapshot?.sequence, 42)
        XCTAssertEqual(snapshotMessage.snapshot?.mode, .live)
        XCTAssertEqual(snapshotMessage.snapshot?.currentTrack?.title, "Water")
        XCTAssertEqual(snapshotMessage.snapshot?.nextTrack?.artist, "Naïka")
        XCTAssertEqual(snapshotMessage.snapshot?.canSafeFade, false)

        let acknowledgement = try decodeServer("ack").acknowledgement
        XCTAssertEqual(acknowledgement?.commandID.uuidString.lowercased(), "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(acknowledgement?.accepted, true)
    }

    func testFixtureManifestContainsEveryProtocolV1Message() throws {
        let fixtures = try fixtureDictionary()
        let expected: Set<String> = [
            "hello", "pairing_required", "pair", "paired", "authenticate",
            "authenticated", "subscribe", "snapshot", "command", "ack", "error", "pong",
        ]
        XCTAssertEqual(Set(fixtures.keys), expected)
    }

    private func decodeClient(_ name: String) throws -> MixPilotRemoteClientMessage {
        try decoder.decode(MixPilotRemoteClientMessage.self, from: fixtureData(name))
    }

    private func decodeServer(_ name: String) throws -> MixPilotRemoteServerMessage {
        try decoder.decode(MixPilotRemoteServerMessage.self, from: fixtureData(name))
    }

    private func fixtureData(_ name: String) throws -> Data {
        let fixtures = try fixtureDictionary()
        let value = try XCTUnwrap(fixtures[name], "Fixture absente : \(name)")
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private func fixtureDictionary() throws -> [String: Any] {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repositoryRoot
            .appendingPathComponent("Shared/RemoteProtocolV1/Fixtures/protocol-v1-fixtures.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL))
        let root = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(root["protocolVersion"] as? Int, 1)
        return try XCTUnwrap(root["fixtures"] as? [String: Any])
    }
}
#endif
