import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotSystem

#if os(macOS)
struct MappingPersistenceTests {
    @Test func validatedProfileCanBeStagedAndRestored() async throws {
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
            software: "rekordbox",
            controllerName: controller,
            mappingVersion: 999,
            minimumAppBuild: 1,
            minimumRekordboxVersion: "5.3.0",
            maximumRekordboxVersion: nil,
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
            rekordboxVersion: "7.0.0",
            controllerName: controller
        )
        #expect(staged.releaseID == releaseID)
        #expect(staged.appliedProfileSHA256 == profileHash)
        #expect(staged.presetSHA256 == presetHash)
        #expect(FileManager.default.fileExists(atPath: staged.presetURL.path))
        #expect(MixPilotRemoteMappingValidator.sha256(try Data(contentsOf: staged.presetURL)) == presetHash)

        let state = try await installer.currentState()
        #expect(state?.releaseID == releaseID)
        #expect(state?.mappingVersion == 999)
        #expect(state?.profileSHA256 == profileHash)

        let restored = try await installer.rollback(controllerName: controller)
        #expect(restored.releaseID == releaseID)
        #expect(restored.mappingVersion == 999)
        #expect(FileManager.default.fileExists(atPath: restored.presetURL.path))
        #expect(try await installer.currentState() == nil)
    }
}
#endif
