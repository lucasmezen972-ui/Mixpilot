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
        let descriptor = selectedBackend.flatMap { identifier in
            backendDescriptors.first { $0.identifier == identifier }
        }
        let diagnostic = MixPilotDiagnosticSnapshot(
            appVersion: Self.applicationVersion,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: Self.machineArchitecture,
            backendIdentifier: selectedBackend,
            backendSoftwareVersion: descriptor?.environment.softwareVersion,
            backendRunning: descriptor?.environment.isRunning == true,
            accessibilityGranted: accessibilityStatus == "Autorisée",
            midiMappingCompletion: mappingProfile.completionRatio,
            audioMonitorRunning: audioMonitor.isRunning,
            internetAvailable: connectivityStatus.isAvailable,
            connectedToPower: powerStatus.connectedToPower,
            emergencyDuration: emergencyDuration,
            projectTrackCount: project?.tracks.count ?? 0,
            projectTransitionCount: project?.transitions.count ?? 0,
            projectLocked: project?.locked == true,
            autopilotState: snapshot.state,
            completedTransitions: snapshot.completedTransitions,
            validations: diagnosticValidations,
            recentEvents: anonymizedRuntimeEvents
        )

        Task {
            do {
                let result = try await MixPilotDiagnosticExporter(directory: directory).export(diagnostic)
                await MainActor.run {
                    NSWorkspace.shared.activateFileViewerSelecting([result.jsonURL, result.markdownURL])
                }
            } catch {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Le diagnostic n’a pas pu être exporté"
                    alert.informativeText = "Vérifie que le dossier est accessible et qu’il reste assez d’espace, puis réessaie."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    private var diagnosticValidations: [MixPilotDiagnosticValidation] {
        var items = backendValidationReport?.items.map {
            MixPilotDiagnosticValidation(
                name: $0.title,
                status: diagnosticStatus($0.status),
                detail: $0.detail
            )
        } ?? []

        items.append(MixPilotDiagnosticValidation(
            name: "Surveillance audio sur le Mac cible",
            status: audioMonitor.isRunning ? .requiresDeviceValidation : .failed,
            detail: audioMonitor.isRunning
                ? "La surveillance est active, mais l’absence de blanc et l’endurance doivent encore être validées sur le système audio réel."
                : "La surveillance audio n’est pas active."
        ))
        items.append(MixPilotDiagnosticValidation(
            name: "Validation matérielle du backend",
            status: .requiresDeviceValidation,
            detail: selectedBackend.map {
                "Les commandes de \($0.displayName) doivent être confirmées avec la version, le contrôleur et le routage audio utilisés pendant le Live."
            } ?? "Aucun backend DJ n’est sélectionné."
        ))
        return items
    }

    private var anonymizedRuntimeEvents: [String] {
        let privateValues = preparedProject?.tracks.flatMap { prepared -> [String] in
            [prepared.track.title, prepared.track.artist].filter { !$0.isEmpty }
        } ?? []

        return runtimeEvents.suffix(100).map { event in
            privateValues.reduce(event) { partial, privateValue in
                partial.replacingOccurrences(
                    of: privateValue,
                    with: "[MORCEAU]",
                    options: [.caseInsensitive, .diacriticInsensitive]
                )
            }
        }
    }

    private func diagnosticStatus(
        _ status: DJValidationStatus
    ) -> MixPilotDiagnosticValidationStatus {
        switch status {
        case .automatedSuccess: .automatedSuccess
        case .simulatedSuccess: .simulatedSuccess
        case .requiresBackendValidation, .unknown: .requiresBackendValidation
        case .requiresDeviceValidation: .requiresDeviceValidation
        case .blockedByPlatform: .blockedByPlatform
        case .failed: .failed
        }
    }

    private static var applicationVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short, let build { return "\(short) (\(build))" }
        return short ?? build ?? "Version inconnue"
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
