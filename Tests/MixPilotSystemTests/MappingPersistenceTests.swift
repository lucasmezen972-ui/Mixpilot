import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotSystem

#if os(macOS)
struct MappingPersistenceTests {
    @Test func rekordboxProfileCanBeStagedAndRestoredWithCSV() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MixPilotMappingPersistence-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = RekordboxMIDIPresetGenerator.defaultControllerName
        let profile = MIDIMappingProfile.developmentDefault
        let profileHash = try MixPilotRemoteMappingValidator.profileSHA256(profile)
        let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
            profile: profile,
            controllerName: controller
        )
        let presetHash = MixPilotRemoteMappingValidator.sha256(Data(preset.csv.utf8))
        let releaseID = UUID()
        let release = MixPilotRemoteMappingRelease(
            id: releaseID,
            channel: "stable",
            backend: .rekordbox,
            controllerName: controller,
            mappingVersion: 999,
            minimumAppBuild: 1,
            minimumSoftwareVersion: "5.3.0",
            maximumSoftwareVersion: nil,
            profile: profile,
            profileSHA256: profileHash,
            generatedPresetSHA256: presetHash,
            publisherSignature: nil,
            applyMode: .nextLaunch,
            mandatory: false,
            rolloutPercentage: 100,
            releaseNotes: "Persistence test",
            validationSummary: [:],
            publishedAt: Date()
        )
        let installer = MixPilotRemoteMappingInstaller(
            rootDirectory: root,
            installationID: UUID()
        )

        let staged = try await installer.stage(
            release: release,
            currentAppBuild: 1,
            backend: .rekordbox,
            softwareVersion: "7.0.0",
            controllerName: controller
        )
        let stagedURL = try #require(staged.generatedArtifactURL)
        #expect(staged.releaseID == releaseID)
        #expect(staged.backend == .rekordbox)
        #expect(staged.appliedProfileSHA256 == profileHash)
        #expect(staged.generatedArtifactSHA256 == presetHash)
        #expect(FileManager.default.fileExists(atPath: stagedURL.path))
        #expect(MixPilotRemoteMappingValidator.sha256(try Data(contentsOf: stagedURL)) == presetHash)

        let state = try await installer.currentState()
        #expect(state?.releaseID == releaseID)
        #expect(state?.mappingVersion == 999)
        #expect(state?.backend == .rekordbox)
        #expect(state?.profileSHA256 == profileHash)

        let restored = try await installer.rollback(
            backend: .rekordbox,
            controllerName: controller
        )
        let rollbackURL = try #require(restored.generatedArtifactURL)
        #expect(restored.releaseID == releaseID)
        #expect(restored.mappingVersion == 999)
        #expect(FileManager.default.fileExists(atPath: rollbackURL.path))
        #expect(try await installer.currentState() == nil)
    }

    @Test func djayProfileStagesWithoutInventingAFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MixPilotDjayMappingPersistence-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let profile = MIDIMappingProfile.developmentDefault
        let profileHash = try MixPilotRemoteMappingValidator.profileSHA256(profile)
        let release = MixPilotRemoteMappingRelease(
            id: UUID(),
            channel: "stable",
            backend: .djay,
            controllerName: "MixPilot Virtual Controller",
            mappingVersion: 7,
            minimumAppBuild: 1,
            minimumSoftwareVersion: nil,
            maximumSoftwareVersion: nil,
            profile: profile,
            profileSHA256: profileHash,
            generatedPresetSHA256: nil,
            publisherSignature: nil,
            applyMode: .nextLaunch,
            mandatory: false,
            rolloutPercentage: 100,
            releaseNotes: "djay profile",
            validationSummary: [:],
            publishedAt: Date()
        )
        let installer = MixPilotRemoteMappingInstaller(
            rootDirectory: root,
            installationID: UUID()
        )

        let staged = try await installer.stage(
            release: release,
            currentAppBuild: 1,
            backend: .djay,
            softwareVersion: "5.2.0",
            controllerName: "MixPilot Virtual Controller"
        )

        #expect(staged.backend == .djay)
        #expect(staged.artifactKind == .profile)
        #expect(staged.generatedArtifactSHA256 == nil)
        #expect(staged.generatedArtifactURL == nil)

        let restored = try await installer.rollback(
            backend: .djay,
            controllerName: "MixPilot Virtual Controller"
        )
        #expect(restored.artifactKind == .profile)
        #expect(restored.generatedArtifactURL == nil)
        #expect(try await installer.currentState() == nil)
    }
}
#endif
