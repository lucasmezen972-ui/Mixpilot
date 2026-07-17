#if os(macOS)
import Foundation
@testable import MixPilotRemoteBridge
import XCTest

private final class SecurityMemoryTokenStore: MixPilotRemoteTokenStoring, @unchecked Sendable {
    var values: [String: String] = [:]
    func read(deviceID: String) -> String? { values[deviceID] }
    func save(_ token: String, deviceID: String) throws { values[deviceID] = token }
    func remove(deviceID: String) throws { values.removeValue(forKey: deviceID) }
}

@MainActor
final class RemoteSecurityPolicyTests: XCTestCase {
    func testCorrectIncorrectAndExpiredCodes() throws {
        let authority = MixPilotRemotePairingAuthority(tokenStore: SecurityMemoryTokenStore())
        let now = Date(timeIntervalSince1970: 1_000)
        let pin = authority.rotatePairingCode(now: now)

        XCTAssertThrowsError(
            try authority.pair(deviceID: "wrong", pin: "000000", now: now)
        )
        XCTAssertThrowsError(
            try authority.pair(deviceID: "expired", pin: pin, now: now.addingTimeInterval(121))
        )

        let freshPIN = authority.rotatePairingCode(now: now)
        let token = try authority.pair(deviceID: "valid", pin: freshPIN, now: now.addingTimeInterval(20))
        XCTAssertTrue(authority.authenticate(deviceID: "valid", token: token))
    }

    func testValidTokenBecomesInvalidAfterRevocation() throws {
        let authority = MixPilotRemotePairingAuthority(tokenStore: SecurityMemoryTokenStore())
        let now = Date(timeIntervalSince1970: 2_000)
        let pin = authority.rotatePairingCode(now: now)
        let token = try authority.pair(deviceID: "iphone", pin: pin, now: now)
        XCTAssertTrue(authority.authenticate(deviceID: "iphone", token: token))

        try authority.revoke(deviceID: "iphone")
        XCTAssertFalse(authority.authenticate(deviceID: "iphone", token: token))
    }

    func testSecondaryDeviceStaleAndDuplicateCommandsAreRejected() throws {
        let authority = MixPilotRemotePairingAuthority(tokenStore: SecurityMemoryTokenStore())
        let now = Date(timeIntervalSince1970: 3_000)
        let primaryPIN = authority.rotatePairingCode(now: now)
        _ = try authority.pair(deviceID: "primary", pin: primaryPIN, now: now)
        let secondaryPIN = authority.pairingCode
        _ = try authority.pair(deviceID: "secondary", pin: secondaryPIN, now: now)

        let command = MixPilotRemoteCommand(
            id: UUID(),
            kind: .takeManualControl,
            issuedAt: now
        )
        XCTAssertFalse(authority.authorize(command: command, deviceID: "secondary", now: now).allowed)
        XCTAssertTrue(authority.authorize(command: command, deviceID: "primary", now: now).allowed)
        XCTAssertFalse(authority.authorize(command: command, deviceID: "primary", now: now).allowed)

        let stale = MixPilotRemoteCommand(
            id: UUID(),
            kind: .pauseAutopilot,
            issuedAt: now.addingTimeInterval(-10.1)
        )
        XCTAssertFalse(authority.authorize(command: stale, deviceID: "primary", now: now).allowed)
    }
}
#endif
