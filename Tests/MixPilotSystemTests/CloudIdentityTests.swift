#if os(macOS)
import Foundation
@testable import MixPilotSystem
import XCTest

final class CloudIdentityTests: XCTestCase {
    func testEmailNormalizationIsExplicitAndBounded() throws {
        XCTAssertEqual(
            try MixPilotCloudIdentityPolicy.normalizedEmail("  Lucas@Example.COM "),
            "lucas@example.com"
        )
        XCTAssertThrowsError(try MixPilotCloudIdentityPolicy.normalizedEmail("lucas"))
        XCTAssertThrowsError(try MixPilotCloudIdentityPolicy.normalizedEmail("@example.com"))
        XCTAssertThrowsError(try MixPilotCloudIdentityPolicy.normalizedEmail("lucas@localhost"))
        XCTAssertThrowsError(try MixPilotCloudIdentityPolicy.normalizedEmail("lucas @example.com"))
    }

    func testOnlyMixPilotPKCECallbackIsAccepted() throws {
        XCTAssertTrue(MixPilotCloudIdentityPolicy.acceptsCallback(
            try XCTUnwrap(URL(string: "mixpilot-autopilot://auth/callback?code=abc123"))
        ))
        XCTAssertFalse(MixPilotCloudIdentityPolicy.acceptsCallback(
            try XCTUnwrap(URL(string: "mixpilot-autopilot://auth/callback"))
        ))
        XCTAssertFalse(MixPilotCloudIdentityPolicy.acceptsCallback(
            try XCTUnwrap(URL(string: "mixpilot-autopilot://evil/callback?code=abc123"))
        ))
        XCTAssertFalse(MixPilotCloudIdentityPolicy.acceptsCallback(
            try XCTUnwrap(URL(string: "https://auth/callback?code=abc123"))
        ))
    }

    func testCloudSourcesNeverAttemptAnonymousSignup() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let paths = [
            "Sources/MixPilotSystem/MixPilotCloudService.swift",
            "Sources/MixPilotSystem/MixPilotRemoteMappingService.swift"
        ]
        for path in paths {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertFalse(source.contains("signInAnonymously"), "Anonymous auth returned in \(path)")
            XCTAssertTrue(source.contains("MixPilotCloudIdentityError.signedOut"))
        }
    }

    func testPackagedAppRegistersAuthenticationScheme() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let script = try String(
            contentsOf: root.appendingPathComponent("Scripts/build_release.sh"),
            encoding: .utf8
        )
        XCTAssertTrue(script.contains("CFBundleURLTypes"))
        XCTAssertTrue(script.contains("mixpilot-autopilot"))
    }
}
#endif
