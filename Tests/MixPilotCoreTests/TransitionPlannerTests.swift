import Testing
@testable import MixPilotCore

@Test("A large BPM gap selects a safe transition")
func largeBPMGapUsesSafeTransition() {
    let outgoing = Track(title: "A", artist: "A", bpm: 90, duration: 200, energy: 0.5, vocalDensity: 0.4, profile: .family)
    let incoming = Track(title: "B", artist: "B", bpm: 130, duration: 200, energy: 0.6, vocalDensity: 0.4, profile: .family)
    let plan = TransitionPlanner().plan(from: outgoing, to: incoming)
    #expect(plan.kind == .echoExit || plan.kind == .safeFade)
    #expect(plan.confidence >= 70)
}

@Test("Rap tracks protect against vocal overlap")
func rapUsesRapSwitch() {
    let outgoing = Track(title: "A", artist: "A", bpm: 100, duration: 200, energy: 0.7, vocalDensity: 0.9, profile: .rap)
    let incoming = Track(title: "B", artist: "B", bpm: 102, duration: 200, energy: 0.8, vocalDensity: 0.85, profile: .rap)
    let plan = TransitionPlanner().plan(from: outgoing, to: incoming)
    #expect(plan.kind == .rapSwitch)
    #expect(plan.bars == 8)
}

@Test("A set produces exactly n minus one transitions")
func setPlanCount() {
    let tracks = SetSimulator().makeTracks(count: 50)
    let plans = TransitionPlanner().planSet(tracks)
    #expect(plans.count == 49)
}
