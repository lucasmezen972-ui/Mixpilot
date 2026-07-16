#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotSystem
import SwiftUI

private struct RekordboxRowExport: Codable {
    var index: Int
    var fields: [String]
}

private struct RekordboxCompatibilityExport: Codable {
    var generatedAt: Date
    var applicationRunning: Bool
    var processIdentifier: Int32?
    var applicationName: String?
    var bundleIdentifier: String?
    var accessibilityGranted: Bool
    var windowTitle: String?
    var visibleText: [String]
    var rows: [RekordboxRowExport]
}

@MainActor
final class RekordboxCompatibilityLabModel: ObservableObject {
    @Published private(set) var environment: RekordboxEnvironmentStatus?
    @Published private(set) var observation: SeratoWindowObservation?
    @Published private(set) var rows: [SeratoLibraryRow] = []
    @Published private(set) var status = "Aucune inspection effectuée"
    @Published private(set) var isInspecting = false

    private let environmentProbe = RekordboxEnvironmentProbe()
    private let accessibilityBridge = SeratoAccessibilityBridge()

    func inspect() {
        isInspecting = true
        defer { isInspecting = false }

        let environment = environmentProbe.probe()
        self.environment = environment

        guard environment.isRunning else {
            observation = nil
            rows = []
            status = "rekordbox n’est pas lancé."
            return
        }

        let observation = accessibilityBridge.observe(
            software: .rekordbox,
            maxDepth: 8,
            maximumStrings: 1_000
        )
        self.observation = observation

        guard observation.accessibilityGranted else {
            rows = []
            status = "Permission Accessibilité requise."
            return
        }

        rows = accessibilityBridge.libraryRows(software: .rekordbox, maxRows: 1_500)
        if rows.isEmpty {
            status = "rekordbox est observable, mais aucune ligne de playlist exploitable n’a été trouvée."
        } else {
            status = "\(rows.count) ligne(s) détectée(s) dans l’interface rekordbox."
        }
    }

    func requestAccessibility() {
        accessibilityBridge.requestAccessibilityPrompt()
        inspect()
    }

    func activateRekordbox() {
        _ = accessibilityBridge.activate(.rekordbox)
    }

    func exportJSON() {
        guard let environment, let observation else {
            status = "Effectue d’abord une inspection."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Exporter le diagnostic rekordbox"
        panel.nameFieldStringValue = "MixPilot-rekordbox-accessibility.json"
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
            rows: rows.map { RekordboxRowExport(index: $0.index, fields: $0.fields) }
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

struct RekordboxCompatibilityLabView: View {
    @StateObject private var model = RekordboxCompatibilityLabModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Laboratoire de compatibilité rekordbox")
                        .font(.largeTitle.bold())
                    Text("Inspection en lecture seule de l’interface réelle de rekordbox.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }

            HStack {
                Button("Inspecter rekordbox") { model.inspect() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isInspecting)
                Button("Afficher rekordbox") { model.activateRekordbox() }
                Button("Autoriser l’Accessibilité") { model.requestAccessibility() }
                Button("Exporter le JSON") { model.exportJSON() }
                    .disabled(model.observation == nil)
            }

            Text(model.status)
                .font(.headline)

            Divider()

            HStack(spacing: 24) {
                metric("Application", model.environment?.isRunning == true ? "Détectée" : "Absente")
                metric("Accessibilité", model.observation?.accessibilityGranted == true ? "Autorisée" : "Non autorisée")
                metric("Textes visibles", "\(model.observation?.visibleText.count ?? 0)")
                metric("Lignes", "\(model.rows.count)")
            }

            GroupBox("Lignes de playlist détectées") {
                if model.rows.isEmpty {
                    ContentUnavailableView(
                        "Aucune ligne détectée",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Affiche une playlist dans rekordbox puis relance l’inspection.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    List(Array(model.rows.prefix(200))) { row in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ligne \(row.index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(row.displayText)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Text("Aucune commande, aucun clic et aucun MIDI ne sont envoyés depuis ce laboratoire. Les titres et artistes visibles peuvent apparaître dans le fichier JSON exporté.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 900, minHeight: 650)
    }

    private var statusBadge: some View {
        Text("REQUIRES_DEVICE_VALIDATION")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.16), in: Capsule())
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
    }
}
#endif
