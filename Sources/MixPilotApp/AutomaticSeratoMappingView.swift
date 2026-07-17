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
                        subtitle: "Sauvegarde l’existant, installe le preset MixPilot, vérifie les fichiers et prépare la relance de Serato dans un parcours réversible.",
                        symbol: "wand.and.stars",
                        accent: stateColor
                    ) {
                        MixPilotStatusBadge(
                            title: trustLabel,
                            symbol: stateSymbol,
                            accent: stateColor
                        )
                    }

                    MixPilotGlassCard(accent: stateColor, elevation: .elevated) {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack(alignment: .center, spacing: 15) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(stateColor.opacity(0.13))
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .strokeBorder(stateColor.opacity(0.24), lineWidth: 1)
                                    Image(systemName: stateSymbol)
                                        .font(.system(size: 29, weight: .semibold))
                                        .foregroundStyle(stateColor)
                                }
                                .frame(width: 66, height: 66)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(session.status)
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .tracking(-0.2)
                                    Text(session.detail)
                                        .font(.callout)
                                        .foregroundStyle(MixPilotPalette.textSecondary)
                                        .lineSpacing(2)
                                }
                                Spacer()
                                if session.isWorking {
                                    ProgressView()
                                        .controlSize(.large)
                                        .tint(stateColor)
                                }
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

                                Button("VÉRIFIER") {
                                    session.refresh(profile: model.mappingProfile)
                                    model.evaluatePreflight()
                                }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                                .disabled(session.isWorking)

                                Button("OUVRIR LE DOSSIER") {
                                    NSWorkspace.shared.activateFileViewerSelecting([
                                        URL(fileURLWithPath: session.installationDirectory)
                                    ])
                                }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                                .disabled(session.isWorking)

                                Spacer()

                                Button("RESTAURER L’ANCIEN MAPPING") {
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

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 16)], spacing: 16) {
                        MixPilotGlassCard(accent: .cyan) {
                            VStack(alignment: .leading, spacing: 13) {
                                MixPilotPanelTitle(
                                    title: "Ce que MixPilot fait",
                                    symbol: "gearshape.2.fill",
                                    subtitle: "Chaque étape est contrôlée et réversible.",
                                    accent: .cyan
                                )
                                MixPilotSectionDivider(accent: .cyan)
                                installationStep("Crée le dossier MIDI XML si nécessaire", "folder.badge.plus")
                                installationStep("Sauvegarde AUTO_SAVE.xml et les anciens presets", "externaldrive.badge.timemachine")
                                installationStep("Installe le preset MixPilot et son chargement automatique", "doc.badge.gearshape")
                                installationStep("Compare les fichiers et valide la structure XML", "checkmark.shield.fill")
                                installationStep("Prépare la relance de Serato", "arrow.clockwise")
                            }
                        }

                        MixPilotGlassCard(accent: .orange) {
                            VStack(alignment: .leading, spacing: 13) {
                                MixPilotPanelTitle(
                                    title: "Niveau de confiance",
                                    symbol: "checkmark.shield.fill",
                                    subtitle: "Automatique ne signifie pas validé sur chaque Mac.",
                                    accent: .orange
                                )
                                MixPilotSectionDivider(accent: .orange)
                                confidenceRow("Installation des fichiers", "AUTOMATED_SUCCESS", .green)
                                confidenceRow("Structure XML", "REAL_MAPPING_SOURCES", .green)
                                confidenceRow("Réaction Serato", "DEVICE_VALIDATION", .orange)
                                confidenceRow("Crossfader / Echo exact", "PLATFORM_LIMIT", .red)
                                MixPilotNotice(
                                    title: "Stratégie conservatrice",
                                    message: "Le moteur utilise aussi les volumes des decks afin de ne pas dépendre uniquement du crossfader.",
                                    kind: .warning
                                )
                            }
                        }
                    }

                    if let result = session.lastResult {
                        MixPilotGlassCard(accent: .green, elevation: .elevated) {
                            VStack(alignment: .leading, spacing: 14) {
                                MixPilotPanelTitle(
                                    title: "Dernière installation",
                                    symbol: "checkmark.seal.fill",
                                    subtitle: "Fichiers écrits, relus et vérifiés",
                                    accent: .green
                                )
                                MixPilotSectionDivider(accent: .green)
                                resultRow("Preset", result.presetPath)
                                resultRow("Chargement automatique", result.autoSavePath)
                                resultRow("Commandes installées", "\(result.supportedActionCount)")
                                resultRow("Fonctions non devinées", result.unsupportedActions.map(\.rawValue).joined(separator: ", "))
                                if let backupPath = result.backupPath {
                                    resultRow("Sauvegarde", backupPath)
                                }
                            }
                            .textSelection(.enabled)
                        }
                    }

                    MixPilotGlassCard(accent: .blue) {
                        HStack(spacing: 14) {
                            MixPilotPanelTitle(
                                title: "Mapping manuel de secours",
                                symbol: "slider.horizontal.3",
                                subtitle: "Disponible dans l’espace Mapping MIDI pour confirmer commande par commande.",
                                accent: .blue
                            )
                            Spacer()
                            Button("OUVRIR L’ASSISTANT MANUEL") {
                                model.selectedSection = .mapping
                            }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 1_060, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .mixPilotWindowSurface(minWidth: 960, minHeight: 720)
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
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.cyan.opacity(0.10))
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 28, height: 28)
            Text(text)
                .font(.callout)
                .foregroundStyle(MixPilotPalette.textSecondary)
            Spacer()
        }
    }

    private func confidenceRow(_ name: String, _ value: String, _ accent: Color) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)
                .shadow(color: accent.opacity(0.45), radius: 4)
            Text(name)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.caption2.bold().monospaced())
                .foregroundStyle(accent)
        }
        .padding(.vertical, 3)
    }

    private func resultRow(_ name: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(name)
                .font(.callout)
                .foregroundStyle(MixPilotPalette.textTertiary)
                .frame(width: 180, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}
#endif