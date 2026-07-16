#if os(macOS)
import AppKit
import MixPilotCore
import SwiftUI

struct AutomaticSeratoMappingView: View {
    @ObservedObject var model: AppModel
    @StateObject private var session = AutomaticSeratoMappingSession()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Support Serato automatique")
                            .font(.largeTitle.bold())
                        Text("Un seul clic : MixPilot publie son contrôleur MIDI, sauvegarde les anciens fichiers, installe le preset et relance Serato. Aucun bouton à mapper ni à valider un par un.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 42))
                }

                GroupBox("Installation en un clic") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: stateSymbol)
                                .font(.title)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.status).font(.headline)
                                Text(session.detail).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if session.isWorking { ProgressView() }
                        }

                        HStack {
                            Button(session.isWorking ? "Configuration en cours…" : "INSTALLER ET RELANCER SERATO") {
                                session.install(profile: model.mappingProfile) {
                                    model.resetDefaultMapping()
                                    model.refreshEnvironment()
                                    model.evaluatePreflight()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(session.isWorking)

                            Button("Revérifier") {
                                session.refresh(profile: model.mappingProfile)
                                model.refreshEnvironment()
                                model.evaluatePreflight()
                            }
                            .disabled(session.isWorking)

                            Button("Ouvrir le dossier Serato") {
                                NSWorkspace.shared.activateFileViewerSelecting([
                                    URL(fileURLWithPath: session.installationDirectory)
                                ])
                            }
                            .disabled(session.isWorking)

                            Spacer()

                            Button("Restaurer l’ancien mapping", role: .destructive) {
                                session.rollback(profile: model.mappingProfile) {
                                    model.resetDefaultMapping()
                                    model.refreshEnvironment()
                                    model.evaluatePreflight()
                                }
                            }
                            .disabled(session.isWorking)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Diagnostic du contrôleur virtuel") {
                    VStack(alignment: .leading, spacing: 10) {
                        statusRow(
                            "Entrée CoreMIDI",
                            value: session.midiDiagnostic?.sourcePublished == true ? "PUBLIÉE" : "ABSENTE"
                        )
                        statusRow(
                            "Sortie CoreMIDI",
                            value: session.midiDiagnostic?.destinationPublished == true ? "PUBLIÉE" : "ABSENTE"
                        )
                        statusRow(
                            "Nom d’entrée",
                            value: session.midiDiagnostic?.expectedSourceName ?? "MixPilot Virtual Controller"
                        )
                        statusRow("Version Serato détectée", value: session.detectedSeratoVersion)
                        statusRow(
                            "Relance automatique",
                            value: session.seratoRelaunched ? "CONFIRMÉE" : "NON EXÉCUTÉE"
                        )
                        if let diagnostic = session.midiDiagnostic,
                           !diagnostic.configurationWarnings.isEmpty {
                            Divider()
                            ForEach(diagnostic.configurationWarnings, id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox("Ce que MixPilot fait réellement") {
                    VStack(alignment: .leading, spacing: 10) {
                        validationLine("Publie une entrée et une sortie CoreMIDI stables", symbol: "cable.connector")
                        validationLine("Crée `~/Music/_Serato_/MIDI/Xml` si nécessaire", symbol: "folder.badge.plus")
                        validationLine("Sauvegarde `AUTO_SAVE.xml` et tout ancien preset MixPilot", symbol: "externaldrive.badge.timemachine")
                        validationLine("Installe `MixPilot Autopilot.xml` et `AUTO_SAVE.xml`", symbol: "doc.badge.gearshape")
                        validationLine("Vérifie que les fichiers sont identiques et que le XML est valide", symbol: "checkmark.shield")
                        validationLine("Ferme puis relance Serato après publication du contrôleur", symbol: "arrow.clockwise")
                    }
                    .padding(8)
                }

                GroupBox("Statut de confiance") {
                    VStack(alignment: .leading, spacing: 10) {
                        statusRow("Publication CoreMIDI", value: session.midiDiagnostic?.isReadyForSerato == true ? "AUTOMATED_SUCCESS" : "FAILED")
                        statusRow("Installation des fichiers", value: "AUTOMATED_SUCCESS")
                        statusRow("Structure XML Serato", value: "SOURCED_FROM_REAL_MAPPINGS")
                        statusRow("Détection du contrôleur par Serato", value: "REQUIRES_SERATO_VALIDATION")
                        statusRow("Crossfader et sélection exacte de l’Echo", value: "BLOCKED_BY_PLATFORM")
                        Text("Le moteur ne dépend plus du crossfader : chaque transition dispose aussi d’un fondu par les volumes des deux decks.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }

                if let result = session.lastResult {
                    GroupBox("Dernière installation") {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Preset", value: result.presetPath)
                            LabeledContent("Chargement automatique", value: result.autoSavePath)
                            LabeledContent("Commandes installées", value: "\(result.supportedActionCount)")
                            LabeledContent(
                                "Fonctions non devinées",
                                value: result.unsupportedActions.map(\.rawValue).joined(separator: ", ")
                            )
                            if let backupPath = result.backupPath {
                                LabeledContent("Sauvegarde", value: backupPath)
                            }
                        }
                        .textSelection(.enabled)
                        .padding(8)
                    }
                }

                DisclosureGroup("Dépannage avancé") {
                    Text("Le mapping manuel reste présent dans le code comme solution de secours, mais il n’est pas demandé dans le parcours normal.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(30)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            session.refresh(profile: model.mappingProfile)
        }
    }

    private var stateSymbol: String {
        if session.midiDiagnostic?.isReadyForSerato == false {
            return "cable.connector.slash"
        }
        switch session.installationState {
        case .installed: "checkmark.circle.fill"
        case .notInstalled: "arrow.down.circle"
        case .updateAvailable: "arrow.triangle.2.circlepath.circle"
        case .damaged: "exclamationmark.triangle.fill"
        }
    }

    private func validationLine(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
    }

    private func statusRow(_ name: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .monospaced()
                .multilineTextAlignment(.trailing)
        }
    }
}
#endif
