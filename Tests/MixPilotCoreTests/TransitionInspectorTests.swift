import Testing
@testable import MixPilotCore

@Test("Inspector can force a transition kind and duration")
func forceTransitionVariant() {
    let tracks = SetSimulator().makeTracks(count: 2)
    let plan = TransitionPlanner().plan(
        from: tracks[0],
        to: tracks[1],
        forcing: .echoExit,
        bars: 6
    )

    #expect(plan.kind == .echoExit)
    #expect(plan.bars == 6)
    #expect(plan.outgoingTrackID == tracks[0].id)
    #expect(plan.incomingTrackID == tracks[1].id)
    #expect(plan.lanes.contains { $0.target == .echoAmount })
    #expect(plan.reasons.contains { $0.contains("inspecteur") })
}
