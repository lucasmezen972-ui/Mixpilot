import Foundation
import Testing
@testable import MixPilotCore

struct RemoteMappingMultiBackendTests {
    @Test func djayProfileDoesNotInventGeneratedArtifact() throws {
        let release = try makeRelease(backend: .djay, generatedArtifactSHA256: nil)

        let validated = try MixPilotRemoteMappingValidator().validate(
            release: release,
            currentAppBuild: 10,
            backend: .djay,
            softwareVersion: "5.2.1",
            controllerName: "MixPilot Virtual Controller",
            installationID: UUID()
        )

        #expect(validated.artifactKind == .profile)
        #expect(validated.generatedArtifactSHA256 == nil)
        #expect(validated.generatedArtifactText == nil)
    }

    @Test func seratoProfileDoesNotInventGeneratedArtifact() throws {
        let release = try makeRelease(backend: .serato, generatedArtifactSHA256: nil)

        let validated = try MixPilotRemoteMappingValidator().validate(
            release: release,
            currentAppBuild: 10,
            backend: .serato,
            softwareVersion: "4.0.0",
            controllerName: "MixPilot Virtual Controller",
            installationID: UUID()
        )

        #expect(validated.artifactKind == .profile)
        #expect(validated.generatedArtifactText == nil)
    }

    @Test func rekordboxReleaseRecompilesAndVerifiesCSV() throws {
        let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
            profile: .developmentDefault,
            controllerName: RekordboxMIDIPresetGenerator.defaultControllerName
        )
        let expectedHash = MixPilotRemoteMappingValidator.sha256(Data(preset.csv.utf8))
        let release = try makeRelease(
            backend: .rekordbox,
            controllerName: RekordboxMIDIPresetGenerator.defaultControllerName,
            generatedArtifactSHA256: expectedHash
        )

        let validated = try MixPilotRemoteMappingValidator().validate(
            release: release,
            currentAppBuild: 10,
            backend: .rekordbox,
            softwareVersion: "7.1.0",
            controllerName: RekordboxMIDIPresetGenerator.defaultControllerName,
            installationID: UUID()
        )

        #expect(validated.artifactKind == .rekordboxCSV)
        #expect(validated.generatedArtifactSHA256 == expectedHash)
        #expect(validated.generatedArtifactText == preset.csv)
    }

    @Test func releaseForAnotherBackendIsRejected() throws {
        let release = try makeRelease(backend: .djay, generatedArtifactSHA256: nil)

        #expect(throws: MixPilotRemoteMappingValidationError.incompatible) {
            _ = try MixPilotRemoteMappingValidator().validate(
                release: release,
                currentAppBuild: 10,
                backend: .serato,
                softwareVersion: "4.0.0",
                controllerName: "MixPilot Virtual Controller",
                installationID: UUID()
            )
        }
    }

    @Test func profileOnlyManifestPassesImmutableProvenanceValidation() throws {
        let release = try makeRelease(backend: .djay, generatedArtifactSHA256: nil)
        let validation = completeValidation()
        let manifest = MixPilotMappingProvenanceManifest(
            applyMode: release.applyMode,
            channel: release.channel,
            ciRunNumber: 12,
            controllerName: release.controllerName,
            generatedArtifactSHA256: nil,
            mandatory: release.mandatory,
            mappingVersion: release.mappingVersion,
            maximumSoftwareVersion: release.maximumSoftwareVersion,
            minimumAppBuild: release.minimumAppBuild,
            minimumSoftwareVersion: release.minimumSoftwareVersion,
            profileSHA256: release.profileSHA256,
            releaseID: release.id,
            releaseNotes: release.releaseNotes,
            repository: MixPilotMappingProvenanceVerifier.trustedRepository,
            schemaVersion: 1,
            software: release.software,
            validation: validation
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let manifestData = try encoder.encode(manifest)
        let provenance = MixPilotMappingProvenance(
            releaseID: release.id,
            sourceRepository: MixPilotMappingProvenanceVerifier.trustedRepository,
            sourceCommitSHA: String(repeating: "a", count: 40),
            sourceManifestPath: "MappingReleases/djay/mapping-v1.json",
            sourceManifestSHA256: MixPilotRemoteMappingValidator.sha256(manifestData)
        )

        let verified = try MixPilotMappingProvenanceVerifier().validate(
            release: release,
            provenance: provenance,
            manifestData: manifestData
        )

        #expect(verified.generatedArtifactSHA256 == nil)
        #expect(verified.software == DJBackendIdentifier.djay.rawValue)
    }

    @Test func legacyRekordboxVersionKeysRemainDecodable() throws {
        let profileHash = try MixPilotRemoteMappingValidator.profileSHA256(.developmentDefault)
        let profileData = try JSONEncoder().encode(MIDIMappingProfile.developmentDefault)
        let profileObject = try #require(
            JSONSerialization.jsonObject(with: profileData) as? [String: Any]
        )
        let id = UUID()
        let json: [String: Any] = [
            "id": id.uuidString,
            "channel": "stable",
            "software": "rekordbox",
            "controller_name": RekordboxMIDIPresetGenerator.defaultControllerName,
            "mapping_version": 5,
            "minimum_app_build": 1,
            "minimum_rekordbox_version": "6.8.0",
            "profile": profileObject,
            "profile_sha256": profileHash,
            "apply_mode": "notify",
            "mandatory": false,
            "rollout_percentage": 100,
            "release_notes": "Legacy fixture",
            "validation_summary": [:],
            "published_at": "2026-07-17T12:00:00Z"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(MixPilotRemoteMappingRelease.self, from: data)

        #expect(decoded.backendIdentifier == .rekordbox)
        #expect(decoded.minimumSoftwareVersion == "6.8.0")
    }

    private func completeValidation() -> MixPilotMappingManifestValidation {
        MixPilotMappingManifestValidation(
            advancedActions: 0,
            dmgChecksum: "passed",
            releaseBuild: "passed",
            simulation250: "passed",
            simulation50: "passed",
            supportedActions: 1,
            unitTests: "passed"
        )
    }

    private func makeRelease(
        backend: DJBackendIdentifier,
        controllerName: String = "MixPilot Virtual Controller",
        generatedArtifactSHA256: String?
    ) throws -> MixPilotRemoteMappingRelease {
        MixPilotRemoteMappingRelease(
            id: UUID(),
            channel: "stable",
            backend: backend,
            controllerName: controllerName,
            mappingVersion: 1,
            minimumAppBuild: 1,
            minimumSoftwareVersion: nil,
            maximumSoftwareVersion: nil,
            profile: .developmentDefault,
            profileSHA256: try MixPilotRemoteMappingValidator.profileSHA256(.developmentDefault),
            generatedPresetSHA256: generatedArtifactSHA256,
            publisherSignature: nil,
            applyMode: .notify,
            mandatory: false,
            rolloutPercentage: 100,
            releaseNotes: "Test",
            validationSummary: [:],
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
