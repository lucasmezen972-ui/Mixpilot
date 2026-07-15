import Testing
@testable import MixPilotCore

@Test("Mapping assistant records confirmations and advances")
func mappingAssistantProgression() {
    var state = MappingWizardState(actions: [.playA, .crossfader])
    #expect(state.steps.count == 2)
    #expect(state.progress == 0)
    #expect(state.currentStep?.action == .playA)

    state.recordCurrentTest(succeeded: true)
    state.moveNext()
    #expect(state.currentStep?.action == .crossfader)
    state.recordCurrentTest(succeeded: true)

    #expect(state.isComplete)
    #expect(state.progress == 1)
}

@Test("Mapping actions expose readable groups and instructions")
func mappingMetadata() {
    #expect(SeratoAction.crossfader.isContinuousControl)
    #expect(!SeratoAction.playA.isContinuousControl)
    #expect(SeratoAction.playA.mappingGroup == .transport)
    #expect(SeratoAction.lowEQA.mappingGroup == .equalizer)
    #expect(!SeratoAction.crossfader.mappingInstruction.isEmpty)
    #expect(SeratoAction.playA.displayName == "Lecture Deck A")
}
