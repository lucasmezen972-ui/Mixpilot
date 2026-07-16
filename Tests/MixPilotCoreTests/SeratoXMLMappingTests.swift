import Foundation
import Testing
@testable import MixPilotCore

@Test("Generated Serato preset is well-formed and uses the MixPilot profile")
func generatedSeratoPresetIsWellFormed() throws {
    let profile = MIDIMappingProfile.developmentDefault
    let preset = SeratoXMLPresetGenerator().generate(profile: profile)

    #expect(preset.xml.contains("<midi app="))
    #expect(preset.xml.contains("<play deck_set=\"Default\" deck_id=\"0\""))
    #expect(preset.xml.contains("<load_track deck_set=\"Default\" deck_id=\"1\""))
    #expect(preset.xml.contains("<upfader deck_set=\"Default\" deck_id=\"0\""))
    #expect(preset.xml.contains("<deck_eq_lo deck_set=\"Default\" deck_id=\"0\""))
    #expect(preset.xml.contains("<deck_filter_auto deck_set=\"Default\" deck_id=\"1\""))
    #expect(preset.xml.contains("<pitch_slider deck_set=\"Default\" deck_id=\"1\""))
    #expect(preset.xml.contains("<library_scroll deck_set=\"Default\""))
    #expect(preset.xml.contains("<tab_library deck_set=\"Default\""))

    let playMapping = try #require(profile[.playA])
    #expect(preset.xml.contains("channel=\"\(Int(playMapping.channel) + 1)\" event_type=\"Note On\" control=\"\(playMapping.number)\""))

    let volumeMapping = try #require(profile[.volumeA])
    #expect(preset.xml.contains("channel=\"\(Int(volumeMapping.channel) + 1)\" event_type=\"Control Change\" data_type=\"Absolute 7\" control=\"\(volumeMapping.number)\""))

    let parser = XMLParser(data: Data(preset.xml.utf8))
    #expect(parser.parse())
    #expect(parser.parserError == nil)
}

@Test("Unsupported Serato commands remain explicit instead of being guessed")
func unsupportedCommandsAreExplicit() {
    let preset = SeratoXMLPresetGenerator().generate(profile: .developmentDefault)
    let expected: Set<SeratoAction> = [
        .crossfader,
        .echoA,
        .echoB,
        .echoAmountA,
        .echoAmountB,
    ]

    #expect(Set(preset.unsupportedActions) == expected)
    #expect(!preset.xml.contains("<crossfader"))
    #expect(!preset.xml.contains("unsupported_command"))
    #expect(preset.coverageRatio > 0.8)
}

@Test("Every generated control has a unique MIDI signature")
func generatedControlsHaveUniqueMIDISignatures() {
    let profile = MIDIMappingProfile.developmentDefault
    let preset = SeratoXMLPresetGenerator().generate(profile: profile)
    var signatures: Set<String> = []

    for action in preset.supportedActions {
        guard let mapping = profile[action] else { continue }
        let signature = "\(mapping.kind.rawValue):\(mapping.channel):\(mapping.number)"
        #expect(signatures.insert(signature).inserted)
    }
}

@Test("Serato application version is escaped in generated XML")
func seratoVersionIsEscaped() {
    let preset = SeratoXMLPresetGenerator().generate(
        profile: .developmentDefault,
        seratoApplicationVersion: "Serato & Test \"4\""
    )
    #expect(preset.xml.contains("Serato &amp; Test &quot;4&quot;"))
}
