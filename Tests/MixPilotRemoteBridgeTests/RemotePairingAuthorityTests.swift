#if os(macOS)
import Foundation
@testable import MixPilotRemoteBridge
import XCTest

private final class MemoryTokenStore: MixPilotRemoteTokenStoring, @unchecked Sendable {
    var values: [String: String] = [:]

    func read(deviceID: String) -> String? { values[deviceID] }
    func save(_ token: String, deviceID: String) throws { values[deviceID] = token }
    func remove(deviceID: String) throws { values.removeValue(forKey: deviceID) }
}

@MainActor
final class RemotePairingAuthorityTests: XCTestCase {
    private let primaryKey = "MixPilotRemotePrimaryDeviceID"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: primaryKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: primaryKey)
        super.tearDown()
    }

    func testPairAuthenticateAndPrimaryControl() throws {
        let store = MemoryTokenStore()
        let authority = MixPilotRemotePairingAuthority(tokenStore: store)
        let now = Date(timeIntervalSince1970: 100)
        let pin = authority.rotatePairingCode(now: now)

        let token = try authority.pair(deviceID: "iphone-lucas", pin: pin, now: now.addingTimeInterval(20))

        XCTAssertTrue(authority.authenticate(deviceID: "iphone-lucas", token: token))
        XCTAssertTrue(authority.isPrimary(deviceID: "iphone-lucas"))
    }

    func testExpiredPairingCodeIsRejected() {
        let authority = MixPilotRemotePairingAuthority(tokenStore: MemoryTokenStore())
        let now = Date(timeIntervalSince1970: 100)
        let pin = authority.rotatePairingCode(now: now)

        XCTAssertThrowsError(
            try authority.pair(deviceID: "iphone", pin: pin, now: now.addingTimeInterval(121))
        )
    }

    func testDuplicateAndStaleCommandsAreRejected() throws {
        let authority = MixPilotRemotePairingAuthority(tokenStore: MemoryTokenStore())
        let now = Date(timeIntervalSince1970: 100)
        let pin = authority.rotatePairingCode(now: now)
        _ = try authority.pair(deviceID: "iphone", pin: pin, now: now)

        let command = MixPilotRemoteCommand(
            id: UUID(),
            kind: .takeManualControl,
            issuedAt: now
        )
        XCTAssertTrue(authority.authorize(command: command, deviceID: "iphone", now: now).allowed)
        XCTAssertFalse(authority.authorize(command: command, deviceID: "iphone", now: now).allowed)

        let stale = MixPilotRemoteCommand(
            id: UUID(),
            kind: .takeManualControl,
            issuedAt: now.addingTimeInterval(-11)
        )
        XCTAssertFalse(authority.authorize(command: stale, deviceID: "iphone", now: now).allowed)
    }

    func testSecondaryDeviceIsReadOnly() throws {
        let store = MemoryTokenStore()
        let authority = MixPilotRemotePairingAuthority(tokenStore: store)
        let now = Date(timeIntervalSince1970: 100)

        let firstPIN = authority.rotatePairingCode(now: now)
        _ = try authority.pair(deviceID: "primary", pin: firstPIN, now: now)
        let secondPIN = authority.pairingCode
        _ = try authority.pair(deviceID: "secondary", pin: secondPIN, now: now)

        let command = MixPilotRemoteCommand(
            id: UUID(),
            kind: .takeManualControl,
            issuedAt: now
        )
        XCTAssertFalse(authority.authorize(command: command, deviceID: "secondary", now: now).allowed)
    }
}
#endif
