import Foundation
import Testing
@testable import MixPilotCore

@Test("Set timeline orders tracks and accounts for transition overlap")
func setTimelineLayout() {
    let tracks = SetSimulator().makeTracks(count: 5)
    let project = SetPreparationEngine().prepare(name: "Timeline", tracks: tracks)
    let timeline = SetTimeline(project: project)

    #expect(timeline.segments.count == 5)
    #expect(timeline.totalDuration > 0)
    #expect(timeline.segments[0].startTime == 0)
    #expect(timeline.segments[1].startTime < timeline.segments[0].endTime)
    #expect(timeline.segments.allSatisfy { $0.endTime >= $0.startTime })
}

@Test("Transition inspection connects adjacent prepared tracks")
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
}

@Test("Diagnostic report exports JSON and readable text")
func diagnosticExport() throws {
    let project = SetPreparationEngine().prepare(
        name: "Diagnostic",
        tracks: SetSimulator().makeTracks(count: 3)
    )
    let report = DiagnosticReport(
        appVersion: "0.3-test",
        environment: DiagnosticEnvironment(
            seratoStatus: "Serato détecté",
            midiStatus: "Port actif",
            accessibilityStatus: "Autorisée",
            audioStatus: "Surveillance active",
            libraryRowCount: 3,
            emergencyStatus: "30 min prêtes"
        ),
        project: DiagnosticProjectSummary(project: project),
        runtimeState: .idle,
        runtimeStatus: "Prêt",
        recentEvents: ["Projet préparé"],
        preflight: nil,
        validationLabels: ["Core": "AUTOMATED_SUCCESS"]
    )

    let json = try report.encodedJSON()
    #expect(!json.isEmpty)
    let text = report.plainText()
    #expect(text.contains("MixPilot Autopilot"))
    #expect(text.contains("Diagnostic"))
    #expect(text.contains("AUTOMATED_SUCCESS"))
}
