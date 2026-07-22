import Foundation
import Testing
@testable import MixPilotCore

@Test("Diagnostic redactor removes home paths and secrets")
func diagnosticRedaction() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let input = "file=\(home)/Music token=super-secret sk-example1234567890"
    let output = DiagnosticRedactor.redact(input)
    #expect(!output.contains(home))
    #expect(!output.contains("super-secret"))
    #expect(!output.contains("sk-example"))
}

@Test("Diagnostic exporter creates JSON and Markdown files")
func diagnosticExporterCreatesFiles() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }

    let snapshot = DiagnosticSnapshot(
        appVersion: "0.3-test",
        operatingSystem: "macOS Test",
        architecture: "arm64",
        seratoRunning: false,
        accessibilityGranted: false,
        midiMappingCompletion: 1,
        audioMonitorRunning: true,
        internetAvailable: true,
        connectedToPower: true,
        emergencyDuration: 2_000,
        projectTrackCount: 10,
        projectTransitionCount: 9,
        projectLocked: true,
        autopilotState: .idle,
        completedTransitions: 0,
        validations: [
            DiagnosticValidation(name: "Core", status: .simulatedSuccess, detail: "Tests passés")
        ],
        recentEvents: ["Loaded /private/tmp/mixpilot-tests/private/path"]
    )
    let result = try await DiagnosticExporter(directory: directory).export(snapshot)
    #expect(FileManager.default.fileExists(atPath: result.jsonURL.path))
    #expect(FileManager.default.fileExists(atPath: result.markdownURL.path))
    let markdown = try String(contentsOf: result.markdownURL, encoding: .utf8)
    #expect(markdown.contains("Diagnostic MixPilot"))
}

@Test("Incident journal persists recent incidents")
func incidentJournalRoundTrip() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("incidents.jsonl")
    defer { try? FileManager.default.removeItem(at: directory) }

    let journal = IncidentJournal(fileURL: file)
    let first = Incident(kind: .slowLoad, message: "Slow", recovered: true)
    let second = Incident(kind: .audioSilence, message: "Silent", recovered: false)
    try await journal.append(first)
    try await journal.append(second)
    let restored = try await journal.readRecent()

    #expect(restored.count == 2)
    #expect(restored[0].kind == .slowLoad)
    #expect(restored[1].kind == .audioSilence)
}
