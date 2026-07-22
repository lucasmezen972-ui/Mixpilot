import Testing
@testable import MixPilotCore

@Test("Missing permissions and observation remain supervised Live warnings")
func permissionsDoNotBlockSupervisedLive() {
    let report = PreflightReport(items: [
        PreflightItem(
            id: "accessibility",
            title: "Accessibilité",
            detail: "Autorisation manquante",
            status: .failed,
            severity: .critical
        ),
        PreflightItem(
            id: "audio",
            title: "Surveillance audio",
            detail: "Surveillance indisponible",
            status: .failed,
            severity: .critical
        ),
        PreflightItem(
            id: "capability-state-reading",
            title: "Observation",
            detail: "État non vérifiable",
            status: .failed,
            severity: .critical
        ),
    ])

    #expect(report.canStartSupervisedLive)
    #expect(report.supervisedReadiness.warnings.count == 3)
    #expect(report.supervisedReadiness.blockers.isEmpty)
}

@Test("A missing MIDI controller remains a hard supervised Live blocker")
func missingMIDIBlocksSupervisedLive() {
    let report = PreflightReport(items: [
        PreflightItem(
            id: "midi",
            title: "MIDI",
            detail: "Contrôleur impossible à créer",
            status: .failed,
            severity: .critical
        ),
    ])

    #expect(!report.canStartSupervisedLive)
    #expect(report.supervisedReadiness.blockers.map(\.id) == ["midi"])
}

@Test("A missing or invalid project remains a hard supervised Live blocker")
func invalidProjectBlocksSupervisedLive() {
    let report = PreflightReport(items: [
        PreflightItem(
            id: "project",
            title: "Plan du set",
            detail: "Moins de deux titres exploitables",
            status: .failed,
            severity: .critical
        ),
    ])

    #expect(!report.canStartSupervisedLive)
    #expect(report.supervisedReadiness.blockers.map(\.id) == ["project"])
}

@Test("A closed backend and pending device validation are warnings in supervised mode")
func launchableBackendAndPendingValidationRemainWarnings() {
    let report = PreflightReport(items: [
        PreflightItem(
            id: "backend-environment",
            title: "rekordbox fermé",
            detail: "L’application peut être lancée depuis MixPilot.",
            status: .failed,
            severity: .critical
        ),
        PreflightItem(
            id: "backend-validation-play",
            title: "Play non confirmé",
            detail: "Validation matérielle en attente",
            status: .failed,
            severity: .critical
        ),
    ])

    #expect(report.canStartSupervisedLive)
    #expect(report.supervisedReadiness.warnings.map(\.id) == [
        "backend-environment",
        "backend-validation-play",
    ])
}
