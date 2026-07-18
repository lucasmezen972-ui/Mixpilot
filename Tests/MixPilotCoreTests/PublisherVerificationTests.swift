#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation
@testable import MixPilotCore
import XCTest

final class PublisherVerificationTests: XCTestCase {
    func testMappingSignatureAcceptsExactCanonicalPayload() throws {
        let fixture = try signedMappingFixture()
        try MixPilotPublisherVerification.verify(
            signatureBase64: fixture.release.publisherSignature,
            payload: MixPilotPublicationCanonicalizer.mappingRelease(fixture.release),
            publicKeyBase64: fixture.publicKey
        )
    }

    func testAlteredMappingAndWrongKeyAreRejected() throws {
        let fixture = try signedMappingFixture()
        let altered = try mappingRelease(
            id: fixture.release.id,
            mappingVersion: fixture.release.mappingVersion + 1,
            publishedAt: fixture.release.publishedAt,
            signature: fixture.release.publisherSignature
        )

        XCTAssertThrowsError(try MixPilotPublisherVerification.verify(
            signatureBase64: altered.publisherSignature,
            payload: MixPilotPublicationCanonicalizer.mappingRelease(altered),
            publicKeyBase64: fixture.publicKey
        ))

        let wrongKey = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
        XCTAssertThrowsError(try MixPilotPublisherVerification.verify(
            signatureBase64: fixture.release.publisherSignature,
            payload: MixPilotPublicationCanonicalizer.mappingRelease(fixture.release),
            publicKeyBase64: wrongKey
        ))
    }

    func testMissingTrustedKeyFailsClosed() throws {
        let fixture = try signedMappingFixture()
        XCTAssertThrowsError(try MixPilotPublisherVerification.verify(
            signatureBase64: fixture.release.publisherSignature,
            payload: MixPilotPublicationCanonicalizer.mappingRelease(fixture.release),
            publicKeyBase64: nil
        )) { error in
            XCTAssertEqual(error as? MixPilotPublisherVerificationError, .missingPublicKey)
        }
    }

    private func signedMappingFixture() throws -> (
        release: MixPilotRemoteMappingRelease,
        publicKey: String
    ) {
        let id = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let publishedAt = Date(timeIntervalSince1970: 1_800_000_100)
        let unsigned = try mappingRelease(
            id: id,
            mappingVersion: 450,
            publishedAt: publishedAt,
            signature: nil
        )
        let privateKey = Curve25519.Signing.PrivateKey()
        let signature = try privateKey.signature(
            for: MixPilotPublicationCanonicalizer.mappingRelease(unsigned)
        ).base64EncodedString()
        let signed = try mappingRelease(
            id: id,
            mappingVersion: 450,
            publishedAt: publishedAt,
            signature: signature
        )
        return (
            signed,
            privateKey.publicKey.rawRepresentation.base64EncodedString()
        )
    }

    private func mappingRelease(
        id: UUID,
        mappingVersion: Int,
        publishedAt: Date,
        signature: String?
    ) throws -> MixPilotRemoteMappingRelease {
        let profile = MIDIMappingProfile.developmentDefault
        let profileHash = try MixPilotRemoteMappingValidator.profileSHA256(profile)
        let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
            profile: profile,
            controllerName: RekordboxMIDIPresetGenerator.defaultControllerName
        )
        let presetHash = MixPilotRemoteMappingValidator.sha256(Data(preset.csv.utf8))
        return MixPilotRemoteMappingRelease(
            id: id,
            channel: "stable",
            software: "rekordbox",
            controllerName: RekordboxMIDIPresetGenerator.defaultControllerName,
            mappingVersion: mappingVersion,
            minimumAppBuild: 1,
            minimumRekordboxVersion: "5.3.0",
            maximumRekordboxVersion: nil,
            profile: profile,
            profileSHA256: profileHash,
            generatedPresetSHA256: presetHash,
            publisherSignature: signature,
            applyMode: .notify,
            mandatory: false,
            rolloutPercentage: 100,
            releaseNotes: "Signed mapping test",
            validationSummary: [
                "unit_tests": "passed",
                "release_build": "passed",
                "dmg_checksum": "passed",
                "device_validation": "passed"
            ],
            publishedAt: publishedAt
        )
    }
}
