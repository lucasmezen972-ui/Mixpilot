import Testing
@testable import MixPilotCore

@Test("Set timeline orders tracks and accounts for overlap")
func setTimelineLayout() {
    let tracks = SetSimulator().makeTracks(count: 5)
    let project = SetPreparationEngine().prepare(name: "Timeline", tracks: tracks)
    let timeline = SetTimeline(project: project)

    #expect(timeline.segments.count == 5)
    #expect(timeline.totalDuration > 0)
    #expect(timeline.segments[0].startTime == 0)
    #expect(timeline.segments[1].startTime < timeline.segments[0].endTime)
    #expect(timeline.segments.allSatisfy { $0.endTime >= $0.startTime })
    #expect(timeline.segments.dropLast().allSatisfy { $0.transitionAfter != nil })
}

@Test("Transition inspection connects adjacent tracks and cue markers")
func transitionInspection() {
    let project = SetPreparationEngine().prepare(
        name: "Inspection",
        tracks: SetSimulator().makeTracks(count: 3)
    )
    let inspection = TransitionInspection(project: project, transitionIndex: 0)

    #expect(inspection != nil)
    #expect(inspection?.outgoing.track.id == project.tracks[0].track.id)
    #expect(inspection?.incoming.track.id == project.tracks[1].track.id)
    #expect(inspection?.plan.id == project.transitions[0].id)
    #expect(inspection?.mixOutMarker != nil)
    #expect(inspection?.mixInMarker != nil)
    #expect(!(inspection?.riskLevel.isEmpty ?? true))
}
