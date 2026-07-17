import Foundation
import Testing
@testable import MixPilotCore

@Suite("Rekordbox advanced compatibility")
struct RekordboxAdvancedCompatibilityTests {
    @Test("Advanced preset adds window focus and both Color FX channels")
    func advancedPresetCoverage() throws {
        let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
            profile: .developmentDefault,
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(preset.csv.contains("SwitchActiveWindow,browserFocus,Button"))
        #expect(preset.csv.contains("CFXParameterCH1,filterA,KnobSlider"))
        #expect(preset.csv.contains("CFXParameterCH2,filterB,KnobSlider"))
        #expect(Set(preset.addedActions) == Set([.browserFocus, .filterA, .filterB]))
        #expect(!preset.csv.contains("echoA"))
        #expect(preset.warnings.contains { $0.contains("Echo") })
    }

    @Test("Compatibility matrix documents every integration route")
    func compatibilityRoutes() {
        let routes = Set(RekordboxCompatibilityCatalog.features.map(\.route))
        #expect(routes.contains(.officialXML))
        #expect(routes.contains(.adaptiveJSON))
        #expect(routes.contains(.oneLibrary))
        #expect(routes.contains(.encryptedDatabaseRead))
        #expect(routes.contains(.midiLearn))
        #expect(routes.contains(.accessibility))
        #expect(routes.contains(.proDJLink))
    }

    @Test("Runtime catalog contains core controls and guarded advanced controls")
    func commandCatalog() {
        let names = Set(RekordboxExtendedCommandCatalog.commands.map(\.csvName))
        #expect(names.contains("PlayPause"))
        #expect(names.contains("Load"))
        #expect(names.contains("SwitchActiveWindow"))
        #expect(names.contains("CFXParameterCH1"))
        #expect(names.contains("CFXParameterCH2"))
        #expect(names.contains("AutoMixStartStop"))
        #expect(RekordboxExtendedCommandCatalog.runtimeCoverage > 0.4)
        #expect(RekordboxExtendedCommandCatalog.runtimeCoverage < 1)
    }

    @Test("Duplicate MIDI codes are rejected after advanced additions")
    func duplicateAdvancedMapping() throws {
        var profile = MIDIMappingProfile.developmentDefault
        profile[.browserFocus] = profile[.playA]

        #expect(throws: RekordboxMIDIPresetError.self) {
            _ = try RekordboxAdvancedMIDIPresetGenerator().generate(profile: profile)
        }
    }
}
