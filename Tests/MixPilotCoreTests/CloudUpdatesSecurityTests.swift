#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation
@testable import MixPilotCore
import XCTest

final class CloudUpdatesSecurityTests: XCTestCase {
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func testValidReleaseOnOfficialGitHubURLIsAvailable() throws {
        let signed = try makeSignedRelease(
            downloadURL: URL(string: "https://github.com/lucasmezen972-ui/Mixpilot/releases/download/v1.0.0/MixPilot.dmg")!,
            releasePageURL: URL(string: "https://github.com/lucasmezen972-ui/Mixpilot/releases/tag/v1.0.0")!
        )

        XCTAssertTrue(signed.release.hasRequiredPublisherMetadata)
        XCTAssertTrue(signed.release.isAvailable(
            currentBuild: 1,
            installationID: installationID,
            trustedPublicKeyBase64: signed.publicKey
        ))
        XCTAssertEqual(signed.release.preferredOpenURL, signed.release.releasePageURL)
    }

    func testUnsignedReleaseIsNeverOffered() throws {
        let release = makeRelease(
            downloadURL: URL(string: "https://github.com/lucasmezen972-ui/Mixpilot/releases/download/v1.0.0/MixPilot.dmg")!,
            releasePageURL: nil,
            signature: nil
        )

        XCTAssertFalse(release.hasRequiredPublisherMetadata)
        XCTAssertFalse(release.isAvailable(
            currentBuild: 1,
            installationID: installationID,
            trustedPublicKeyBase64: nil
        ))
    }

    func testWrongKeyAndAlteredFieldsAreRejected() throws {
        let signed = try makeSignedRelease(
            downloadURL: URL(string: "https://github.com/lucasmezen972-ui/Mixpilot/releases/download/v1.0.0/MixPilot.dmg")!,
            releasePageURL: nil
        )
        let wrongKey = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()

        XCTAssertFalse(signed.release.isAvailable(
            currentBuild: 1,
            installationID: installationID,
            trustedPublicKeyBase64: wrongKey
        ))

        let altered = makeRelease(
            id: signed.release.id,
            publishedAt: signed.release.publishedAt,
            downloadURL: URL(string: "https://objects.githubusercontent.com/altered/MixPilot.dmg")!,
            releasePageURL: nil,
            signature: signed.release.signature
        )
        XCTAssertFalse(altered.isAvailable(
            currentBuild: 1,
            installationID: installationID,
            trustedPublicKeyBase64: signed.publicKey
        ))
    }

    func testUntrustedReleaseURLIsRejectedAndNeverOpened() throws {
        let release = makeRelease(
            downloadURL: URL(string: "https://example.invalid/MixPilot.dmg")!,
            releasePageURL: URL(string: "https://example.invalid/release")!,
            signature: Data(repeating: 0, count: 64).base64EncodedString()
        )

        XCTAssertFalse(release.isAvailable(
            currentBuild: 1,
            installationID: installationID,
            trustedPublicKeyBase64: Data(repeating: 0, count: 32).base64EncodedString()
        ))
        XCTAssertEqual(
            release.preferredOpenURL.absoluteString,
            "https://github.com/lucasmezen972-ui/Mixpilot/releases"
        )
    }

    func testURLsWithCredentialsOrHTTPAreRejected() throws {
        XCTAssertFalse(MixPilotCloudRelease.isAllowedDistributionURL(
            URL(string: "http://github.com/lucasmezen972-ui/Mixpilot/releases")!
        ))
        XCTAssertFalse(MixPilotCloudRelease.isAllowedDistributionURL(
            URL(string: "https://user:password@github.com/lucasmezen972-ui/Mixpilot/releases")!
        ))
    }

    private func makeSignedRelease(
        downloadURL: URL,
        releasePageURL: URL?
    ) throws -> (release: MixPilotCloudRelease, publicKey: String) {
        let id = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let publishedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let unsigned = makeRelease(
            id: id,
            publishedAt: publishedAt,
            downloadURL: downloadURL,
            releasePageURL: releasePageURL,
            signature: nil
        )
        let privateKey = Curve25519.Signing.PrivateKey()
        let signature = try privateKey.signature(
            for: MixPilotPublicationCanonicalizer.appRelease(unsigned)
        ).base64EncodedString()
        let signed = makeRelease(
            id: id,
            publishedAt: publishedAt,
            downloadURL: downloadURL,
            releasePageURL: releasePageURL,
            signature: signature
        )
        return (
            signed,
            privateKey.publicKey.rawRepresentation.base64EncodedString()
        )
    }

    private func makeRelease(
        id: UUID = UUID(),
        publishedAt: Date = Date(),
        downloadURL: URL,
        releasePageURL: URL?,
        signature: String?
    ) -> MixPilotCloudRelease {
        MixPilotCloudRelease(
            id: id,
            channel: "stable",
            version: "1.0.0",
            build: 2,
            minimumMacOS: "14.0",
            downloadURL: downloadURL,
            releasePageURL: releasePageURL,
            sha256: String(repeating: "0", count: 64),
            signature: signature,
            releaseNotes: "Security test",
            mandatory: false,
            rolloutPercentage: 100,
            publishedAt: publishedAt
        )
    }
}
