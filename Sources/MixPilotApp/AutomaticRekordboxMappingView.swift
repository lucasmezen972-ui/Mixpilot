#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotSystem
import SwiftUI
import UniformTypeIdentifiers

struct AutomaticRekordboxMappingView: View {
    @ObservedObject var model: AppModel
    @State private var preset: RekordboxAdvancedMIDIPreset?
    @State private var status = "Aucun preset généré"
    @State private var exportedURL: URL?

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MixPilotSectionHero(
                        eyebrow: "MIDI Learn",
                        title: "Mapping rekordbox avancé",
                        subtitle: "Génère un preset versionné, vérifie sa structure puis accompagne son import dans rekordbox sans toucher au paquet signé de l’application.",
                        symbol: "slider.horizontal.3",
                        accent: .blue
                    ) {
                        MixPilotStatusBadge(
                            title: preset == nil ? "Validation requise" : "Preset vérifié",
                            symbol: preset == nil ? "exclamationmark.shield.fill" : "checkmark.seal.fill",
                            accent: preset == nil ? .orange : .green
                        )
                    }

                    MixPilotGlassCard(accent: preset == nil ? .blue : .green, elevation: .elevated) {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack(alignment: .center, spacing: 15) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill((preset == nil ? Color.blue : Color.green).opacity(0.13))
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .strokeBorder((preset == nil ? Color.blue : Color.green).opacity(0.22), lineWidth: 1)
                                    Image(systemName: preset == nil ? "arrow.down.doc.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 29, weight: .semibold))
                                        .foregroundStyle(preset == nil ? .blue : .green)
                                }
                                .frame(width: 66, height: 66)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(status)
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .tracking(-0.2)
                                    Text("Écriture atomique, relecture après export et validation du CSV avant toute utilisation réelle.")
                                        .font(.callout)
                                        .foregroundStyle(MixPilotPalette.textSecondary)
                                        .lineSpacing(2)
                                }
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                Button("GÉNÉRER LE PRESET AVANCÉ") { exportPreset() }
                                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .blue))

                                if let exportedURL {
                                    Button("AFFICHER DANS LE FINDER") {
                                        NSWorkspace.shared.activateFileViewerSelecting([exportedURL])
                                    }
                                    .buttonStyle(MixPilotSecondaryButtonStyle())
                                }

                                Button("AFFICHER REKORDBOX") {
                                    _ = NSWorkspace.shared.runningApplications
                                        .first(where: {
                                            RekordboxApplicationMatcher.matches(
                                                name: $0.localizedName,
                                                bundleIdentifier: $0.bundleIdentifier
                                            )
                                        })?
                                        .activate(options: [.activateAllWindows])
                                }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                            }
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 16)], spacing: 16) {
                        MixPilotGlassCard(accent: .cyan) {
                            VStack(alignment: .leading, spacing: 13) {
                                MixPilotPanelTitle(
                                    title: "Validation du compilateur",
                                    symbol: "checkmark.shield.fill",
                                    subtitle: "Le fichier est refusé à la moindre incohérence.",
                                    accent: .cyan
                                )
                                MixPilotSectionDivider(accent: .cyan)
                                validationLine("En-tête @file et nom du contrôleur")
                                validationLine("15 colonnes par commande")
                                validationLine("MIDI IN global, Deck 1 ou Deck 2")
                                validationLine("Codes Note On et Control Change valides")
                                validationLine("Aucun message MIDI dupliqué")
                                validationLine("Commandes issues des catalogues étudiés")
                                validationLine("Focus et Color FX canaux 1/2")
                                validationLine("Aucun jog ou message 14 bits inventé")
                            }
                        }

                        MixPilotGlassCard(accent: .purple) {
                            VStack(alignment: .leading, spacing: 13) {
                                MixPilotPanelTitle(
                                    title: "Import dans rekordbox",
                                    symbol: "square.and.arrow.down.fill",
                                    subtitle: "Parcours officiel MIDI IMPORT",
                                    accent: .purple
                                )
                                MixPilotSectionDivider(accent: .purple)
                                step(1, "Lance MixPilot pour publier le port virtuel.")
                                step(2, "Passe rekordbox en mode PERFORMANCE.")
                                step(3, "Ouvre MIDI et sélectionne MixPilot Virtual Controller.")
                                step(4, "Clique sur IMPORT et choisis le fichier Advanced.midi.csv.")
                                step(5, "Sélectionne Filter dans Color FX.")
                                step(6, "Teste les commandes sur une playlist de copie.")
                            }
                        }
                    }

                    if let preset {
                        MixPilotGlassCard(accent: .green, elevation: .elevated) {
                            VStack(alignment: .leading, spacing: 15) {
                                MixPilotPanelTitle(
                                    title: "Couverture du dernier preset",
                                    symbol: "chart.bar.fill",
                                    subtitle: preset.base.controllerName,
                                    accent: .green
                                )
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: 10)], spacing: 10) {
                                    coverageTile("\(preset.base.supportedActions.count)", "Commandes principales", "dial.medium.fill")
                                    coverageTile("\(preset.addedActions.count)", "Commandes avancées", "plus.circle.fill")
                                    coverageTile(preset.base.observedCommandCatalogueVersions.joined(separator: ", "), "Catalogues", "books.vertical.fill")
                                    coverageTile("7 bits", "Résolution validée", "waveform.path.ecg")
                                }
                                MixPilotNotice(
                                    title: "Commandes avancées intégrées",
                                    message: preset.addedActions.map(\.rawValue).joined(separator: ", "),
                                    kind: .success
                                )
                                ForEach(preset.warnings, id: \.self) { warning in
                                    MixPilotNotice(title: "Avertissement", message: warning, kind: .warning)
                                }
                            }
                        }
                    }

                    MixPilotNotice(
                        title: "Limite assumée : Echo reste manuel",
                        message: "Les catalogues exposent des emplacements FX génériques sans garantir qu’un message sélectionne précisément Echo sur toutes les versions. MixPilot refuse donc une commande ambiguë.",
                        kind: .warning
                    )
                }
                .padding(28)
                .frame(maxWidth: 1_060, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .mixPilotWindowSurface(minWidth: 960, minHeight: 740)
    }

    private func exportPreset() {
        do {
            let generated = try RekordboxAdvancedMIDIPresetGenerator().generate(profile: model.mappingProfile)
            let panel = NSSavePanel()
            panel.title = "Exporter le mapping MIDI rekordbox avancé"
            panel.nameFieldStringValue = "MixPilot Virtual Controller Advanced.midi.csv"
            panel.allowedContentTypes = [.commaSeparatedText]
            guard panel.runModal() == .OK, let url = panel.url else {
                status = "Export annulé"
                return
            }

            let data = Data(generated.csv.utf8)
            try data.write(to: url, options: .atomic)
            guard try Data(contentsOf: url) == data else {
                throw RekordboxMappingExportError.verificationFailed
            }

            preset = generated
            exportedURL = url
            status = "Preset avancé validé et exporté : \(url.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            preset = nil
            exportedURL = nil
            status = "Échec de génération : \(error.localizedDescription)"
        }
    }

    private func validationLine(_ text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.callout)
                .foregroundStyle(MixPilotPalette.textSecondary)
            Spacer()
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(format: "%02d", number))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .frame(width: 28, height: 28)
                .background(.purple.opacity(0.13), in: Circle())
                .overlay { Circle().strokeBorder(.purple.opacity(0.20), lineWidth: 1) }
                .foregroundStyle(.purple)
            Text(text)
                .font(.callout)
                .foregroundStyle(MixPilotPalette.textSecondary)
                .padding(.top, 4)
            Spacer()
        }
    }

    private func coverageTile(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.green.opacity(0.11))
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .frame(width: 30, height: 30)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(2)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.65)
                .foregroundStyle(MixPilotPalette.textTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(.white.opacity(0.040), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.075), lineWidth: 1)
        }
    }
}

private enum RekordboxMappingExportError: Error, LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        "Le fichier écrit ne correspond pas au preset validé."
    }
}
#endif