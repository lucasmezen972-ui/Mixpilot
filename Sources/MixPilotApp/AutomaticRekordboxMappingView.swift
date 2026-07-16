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
                        subtitle: "Génère un preset versionné, validé et importable pour MixPilot Virtual Controller.",
                        symbol: "slider.horizontal.3",
                        accent: .blue
                    ) {
                        MixPilotStatusBadge(
                            title: "Device validation",
                            symbol: "exclamationmark.shield.fill",
                            accent: .orange
                        )
                    }

                    MixPilotGlassCard(accent: preset == nil ? .blue : .green) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill((preset == nil ? Color.blue : Color.green).opacity(0.14))
                                    Image(systemName: preset == nil ? "arrow.down.doc.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 27, weight: .semibold))
                                        .foregroundStyle(preset == nil ? .blue : .green)
                                }
                                .frame(width: 58, height: 58)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(status)
                                        .font(.system(size: 21, weight: .bold, design: .rounded))
                                    Text("Écriture atomique, relecture après export et aucune modification du paquet signé de rekordbox.")
                                        .font(.callout)
                                        .foregroundStyle(.white.opacity(0.52))
                                }
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                Button("GÉNÉRER LE PRESET AVANCÉ") { exportPreset() }
                                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .blue))

                                if let exportedURL {
                                    Button("Afficher dans le Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([exportedURL])
                                    }
                                    .buttonStyle(MixPilotSecondaryButtonStyle())
                                }

                                Button("Afficher rekordbox") {
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

                    HStack(alignment: .top, spacing: 16) {
                        MixPilotGlassCard(accent: .cyan) {
                            VStack(alignment: .leading, spacing: 12) {
                                MixPilotPanelTitle(title: "Validation du compilateur", symbol: "checkmark.shield.fill", subtitle: "Le fichier est refusé à la moindre incohérence.", accent: .cyan)
                                validationLine("En-tête @file et nom du contrôleur")
                                validationLine("15 colonnes par commande")
                                validationLine("MIDI IN global, Deck 1 ou Deck 2")
                                validationLine("Codes Note On et Control Change valides")
                                validationLine("Aucun message MIDI dupliqué")
                                validationLine("Commandes des catalogues étudiés uniquement")
                                validationLine("Focus et Color FX canaux 1/2")
                                validationLine("Aucun jog ou 14 bits inventé")
                            }
                        }

                        MixPilotGlassCard(accent: .purple) {
                            VStack(alignment: .leading, spacing: 12) {
                                MixPilotPanelTitle(title: "Import dans rekordbox", symbol: "square.and.arrow.down.fill", subtitle: "Parcours officiel MIDI IMPORT.", accent: .purple)
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
                        MixPilotGlassCard(accent: .green) {
                            VStack(alignment: .leading, spacing: 14) {
                                MixPilotPanelTitle(title: "Couverture du dernier preset", symbol: "chart.bar.fill", subtitle: preset.base.controllerName, accent: .green)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                                    coverageTile("\(preset.base.supportedActions.count)", "Commandes principales", "dial.medium.fill")
                                    coverageTile("\(preset.addedActions.count)", "Commandes avancées", "plus.circle.fill")
                                    coverageTile(preset.base.observedCommandCatalogueVersions.joined(separator: ", "), "Catalogues", "books.vertical.fill")
                                    coverageTile("7 bits", "Résolution validée", "waveform.path.ecg")
                                }
                                Text("Avancées : \(preset.addedActions.map(\.rawValue).joined(separator: ", "))")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.white.opacity(0.5))
                                    .textSelection(.enabled)
                                ForEach(preset.warnings, id: \.self) { warning in
                                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }

                    MixPilotGlassCard(accent: .orange) {
                        VStack(alignment: .leading, spacing: 10) {
                            MixPilotPanelTitle(title: "Limite assumée", symbol: "waveform.badge.exclamationmark", subtitle: "L’Echo reste manuel.", accent: .orange)
                            Text("Les catalogues exposent des emplacements FX génériques sans garantir qu’un message sélectionne précisément Echo sur toutes les versions. MixPilot refuse donc une commande ambiguë.")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.56))
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 1_020, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 940, minHeight: 720)
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
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.callout)
            .foregroundStyle(.white.opacity(0.64))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 25, height: 25)
                .background(.purple.opacity(0.16), in: Circle())
                .foregroundStyle(.purple)
            Text(text)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    private func coverageTile(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(.green)
            Text(value).font(.title3.bold().monospacedDigit()).lineLimit(2)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }
}

private enum RekordboxMappingExportError: Error, LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        "Le fichier écrit ne correspond pas au preset validé."
    }
}
#endif
