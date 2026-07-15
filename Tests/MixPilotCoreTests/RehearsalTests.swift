import Testing
@testable import MixPilotCore

@Test("Rehearsal creates safe alternatives")
func rehearsalCreatesAlternatives() {
    let tracks = SetSimulator().makeTracks(count: 2)
    let plan = TransitionPlanner().plan(from: tracks[0], to: tracks[1])
    let variants = RehearsalEngine().variants(for: plan)

    #expect(!variants.isEmpty)
    #expect(variants.contains { $0.plan.kind == .safeFade || $0.plan.kind == .echoExit })
    #expect(variants.allSatisfy { $0.plan.outgoingTrackID == plan.outgoingTrackID })
    #expect(variants.allSatisfy { $0.plan.incomingTrackID == plan.incomingTrackID })
}

@Test("Stable rehearsal observation scores above a faulty execution")
func stableObservationWins() {
    let tracks = SetSimulator().makeTracks(count: 2)
    let plan = TransitionPlanner().plan(from: tracks[0], to: tracks[1])
    let engine = RehearsalEngine()
    let variants = engine.variants(for: plan)

    let stable = engine.evaluate(
        variant: variants[0],
        observation: RehearsalObservation(
            silenceDuration: 0,
            clippingFrameCount: 0,
            beatOffsetMilliseconds: 20,
            vocalOverlapRatio: 0.1,
            levelDifferenceDB: 1,
            executionCompleted: true
        )
    )
    let faulty = engine.evaluate(
        variant: variants[1],
        observation: RehearsalObservation(
            silenceDuration: 1.4,
            clippingFrameCount: 6,
            beatOffsetMilliseconds: 180,
            vocalOverlapRatio: 0.8,
            levelDifferenceDB: 7,
            executionCompleted: false
        )
    )

    #expect((stable.score?.total ?? 0) > (faulty.score?.total ?? 0))
    let result = engine.selectBest([stable, faulty])
    #expect(result.selectedVariantID == stable.id)
}
