import Foundation
import Testing
@testable import MixPilotCore

@Test("Automatic preset is ready when every critical Live action is installed")
func automaticPresetCriticalCoverage() throws {
    let suite = "MixPilotAutomaticPresetCoverageTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let preset = SeratoXMLPresetGenerator().generate(profile: .developmentDefault)
    MIDIMappingProfile.recordAutomaticPresetInstallation(
        supportedActions: preset.supportedActions,
        version: preset.version,
        defaults: defaults
    )

    #expect(MIDIMappingProfile.automaticPresetCoverageRatio(defaults: defaults) == 1)
    #expect(SeratoAction.automaticPresetCriticalActions.isSubset(of: Set(preset.supportedActions)))
}

@Test("Missing a critical automatic action keeps mapping incomplete")
func missingCriticalAutomaticAction() throws {
    let suite = "MixPilotAutomaticPresetCoverageTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    var actions = Array(SeratoAction.automaticPresetCriticalActions)
    actions.removeAll { $0 == .loadB }
    MIDIMappingProfile.recordAutomaticPresetInstallation(
        supportedActions: actions,
        version: "test",
        defaults: defaults
    )

    #expect(MIDIMappingProfile.automaticPresetCoverageRatio(defaults: defaults) < 1)
}
