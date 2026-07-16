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
                        Text("Mapping Serato automatique")
                            .font(.largeTitle.bold())
                        Text("MixPilot ferme Serato, sauvegarde les anciens fichiers, installe son preset puis relance Serato. Aucun bouton à mapper ni à valider un par un.")
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
                            Button(session.isWorking ? "Installation en cours…" : "INSTALLER AUTOMATIQUEMENT") {
                                session.install(profile: model.mappingProfile) {
                                    model.resetDefaultMapping()
                                    model.refreshEnvironment()
                                    model.evaluatePreflight()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(session.isWorking)

                            Button("Vérifier") {
                                session.refresh(profile: model.mappingProfile)
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

                GroupBox("Ce que MixPilot fait réellement") {
                    VStack(alignment: .leading, spacing: 10) {
                        validationLine("Crée `~/Music/_Serato_/MIDI/Xml` si nécessaire", symbol: "folder.badge.plus")
                        validationLine("Sauvegarde `AUTO_SAVE.xml` et tout ancien preset MixPilot", symbol: "externaldrive.badge.timemachine")
                        validationLine("Installe `MixPilot Autopilot.xml` et `AUTO_SAVE.xml`", symbol: "doc.badge.gearshape")
                        validationLine("Vérifie que les deux fichiers sont identiques et que le XML est valide", symbol: "checkmark.shield")
                        validationLine("Relance Serato automatiquement", symbol: "arrow.clockwise")
                    }
                    .padding(8)
                }

                GroupBox("Statut de confiance") {
                    VStack(alignment: .leading, spacing: 10) {
                        statusRow("Installation des fichiers", value: "AUTOMATED_SUCCESS")
                        statusRow("Structure XML Serato", value: "SOURCED_FROM_REAL_MAPPINGS")
                        statusRow("Réaction réelle dans Serato", value: "REQUIRES_SERATO_VALIDATION")
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

                DisclosureGroup("Mapping manuel de secours") {
                    Text("L’ancien assistant reste disponible dans la rubrique Mapping MIDI, mais il n’est plus nécessaire pour installer le preset automatique.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                    Button("Ouvrir l’assistant manuel") {
                        model.selectedSection = .mapping
                    }
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
        HStack {
            Text(name)
            Spacer()
            Text(value).font(.caption.bold()).monospaced()
        }
    }
}
#endif
