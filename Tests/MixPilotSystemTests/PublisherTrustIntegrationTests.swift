#if os(macOS)
import Foundation
import XCTest

final class PublisherTrustIntegrationTests: XCTestCase {
    func testMappingServiceVerifiesSignatureBeforeProvenanceFetch() throws {
        let source = try repositorySource(
            "Sources/MixPilotSystem/MixPilotRemoteMappingService.swift"
        )
        let signatureIndex = try XCTUnwrap(
            source.range(of: "MixPilotPublisherTrust.verify(release)")?.lowerBound
        )
        let provenanceIndex = try XCTUnwrap(
            source.range(of: "verifyImmutableProvenance(")?.lowerBound
        )
        XCTAssertLessThan(signatureIndex, provenanceIndex)
    }

    func testStableBuildCanRequireEmbeddedPublicKey() throws {
        let source = try repositorySource("Scripts/build_release.sh")
        XCTAssertTrue(source.contains("MIXPILOT_PUBLISHER_PUBLIC_KEY_BASE64"))
        XCTAssertTrue(source.contains("MIXPILOT_REQUIRE_PUBLISHER_KEY"))
        XCTAssertTrue(source.contains("MixPilotPublisherPublicKey"))
        XCTAssertTrue(source.contains("32-byte Ed25519 public key"))
    }

    func testMappingSignerReadsSecretOnlyFromEnvironment() throws {
        let source = try repositorySource(
            "Sources/MixPilotMappingPublisherCLI/main.swift"
        )
        XCTAssertTrue(source.contains("MIXPILOT_SIGNING_KEY_BASE64"))
        XCTAssertTrue(source.contains("--sign"))
        XCTAssertTrue(source.contains("MixPilotPublicationCanonicalizer.mappingRelease"))
        XCTAssertFalse(source.contains("print(encoded)"))
        XCTAssertFalse(source.contains("privateKeyBase64"))
    }

    func testDatabaseRejectsMalformedSignatureEncoding() throws {
        let source = try repositorySource(
            "supabase/migrations/20260718153000_require_ed25519_signature_shape.sql"
        )
        XCTAssertTrue(source.contains("octet_length(decoded) = 64"))
        XCTAssertTrue(source.contains("valid Ed25519 signature encoding"))
        XCTAssertTrue(source.contains("is_ed25519_signature('not-a-signature')"))
    }

    private func repositorySource(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent(path),
            encoding: .utf8
        )
    }
}
#endif
