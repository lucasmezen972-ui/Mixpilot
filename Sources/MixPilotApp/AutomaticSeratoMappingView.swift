#if os(macOS)
import AppKit
import MixPilotCore
import SwiftUI

struct AutomaticSeratoMappingView: View {
    @ObservedObject var model: AppModel
    @StateObject private var session = AutomaticSeratoMappingSession()

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MixPilotSectionHero(
                        eyebrow: "Installation guidée",
                        title: "Mapping Serato automatique",
                        subtitle: "Sauvegarde, installation du preset, vérification et relance de Serato en un seul parcours.",
                        symbol: "wand.and.stars",
                        accent: stateColor
                    ) {
                        MixPilotStatusBadge(
                            title: trustLabel,
                            symbol: stateSymbol,
                            accent: stateColor
                        )
                    }

                    MixPilotGlassCard(accent: stateColor) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15).fill(stateColor.opacity(0.14))
                                    Image(systemName: stateSymbol)
                                        .font(.system(size: 27, weight: .semibold))
                                        .foregroundStyle(stateColor)
                                }
                                .frame(width: 58, height: 58)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(session.status)
                                        .font(.system(size: 21, weight: .bold, design: .rounded))
                                    Text(session.detail)
                                        .font(.callout)
                                        .foregroundStyle(.white.opacity(0.52))
                                }
                                Spacer()
                                if session.isWorking { ProgressView().controlSize(.large).tint(stateColor) }
                            }

                            HStack(spacing: 10) {
                                Button(session.isWorking ? "INSTALLATION EN COURS…" : "INSTALLER AUTOMATIQUEMENT") {
                                    session.install(profile: model.mappingProfile) {
                                        model.resetDefaultMapping()
                                        model.refreshEnvironment()
                                        model.evaluatePreflight()
                                    }
                                }
                                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                                .disabled(session.isWorking)

                                Button("Vérifier") {
                                    session.refresh(profile: model.mappingProfile)
                                    model.evaluatePreflight()
                                }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                                .disabled(session.isWorking)

                                Button("Ouvrir le dossier Serato") {
                                    NSWorkspace.shared.activateFileViewerSelecting([
                                        URL(fileURLWithPath: session.installationDirectory)
                                    ])
                                }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                                .disabled(session.isWorking)

                                Spacer()

                                Button("Restaurer l’ancien mapping") {
                                    session.rollback(profile: model.mappingProfile) {
                                        model.resetDefaultMapping()
                                        model.refreshEnvironment()
                                        model.evaluatePreflight()
                                    }
                                }
                                .buttonStyle(MixPilotDangerButtonStyle())
                                .disabled(session.isWorking)
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 16) {
                        MixPilotGlassCard(accent: .cyan) {
                            VStack(alignment: .leading, spacing: 13) {
                                MixPilotPanelTitle(title: "Ce que MixPilot fait", symbol: "gearshape.2.fill", subtitle: "Chaque étape est vérifiée.", accent: .cyan)
                                installationStep("Crée le dossier MIDI XML si nécessaire", "folder.badge.plus")
                                installationStep("Sauvegarde AUTO_SAVE.xml et les anciens presets", "externaldrive.badge.timemachine")
                                installationStep("Installe le preset MixPilot et son chargement automatique", "doc.badge.gearshape")
                                installationStep("Compare les fichiers et valide la structure XML", "checkmark.shield.fill")
                                installationStep("Relance Serato automatiquement", "arrow.clockwise")
                            }
                        }

                        MixPilotGlassCard(accent: .orange) {
                            VStack(alignment: .leading, spacing: 13) {
                                MixPilotPanelTitle(title: "Niveau de confiance", symbol: "checkmark.shield.fill", subtitle: "Automatique ≠ testé sur chaque Mac.", accent: .orange)
                                confidenceRow("Installation des fichiers", "AUTOMATED_SUCCESS", .green)
                                confidenceRow("Structure XML", "REAL_MAPPING_SOURCES", .green)
                                confidenceRow("Réaction Serato", "DEVICE_VALIDATION", .orange)
                                confidenceRow("Crossfader / Echo exact", "PLATFORM_LIMIT", .red)
                                Text("Le moteur utilise aussi les volumes des decks afin de ne pas dépendre uniquement du crossfader.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.48))
                            }
                        }
                    }

                    if let result = session.lastResult {
                        MixPilotGlassCard(accent: .green) {
                            VStack(alignment: .leading, spacing: 13) {
                                MixPilotPanelTitle(title: "Dernière installation", symbol: "checkmark.seal.fill", subtitle: "Fichiers écrits et vérifiés.", accent: .green)
                                resultRow("Preset", result.presetPath)
                                resultRow("Chargement automatique", result.autoSavePath)
                                resultRow("Commandes installées", "\(result.supportedActionCount)")
                                resultRow("Fonctions non devinées", result.unsupportedActions.map(\.rawValue).joined(separator: ", "))
                                if let backupPath = result.backupPath { resultRow("Sauvegarde", backupPath) }
                            }
                            .textSelection(.enabled)
                        }
                    }

                    MixPilotGlassCard(accent: .blue) {
                        HStack {
                            MixPilotPanelTitle(title: "Mapping manuel de secours", symbol: "slider.horizontal.3", subtitle: "Disponible dans l’espace Mapping MIDI.", accent: .blue)
                            Spacer()
                            Button("OUVRIR L’ASSISTANT MANUEL") { model.selectedSection = .mapping }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 1_020, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 940, minHeight: 700)
        .onAppear { session.refresh(profile: model.mappingProfile) }
    }

    private var stateSymbol: String {
        switch session.installationState {
        case .installed: "checkmark.circle.fill"
        case .notInstalled: "arrow.down.circle.fill"
        case .updateAvailable: "arrow.triangle.2.circlepath.circle.fill"
        case .damaged: "exclamationmark.triangle.fill"
        }
    }

    private var stateColor: Color {
        switch session.installationState {
        case .installed: .green
        case .notInstalled: .purple
        case .updateAvailable: .cyan
        case .damaged: .red
        }
    }

    private var trustLabel: String {
        switch session.installationState {
        case .installed: "Preset installé"
        case .notInstalled: "À installer"
        case .updateAvailable: "Mise à jour disponible"
        case .damaged: "À réparer"
        }
    }

    private func installationStep(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(.white.opacity(0.64))
    }

    private func confidenceRow(_ name: String, _ value: String, _ accent: Color) -> some View {
        HStack {
            Circle().fill(accent).frame(width: 7, height: 7)
            Text(name).font(.callout)
            Spacer()
            Text(value)
                .font(.caption2.bold().monospaced())
                .foregroundStyle(accent)
        }
        .padding(.vertical, 2)
    }

    private func resultRow(_ name: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(name).foregroundStyle(.white.opacity(0.48)).frame(width: 180, alignment: .leading)
            Text(value).font(.caption.monospaced()).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }
}
#endif
