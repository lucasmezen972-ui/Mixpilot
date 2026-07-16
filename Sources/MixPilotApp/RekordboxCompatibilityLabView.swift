#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotSystem
import SwiftUI
import UniformTypeIdentifiers

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
    var actionableElements: [RekordboxActionableElement]
}

@MainActor
final class RekordboxCompatibilityLabModel: ObservableObject {
    @Published private(set) var environment: RekordboxEnvironmentStatus?
    @Published private(set) var observation: SeratoWindowObservation?
    @Published private(set) var rows: [SeratoLibraryRow] = []
    @Published private(set) var actionableElements: [RekordboxActionableElement] = []
    @Published private(set) var status = "Aucune inspection effectuée"
    @Published private(set) var isInspecting = false

    private let environmentProbe = RekordboxEnvironmentProbe()
    private let accessibilityBridge = SeratoAccessibilityBridge()
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
            software: .rekordbox,
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

        rows = accessibilityBridge.libraryRows(software: .rekordbox, maxRows: 1_500)
        do {
            actionableElements = try actionBridge.inspect()
        } catch {
            actionableElements = []
            status = error.localizedDescription
            return
        }

        status = "\(rows.count) ligne(s) et \(actionableElements.count) contrôle(s) actionnable(s) détectés."
    }

    func requestAccessibility() {
        accessibilityBridge.requestAccessibilityPrompt()
        inspect()
    }

    func activateRekordbox() {
        _ = accessibilityBridge.activate(.rekordbox)
    }

    func perform(element: RekordboxActionableElement, action: String) {
        var allowDestructive = false
        if element.isPotentiallyDestructive {
            let alert = NSAlert()
            alert.messageText = "Confirmer l’action rekordbox"
            alert.informativeText = "Le contrôle « \(element.displayName) » peut modifier ou supprimer des données. MixPilot exécutera uniquement l’action \(action)."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Exécuter")
            alert.addButton(withTitle: "Annuler")
            guard alert.runModal() == .alertFirstButtonReturn else {
                status = "Action annulée."
                return
            }
            allowDestructive = true
        }

        do {
            try actionBridge.perform(
                element: element,
                action: action,
                allowPotentiallyDestructive: allowDestructive
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

struct RekordboxCompatibilityLabView: View {
    @ObservedObject var appModel: AppModel
    @StateObject private var model = RekordboxCompatibilityLabModel()
    @State private var actionsArmed = false
    @State private var selectedElementID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Contrôle et compatibilité rekordbox")
                        .font(.largeTitle.bold())
                    Text("Inspection, tests MIDI et actions Accessibilité protégées sur l’interface réelle.")
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
                Spacer()
                Toggle("Armer les actions", isOn: $actionsArmed)
                    .toggleStyle(.switch)
            }

            Text(model.status)
                .font(.headline)

            HStack(spacing: 24) {
                metric("Application", model.environment?.isRunning == true ? "Détectée" : "Absente")
                metric("Accessibilité", model.observation?.accessibilityGranted == true ? "Autorisée" : "Non autorisée")
                metric("Lignes", "\(model.rows.count)")
                metric("Contrôles", "\(model.actionableElements.count)")
                metric("Mapping MIDI", "\(Int(appModel.mappingProfile.completionRatio * 100)) %")
            }

            TabView {
                midiControls
                    .tabItem { Label("Live MIDI", systemImage: "slider.horizontal.3") }
                accessibilityControls
                    .tabItem { Label("Interface", systemImage: "cursorarrow.click") }
                playlistRows
                    .tabItem { Label("Playlist", systemImage: "list.bullet.rectangle") }
            }

            Text("Le mode Live utilise les mêmes intentions de haut niveau que Serato, mais rekordbox doit apprendre les messages du contrôleur virtuel. Les actions potentiellement destructrices demandent toujours une confirmation séparée.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 980, minHeight: 720)
        .onAppear { model.inspect() }
    }

    private var midiControls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Commandes Live envoyées par le port MIDI virtuel")
                    .font(.title2.bold())
                Text("Ces boutons envoient de vraies commandes MIDI. Ils restent désactivés tant que les actions ne sont pas armées.")
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 24) {
                    deckControls(title: "Deck A", play: .playA, pause: .pauseA, sync: .syncA, load: .loadA)
                    deckControls(title: "Deck B", play: .playB, pause: .pauseB, sync: .syncB, load: .loadB)
                }

                GroupBox("Navigation et mixeur") {
                    HStack {
                        actionButton("Focus navigateur", action: .browserFocus)
                        actionButton("Titre suivant", action: .browserDown)
                        actionButton("Crossfader au centre", action: .crossfader)
                        actionButton("Volume A à 50 %", action: .volumeA)
                        actionButton("Volume B à 50 %", action: .volumeB)
                    }
                    .padding(8)
                }
            }
            .padding(8)
        }
    }

    private var accessibilityControls: some View {
        GroupBox("Contrôles Accessibilité détectés") {
            if model.actionableElements.isEmpty {
                ContentUnavailableView(
                    "Aucun contrôle actionnable",
                    systemImage: "cursorarrow.slash",
                    description: Text("Affiche le panneau souhaité dans rekordbox, puis relance l’inspection.")
                )
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                HStack(spacing: 12) {
                    List(model.actionableElements, selection: $selectedElementID) { element in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(element.displayName)
                                if element.isPotentiallyDestructive {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                            Text("\(element.role) • \(element.actions.joined(separator: ", "))")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .tag(element.id)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        if let selectedElement {
                            Text(selectedElement.displayName).font(.headline)
                            Text(selectedElement.fingerprint)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                            ForEach(selectedElement.actions, id: \.self) { action in
                                Button("Exécuter \(action)") {
                                    model.perform(element: selectedElement, action: action)
                                }
                                .disabled(!actionsArmed)
                            }
                        } else {
                            Text("Sélectionne un contrôle rekordbox.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .frame(width: 280, alignment: .topLeading)
                    .padding(8)
                }
            }
        }
    }

    private var playlistRows: some View {
        GroupBox("Lignes de playlist détectées") {
            if model.rows.isEmpty {
                ContentUnavailableView(
                    "Aucune ligne détectée",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Affiche une playlist dans rekordbox puis relance l’inspection.")
                )
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                List(Array(model.rows.prefix(300))) { row in
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
    }

    private var selectedElement: RekordboxActionableElement? {
        guard let selectedElementID else { return nil }
        return model.actionableElements.first { $0.id == selectedElementID }
    }

    private func deckControls(
        title: String,
        play: SeratoAction,
        pause: SeratoAction,
        sync: SeratoAction,
        load: SeratoAction
    ) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 8) {
                actionButton("Charger", action: load)
                actionButton("Lecture", action: play)
                actionButton("Pause", action: pause)
                actionButton("Sync", action: sync)
            }
            .padding(8)
            .frame(minWidth: 220, alignment: .leading)
        }
    }

    private func actionButton(_ title: String, action: SeratoAction) -> some View {
        Button(title) { appModel.testMapping(action) }
            .disabled(!actionsArmed)
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
