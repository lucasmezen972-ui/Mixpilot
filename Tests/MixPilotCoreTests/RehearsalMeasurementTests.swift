import Testing
@testable import MixPilotCore

@Test("Local audio analysis produces a measurable rehearsal observation")
func rehearsalMeasurement() {
    let tracks = SetSimulator().makeTracks(count: 2)
    let plan = TransitionPlanner().plan(from: tracks[0], to: tracks[1])
    let beatPeriod = 60 / plan.targetBPM
    let analysis = LocalAudioAnalysis(
        duration: Double(plan.bars * 4) * beatPeriod,
        integratedRMS: 0.25,
        peak: 0.8,
        onsets: [],
        beatGrid: BeatGridEstimate(
            bpm: plan.targetBPM,
            beatPeriod: beatPeriod,
            phase: 0,
            confidence: 0.9,
            beatTimes: [0, beatPeriod, beatPeriod * 2]
        ),
        energySections: [
            EnergySection(start: 0, end: 2, normalizedEnergy: 0.5, kind: .medium),
            EnergySection(start: 2, end: 4, normalizedEnergy: 0.8, kind: .high),
        ]
    )

    let observation = RehearsalMeasurementBuilder().makeObservation(
        analysis: analysis,
        plan: plan,
        outgoing: tracks[0],
        incoming: tracks[1]
    )

    #expect(observation.executionCompleted)
    #expect(observation.beatOffsetMilliseconds < 1)
    #expect(observation.silenceDuration == 0)
    #expect(observation.clippingFrameCount == 0)
}

@Test("Clipped and incomplete audio is penalized")
func faultyRehearsalMeasurement() {
    let tracks = SetSimulator().makeTracks(count: 2)
    let plan = TransitionPlanner().plan(from: tracks[0], to: tracks[1])
    let analysis = LocalAudioAnalysis(
        duration: 1,
        integratedRMS: 0.01,
        peak: 1,
        onsets: [],
        beatGrid: nil,
        energySections: [
            EnergySection(start: 0, end: 1, normalizedEnergy: 0.01, kind: .quiet),
        ]
    )
    let observation = RehearsalMeasurementBuilder().makeObservation(
        analysis: analysis,
        plan: plan,
        outgoing: tracks[0],
        incoming: tracks[1]
    )
    let variant = RehearsalVariant(plan: plan, label: "Test")
    let evaluated = RehearsalEngine().evaluate(variant: variant, observation: observation)

    #expect(!observation.executionCompleted)
    #expect(observation.clippingFrameCount == 1)
    #expect((evaluated.score?.total ?? 100) < 70)
}
