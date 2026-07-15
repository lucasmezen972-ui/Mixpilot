#if os(macOS)
import AppKit
import Foundation
import MixPilotCore

@MainActor
extension AppModel {
    func exportDiagnostics() {
        let panel = NSOpenPanel()
        panel.title = "Choisir le dossier du diagnostic MixPilot"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let directory = panel.url else { return }

        let project = preparedProject
        let snapshot = DiagnosticSnapshot(
            appVersion: Self.applicationVersion,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: Self.machineArchitecture,
            seratoRunning: seratoStatus.contains("détecté"),
            accessibilityGranted: accessibilityStatus == "Autorisée",
            midiMappingCompletion: mappingProfile.completionRatio,
            audioMonitorRunning: audioStatus.contains("active"),
            internetAvailable: connectivityStatus.isAvailable,
            connectedToPower: powerStatus.connectedToPower,
            emergencyDuration: emergencyDuration,
            projectTrackCount: project?.tracks.count ?? 0,
            projectTransitionCount: project?.transitions.count ?? 0,
            projectLocked: project?.locked == true,
            autopilotState: self.snapshot.state,
            completedTransitions: self.snapshot.completedTransitions,
            validations: [
                DiagnosticValidation(name: "Tests Core", status: .simulatedSuccess, detail: "Validés dans GitHub Actions"),
                DiagnosticValidation(name: "Simulation 50 titres", status: .simulatedSuccess, detail: "Incidents et récupérations validés"),
                DiagnosticValidation(name: "Stress-test commandes", status: .simulatedSuccess, detail: "49 transitions générées dans les limites"),
                DiagnosticValidation(name: "Serato réel", status: .requiresValidation, detail: seratoStatus),
                DiagnosticValidation(name: "Audio réel", status: .requiresValidation, detail: audioStatus),
            ],
            recentEvents: runtimeEvents
        )

        Task {
            do {
                let result = try await DiagnosticExporter(directory: directory).export(snapshot)
                await MainActor.run {
                    NSWorkspace.shared.activateFileViewerSelecting([result.jsonURL, result.markdownURL])
                }
            } catch {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Échec de l’export diagnostic"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    private static var applicationVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return [short, build].compactMap { $0 }.joined(separator: " (") + (short != nil && build != nil ? ")" : "")
    }

    private static var machineArchitecture: String {
        var system = utsname()
        uname(&system)
        return withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
#endif
