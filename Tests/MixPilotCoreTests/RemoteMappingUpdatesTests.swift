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
}
