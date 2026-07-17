import Foundation
import Testing
@testable import MixPilotCore

struct RemoteMappingUpdatesTests {
    @Test func profileDigestIsStable() throws {
        let first = try MixPilotRemoteMappingValidator.profileSHA256(.developmentDefault)
        let second = try MixPilotRemoteMappingValidator.profileSHA256(.developmentDefault)
        #expect(first == second)
        #expect(first.count == 64)
    }

    @Test func rekordboxPresetCanBeRecompiled() throws {
        let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
            profile: .developmentDefault,
            controllerName: RekordboxMIDIPresetGenerator.defaultControllerName
        )
        let digest = MixPilotRemoteMappingValidator.sha256(Data(preset.csv.utf8))
        #expect(!preset.base.supportedActions.isEmpty)
        #expect(digest.count == 64)
    }

    @Test func immutableManifestMatchesRelease() throws {
        let fixture = try makeFixture()
        let verified = try MixPilotMappingProvenanceVerifier().validate(
            release: fixture.release,
            provenance: fixture.provenance,
            manifestData: fixture.manifestData
        )
        #expect(verified.mappingVersion == 450)
        #expect(verified.validation.isComplete)
    }

    @Test func forgedManifestIsRejected() throws {
        let fixture = try makeFixture()
        var forged = fixture.manifestData
        forged.append(0x20)

        do {
            _ = try MixPilotMappingProvenanceVerifier().validate(
                release: fixture.release,
                provenance: fixture.provenance,
                manifestData: forged
            )
            Issue.record("Un manifeste modifié ne doit jamais être accepté.")
        } catch let error as MixPilotMappingProvenanceError {
            #expect(error == .manifestDigestMismatch)
        }
    }

    @Test func untrustedRepositoryIsRejectedBeforeNetworkUse() throws {
        let provenance = MixPilotMappingProvenance(
            releaseID: UUID(),
            sourceRepository: "attacker/example",
            sourceCommitSHA: String(repeating: "a", count: 40),
            sourceManifestPath: "MappingReleases/rekordbox/mapping.json",
            sourceManifestSHA256: String(repeating: "b", count: 64)
        )
        do {
            _ = try MixPilotMappingProvenanceVerifier.rawManifestURL(for: provenance)
            Issue.record("Un dépôt non approuvé ne doit produire aucune URL.")
        } catch let error as MixPilotMappingProvenanceError {
            #expect(error == .untrustedRepository)
        }
    }

    private func makeFixture() throws -> (
        release: MixPilotRemoteMappingRelease,
        provenance: MixPilotMappingProvenance,
        manifestData: Data
    ) {
        let releaseID = UUID(uuidString: "036DF828-BD1D-4842-AA86-C2EF34AD30C6")!
        let profileHash = try MixPilotRemoteMappingValidator.profileSHA256(.developmentDefault)
        let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
            profile: .developmentDefault,
            controllerName: RekordboxMIDIPresetGenerator.defaultControllerName
        )
        let presetHash = MixPilotRemoteMappingValidator.sha256(Data(preset.csv.utf8))

        let release = MixPilotRemoteMappingRelease(
            id: releaseID,
            channel: "stable",
            software: "rekordbox",
            controllerName: RekordboxMIDIPresetGenerator.defaultControllerName,
            mappingVersion: 450,
            minimumAppBuild: 1,
            minimumRekordboxVersion: "5.3.0",
            maximumRekordboxVersion: nil,
            profile: .developmentDefault,
            profileSHA256: profileHash,
            generatedPresetSHA256: presetHash,
            publisherSignature: nil,
            applyMode: .notify,
            mandatory: false,
            rolloutPercentage: 100,
            releaseNotes: "Mapping MixPilot généré et validé par la CI.",
            validationSummary: [:],
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let manifest = MixPilotMappingProvenanceManifest(
            applyMode: .notify,
            channel: "stable",
            ciRunNumber: 450,
            controllerName: RekordboxMIDIPresetGenerator.defaultControllerName,
            generatedPresetSHA256: presetHash,
            mandatory: false,
            mappingVersion: 450,
            maximumRekordboxVersion: nil,
            minimumAppBuild: 1,
            minimumRekordboxVersion: "5.3.0",
            profileSHA256: profileHash,
            releaseID: releaseID,
            releaseNotes: "Mapping MixPilot généré et validé par la CI.",
            repository: MixPilotMappingProvenanceVerifier.trustedRepository,
            schemaVersion: 1,
            software: "rekordbox",
            validation: MixPilotMappingManifestValidation(
                advancedActions: 3,
                dmgChecksum: "passed",
                releaseBuild: "passed",
                simulation250: "passed",
                simulation50: "passed",
                supportedActions: 27,
                unitTests: "passed"
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        let provenance = MixPilotMappingProvenance(
            releaseID: releaseID,
            sourceRepository: MixPilotMappingProvenanceVerifier.trustedRepository,
            sourceCommitSHA: String(repeating: "a", count: 40),
            sourceManifestPath: "MappingReleases/rekordbox/mapping-v450.json",
            sourceManifestSHA256: MixPilotRemoteMappingValidator.sha256(data)
        )
        return (release, provenance, data)
    }
}
