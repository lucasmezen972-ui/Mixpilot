import Testing
@testable import MixPilotCore

@Test("Serato keeps direct deck control as its preferred mode")
func seratoCapabilities() {
    let capabilities = DJSoftware.serato.capabilities
    #expect(capabilities.spotifyLibrary)
    #expect(!capabilities.builtInAutomix)
    #expect(capabilities.customMIDILearn)
    #expect(capabilities.detailedDeckAutomation)
    #expect(capabilities.preferredExecutionMode == .directDeckControl)
}

@Test("djay uses Automix queue without replacing the MixPilot engine")
func djayCapabilities() {
    let capabilities = DJSoftware.djay.capabilities
    #expect(capabilities.spotifyLibrary)
    #expect(capabilities.builtInAutomix)
    #expect(capabilities.customMIDILearn)
    #expect(!capabilities.detailedDeckAutomation)
    #expect(capabilities.preferredExecutionMode == .automixQueue)
    #expect(capabilities.validationStatus == .requiresDeviceValidation)
}
