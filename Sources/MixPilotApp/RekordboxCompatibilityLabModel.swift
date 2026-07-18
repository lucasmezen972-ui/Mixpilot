#if os(macOS)
import AppKit
import Combine
import Foundation
import MixPilotCore
import MixPilotSystem
import UniformTypeIdentifiers

struct RekordboxRowExport: Codable {
    var index: Int
    var fields: [String]
}

struct RekordboxCompatibilityExport: Codable {
    var generatedAt: Date
    var applicationRunning: Bool
    var processIdentifier: Int32?
    var applicationName: String?
    var bundleIdentifier: String?
    var accessibilityGranted: Bool
    var windowTitle: String?
    var visibleText: [String]
    var rows: [RekordboxRowExport]
    var actionableElements: [RekordboxActionableElement]
}

@MainActor
final class RekordboxCompatibilityLabModel: ObservableObject {
    @Published private(set) var environment: RekordboxEnvironmentStatus?
    @Published private(set) var observation: DJWindowObservation?
    @Published private(set) var rows: [DJLibraryRow] = []
    @Published private(set) var actionableElements: [RekordboxActionableElement] = []
    @Published private(set) var status = "Aucune inspection effectuée"
    @Published private(set) var isInspecting = false

    private let environmentProbe = RekordboxEnvironmentProbe()
    private let accessibilityBridge = DJAccessibilityBridge()
    private let actionBridge = RekordboxAccessibilityActionBridge()

    func inspect() {
        isInspecting = true
        defer { isInspecting = false }

        let environment = environmentProbe.probe()
        self.environment = environment

        guard environment.isRunning else {
            observation = nil
            rows = []
            actionableElements = []
            status = "rekordbox n’est pas lancé."
            return
        }

        let observation = accessibilityBridge.observe(
            backend: .rekordbox,
            maxDepth: 8,
            maximumStrings: 1_000
        )
        self.observation = observation

        guard observation.accessibilityGranted else {
            rows = []
            actionableElements = []
            status = "Permission Accessibilité requise."
            return
        }

        rows = accessibilityBridge.libraryRows(backend: .rekordbox, maxRows: 1_500)
        do {
            actionableElements = try actionBridge.inspect()
            status = "\(rows.count) ligne(s) et \(actionableElements.count) contrôle(s) actionnable(s) détectés."
        } catch {
            actionableElements = []
            status = error.localizedDescription
        }
    }

    func requestAccessibility() {
        accessibilityBridge.requestAccessibilityPrompt()
        inspect()
    }

    func activateRekordbox() {
        do {
            try accessibilityBridge.activate(.rekordbox)
        } catch {
            status = error.localizedDescription
        }
    }

    func perform(element: RekordboxActionableElement, action: String) {
        var allowSensitiveAction = false
        if element.isPotentiallyDestructive {
            let alert = NSAlert()
            alert.messageText = "Confirmer l’action rekordbox"
            alert.informativeText = "Le contrôle « \(element.displayName) » peut modifier la bibliothèque. MixPilot exécutera uniquement l’action \(action)."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Exécuter")
            alert.addButton(withTitle: "Annuler")
            guard alert.runModal() == .alertFirstButtonReturn else {
                status = "Action annulée."
                return
            }
            allowSensitiveAction = true
        }

        do {
            try actionBridge.perform(
                element: element,
                action: action,
                allowPotentiallyDestructive: allowSensitiveAction
            )
            status = "Action \(action) envoyée à « \(element.displayName) »."
            inspect()
        } catch {
            status = "Action refusée : \(error.localizedDescription)"
        }
    }

    func exportJSON() {
        guard let environment, let observation else {
            status = "Effectue d’abord une inspection."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Exporter le diagnostic rekordbox"
        panel.nameFieldStringValue = "MixPilot-rekordbox-compatibility.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let export = RekordboxCompatibilityExport(
            generatedAt: Date(),
            applicationRunning: environment.isRunning,
            processIdentifier: environment.processIdentifier,
            applicationName: environment.applicationName,
            bundleIdentifier: environment.bundleIdentifier,
            accessibilityGranted: observation.accessibilityGranted,
            windowTitle: observation.windowTitle,
            visibleText: observation.visibleText,
            rows: rows.map { RekordboxRowExport(index: $0.index, fields: $0.fields) },
            actionableElements: actionableElements
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(export).write(to: url, options: .atomic)
            status = "Diagnostic exporté : \(url.lastPathComponent)"
        } catch {
            status = "Échec export : \(error.localizedDescription)"
        }
    }
}
#endif
