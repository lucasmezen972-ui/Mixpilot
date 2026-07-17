import Testing
@testable import MixPilotCore

@Test("Every planned transition has independent incoming and outgoing volume lanes")
func everyTransitionHasVolumeFallback() {
    let tracks = SetSimulator().makeTracks(count: 40)
    let plans = TransitionPlanner().planSet(tracks)

    #expect(!plans.isEmpty)
    for plan in plans {
        #expect(plan.lanes.contains { $0.target == .incomingVolume })
        #expect(plan.lanes.contains { $0.target == .outgoingVolume })
    }
}

@Test("Volume fallback completes a full handoff without relying on crossfader")
func volumeFallbackCompletesHandoff() {
    let tracks = SetSimulator().makeTracks(count: 2)
    let plan = TransitionPlanner().plan(from: tracks[0], to: tracks[1])
    let frames = TransitionFrameGenerator().frames(for: plan, outgoingDeck: .a, framesPerSecond: 10)

    let first = frames.first
    let last = frames.last
    #expect(first?.values[.volumeA] == 1)
    #expect(first?.values[.volumeB] == 0)
    #expect(last?.values[.volumeA] == 0)
    #expect(last?.values[.volumeB] == 1)
}
