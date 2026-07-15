import Foundation
import XCTest

final class RemoteProtocolContractTests: XCTestCase {
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testClientFixturesDecodeWithExactFields() throws {
        let hello = try decodeClient("hello")
        XCTAssertEqual(hello.version, 1)
        XCTAssertEqual(hello.type, "hello")
        XCTAssertEqual(hello.deviceName, "iPhone de Test")

        XCTAssertEqual(try decodeClient("pair").pin, "482913")
        XCTAssertEqual(try decodeClient("authenticate").token, "fixture-token-not-a-real-secret")
        XCTAssertEqual(try decodeClient("subscribe").lastSequence, 41)

        let command = try decodeClient("command")
        XCTAssertEqual(command.command?.kind, .takeManualControl)
        XCTAssertEqual(command.command?.id.uuidString.lowercased(), "22222222-2222-2222-2222-222222222222")
    }

    func testServerFixturesDecodeWithExactFieldsAndEnums() throws {
        XCTAssertEqual(try decodeServer("pairing_required").type, "pairing_required")
        XCTAssertEqual(try decodeServer("paired").sessionToken, "fixture-token-not-a-real-secret")
        XCTAssertEqual(try decodeServer("authenticated").type, "authenticated")
        XCTAssertEqual(try decodeServer("pong").type, "pong")

        let snapshot = try decodeServer("snapshot").snapshot
        XCTAssertEqual(snapshot?.sequence, 42)
        XCTAssertEqual(snapshot?.mode, .live)
        XCTAssertEqual(snapshot?.updatedAt, ISO8601DateFormatter().date(from: "2026-07-15T22:31:03Z"))
        XCTAssertEqual(snapshot?.currentTrack?.title, "Water")
        XCTAssertEqual(snapshot?.canSafeFade, false)

        let acknowledgement = try decodeServer("ack").acknowledgement
        XCTAssertEqual(acknowledgement?.accepted, true)
        XCTAssertEqual(acknowledgement?.commandID.uuidString.lowercased(), "22222222-2222-2222-2222-222222222222")
    }

    func testFixtureManifestContainsAllVersionOneMessages() throws {
        let fixtures = try fixtureDictionary()
        let expected: Set<String> = [
            "hello", "pairing_required", "pair", "paired", "authenticate",
            "authenticated", "subscribe", "snapshot", "command", "ack", "error", "pong",
        ]
        XCTAssertEqual(Set(fixtures.keys), expected)
    }

    private func decodeClient(_ name: String) throws -> RemoteClientMessage {
        try decoder.decode(RemoteClientMessage.self, from: fixtureData(name))
    }

    private func decodeServer(_ name: String) throws -> RemoteServerMessage {
        try decoder.decode(RemoteServerMessage.self, from: fixtureData(name))
    }

    private func fixtureData(_ name: String) throws -> Data {
        let value = try XCTUnwrap(try fixtureDictionary()[name])
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private func fixtureDictionary() throws -> [String: Any] {
        let fixtureURL = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "protocol-v1-fixtures",
                withExtension: "json"
            )
        )
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL))
        let root = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(root["protocolVersion"] as? Int, 1)
        return try XCTUnwrap(root["fixtures"] as? [String: Any])
    }
}
