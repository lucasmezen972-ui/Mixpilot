import Testing
@testable import MixPilotCore

@Test("Continuous controls require Control Change")
func continuousControlsRequireControlChange() {
    let note = MIDIMessageMapping(kind: .note, number: 60, isMomentary: true)
    let control = MIDIMessageMapping(kind: .controlChange, number: 11)

    #expect(!note.isRuntimeCompatible(with: .volumeA))
    #expect(control.isRuntimeCompatible(with: .volumeA))
}

@Test("Control Change triggers must be momentary")
func controlChangeTriggersMustBeMomentary() {
    let latched = MIDIMessageMapping(kind: .controlChange, number: 20, isMomentary: false)
    let momentary = MIDIMessageMapping(kind: .controlChange, number: 20, isMomentary: true)

    #expect(!latched.isRuntimeCompatible(with: .playA))
    #expect(momentary.isRuntimeCompatible(with: .playA))
}

@Test("The default profile has full compatible Live coverage")
func defaultProfileHasCompatibleCoverage() {
    #expect(MIDIMappingProfile.developmentDefault.liveControlCoverageRatio == 1)
}

@Test("An incompatible continuous mapping lowers Live coverage")
func incompatibleContinuousMappingLowersCoverage() {
    var profile = MIDIMappingProfile.developmentDefault
    profile[.volumeA] = MIDIMessageMapping(kind: .note, number: 11, isMomentary: true)

    #expect(profile.liveControlCoverageRatio < 1)
    #expect(!profile.hasRuntimeCompatibleMapping(for: .volumeA))
}
