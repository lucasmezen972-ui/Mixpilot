import Foundation
import Testing
@testable import MixPilotCore

@Test("Equivalent MIDI mappings have the same validation identifier")
func equivalentMappingsShareFingerprint() {
    var first = MIDIMappingProfile(name: "First")
    first[.playA] = MIDIMessageMapping(kind: .note, channel: 1, number: 60, isMomentary: true)
    first[.volumeA] = MIDIMessageMapping(kind: .controlChange, channel: 1, number: 11)

    var second = MIDIMappingProfile(name: "Second")
    second[.volumeA] = MIDIMessageMapping(kind: .controlChange, channel: 1, number: 11)
    second[.playA] = MIDIMessageMapping(kind: .note, channel: 1, number: 60, isMomentary: true)

    #expect(first.id != second.id)
    #expect(first.name != second.name)
    #expect(first.validationIdentifier == second.validationIdentifier)
}

@Test("Changing one MIDI value invalidates prior command evidence")
func changedMappingChangesFingerprint() {
    var profile = MIDIMappingProfile(name: "Profile")
    profile[.playA] = MIDIMessageMapping(kind: .note, number: 60, isMomentary: true)
    let original = profile.validationIdentifier

    profile[.playA] = MIDIMessageMapping(kind: .note, number: 61, isMomentary: true)

    #expect(profile.validationIdentifier != original)
}

@Test("Metadata and timestamps do not change the mapping fingerprint")
func metadataDoesNotChangeFingerprint() {
    var profile = MIDIMappingProfile(name: "Profile")
    profile[.playA] = MIDIMessageMapping(kind: .note, number: 60, isMomentary: true)
    let original = profile.validationIdentifier

    profile.name = "Renamed"
    profile.updatedAt = Date().addingTimeInterval(10_000)

    #expect(profile.validationIdentifier == original)
}

@Test("The schema version participates in the validation identifier")
func schemaVersionChangesFingerprint() {
    var profile = MIDIMappingProfile(name: "Profile")
    profile[.playA] = MIDIMessageMapping(kind: .note, number: 60, isMomentary: true)
    let original = profile.validationIdentifier

    profile.schemaVersion += 1

    #expect(profile.validationIdentifier != original)
}
