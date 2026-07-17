import Foundation
@testable import MixPilotCore
import XCTest

final class CloudUpdatesSecurityTests: XCTestCase {
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func testSignedReleaseOnOfficialGitHubURLIsAvailable() throws {
        let release = makeRelease(
            downloadURL: URL(string: "https://github.com/lucasmezen972-ui/Mixpilot/releases/download/v1.0.0/MixPilot.dmg")!,
            releasePageURL: URL(string: "https://github.com/lucasmezen972-ui/Mixpilot/releases/tag/v1.0.0")!,
            signature: String(repeating: "a", count: 64)
        )

        XCTAssertTrue(release.hasRequiredPublisherMetadata)
        XCTAssertTrue(release.isAvailable(currentBuild: 1, installationID: installationID))
        XCTAssertEqual(release.preferredOpenURL, release.releasePageURL)
    }

    func testUnsignedReleaseIsNeverOffered() throws {
        let release = makeRelease(
            downloadURL: URL(string: "https://github.com/lucasmezen972-ui/Mixpilot/releases/download/v1.0.0/MixPilot.dmg")!,
            releasePageURL: nil,
            signature: nil
        )

        XCTAssertFalse(release.hasRequiredPublisherMetadata)
        XCTAssertFalse(release.isAvailable(currentBuild: 1, installationID: installationID))
    }

    func testUntrustedReleaseURLIsRejectedAndNeverOpened() throws {
        let release = makeRelease(
            downloadURL: URL(string: "https://example.invalid/MixPilot.dmg")!,
            releasePageURL: URL(string: "https://example.invalid/release")!,
            signature: String(repeating: "b", count: 64)
        )

        XCTAssertFalse(release.isAvailable(currentBuild: 1, installationID: installationID))
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

    private func makeRelease(
        downloadURL: URL,
        releasePageURL: URL?,
        signature: String?
    ) -> MixPilotCloudRelease {
        MixPilotCloudRelease(
            id: UUID(),
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
            publishedAt: Date()
        )
    }
}
