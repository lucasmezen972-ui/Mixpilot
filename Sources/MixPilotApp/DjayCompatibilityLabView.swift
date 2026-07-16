#if os(macOS)
import AppKit
import Combine
import Foundation
import MixPilotCore
import MixPilotSystem
import SwiftUI

private struct DjayCompatibilityExport: Codable {
    var capture: DjayAccessibilityCapture
    var readiness: DjayAutomixReadinessReport
}

@MainActor
final class DjayCompatibilityLabModel: ObservableObject {
    @Published private(set) var capture: DjayAccessibilityCapture?
    @Published private(set) var readiness: DjayAutomixReadinessReport?
    @Published private(set) var status = "Aucune inspection effectuée"
    @Published private(set) var isInspecting = false

    private let inspector = DjayAccessibilityInspector()
    private let analyzer = DjayAutomixQueueAnalyzer()

    func inspect() {
        guard !isInspecting else { return }
        isInspecting = true
        status = "Inspection de djay en lecture seule…"

        let capture = inspector.capture()
        let readiness = analyzer.analyze(nodes: capture.nodes)
        self.capture = capture
        self.readiness = readiness
        isInspecting = false

        if let failure = capture.failureReason {
            status = failure
        } else {
            status = "\(capture.nodes.count) éléments inspectés • confiance Automix \(readiness.confidence) %"
        }
    }

    func exportJSON() {
        guard let capture, let readiness else {
            status = "Effectue d’abord une inspection."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Exporter le diagnostic djay"
        panel.nameFieldStringValue = "MixPilot-djay-accessibility-\(Int(capture.capturedAt.timeIntervalSince1970)).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(DjayCompatibilityExport(capture: capture, readiness: readiness)).write(to: url, options: .atomic)
            status = "Diagnostic exporté localement : \(url.lastPathComponent)"
        } catch {
            status = "Échec export : \(error.localizedDescription)"
        }
    }
}

struct DjayCompatibilityLabView: View {
    @StateObject private var lab = DjayCompatibilityLabModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            HStack(spacing: 12) {
                Button(lab.isInspecting ? "INSPECTION…" : "INSPECTER DJAY") {
                    lab.inspect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(lab.isInspecting)

                Button("EXPORTER LE JSON") {
                    lab.exportJSON()
                }
                .buttonStyle(.bordered)
                .disabled(lab.capture == nil)

                Spacer()

                Text(DJBackendValidationStatus.requiresDeviceValidation.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.14), in: Capsule())
            }

            Text(lab.status)
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    captureSummary
                    readinessSummary
                    candidates
                    privacyNotice
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(minWidth: 820, minHeight: 620)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Laboratoire de compatibilité djay")
                .font(.largeTitle.bold())
            Text("Cartographie l’interface réelle et recherche la file Automix sans exécuter de commande.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var captureSummary: some View {
        GroupBox("Capture Accessibilité") {
            if let capture = lab.capture {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    row("Application", capture.applicationName ?? "Non détectée")
                    row("Fenêtre", capture.windowTitle ?? "Non exposée")
                    row("Permission", capture.accessibilityGranted ? "Accordée" : "Action requise")
                    row("Éléments", "\(capture.nodes.count)\(capture.truncated ? " (limite atteinte)" : "")")
                    row("Capture", capture.capturedAt.formatted(date: .abbreviated, time: .standard))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Lance djay, affiche Automix, puis démarre l’inspection.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var readinessSummary: some View {
        GroupBox("Analyse Automix en lecture seule") {
            if let report = lab.readiness {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Gauge(value: Double(report.confidence), in: 0...100) {
                            Text("Confiance")
                        } currentValueLabel: {
                            Text("\(report.confidence) %")
                        }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .frame(maxWidth: 320)

                        Spacer()

                        Text("\(report.automixContainers.count) conteneur(s) • \(report.queueRows.count) ligne(s) • \(report.controls.count) contrôle(s)")
                            .font(.callout.monospacedDigit())
                    }

                    Text(report.summary)
                        .font(.callout)

                    if report.hasReadOnlyAutomixEvidence {
                        Label("Preuves suffisantes pour poursuivre l’observation, pas pour cliquer automatiquement.", systemImage: "checkmark.shield")
                            .foregroundStyle(.green)
                    } else {
                        Label("Aucune automatisation ne sera activée tant que les éléments réels ne sont pas identifiés.", systemImage: "exclamationmark.shield")
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("L’analyse apparaîtra après la première inspection.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var candidates: some View {
        GroupBox("Meilleurs éléments candidats") {
            if let candidates = lab.readiness?.candidates, !candidates.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(candidates.prefix(20))) { candidate in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(candidate.score)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 38, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(candidate.label)
                                    .font(.headline)
                                Text(candidate.kind.rawValue)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(candidate.nodePath)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                Text(candidate.reasons.joined(separator: " • "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        if candidate.id != candidates.prefix(20).last?.id {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Aucun candidat Automix identifié.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var privacyNotice: some View {
        Label(
            "Le JSON reste sur ton Mac, mais peut contenir les titres et artistes visibles dans djay. Ne le publie pas sans le relire.",
            systemImage: "lock.doc"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
#endif
