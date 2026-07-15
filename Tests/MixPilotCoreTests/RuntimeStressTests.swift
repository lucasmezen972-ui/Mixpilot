import Testing
@testable import MixPilotCore

@Test("Fifty-track runtime stress simulation stays within valid control ranges")
func runtimeStressSimulation() {
    let report = RuntimeStressSimulator().run(trackCount: 50, framesPerSecond: 30)
    #expect(report.succeeded)
    #expect(report.transitionCount == 49)
    #expect(report.invalidValueCount == 0)
    #expect(report.missingCrossfaderTransitionCount == 0)
    #expect(report.generatedFrameCount > 10_000)
    #expect(report.generatedControlValueCount > report.generatedFrameCount)
    #expect(report.maximumControlJump <= 1)
    #expect(report.finalActiveDeck == .b)
}
