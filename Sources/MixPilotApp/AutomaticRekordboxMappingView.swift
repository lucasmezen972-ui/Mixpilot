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
            LinearGradient(
                colors: [Color.black, Color.purple.opacity(0.18), Color.blue.opacity(0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("MAPPING REKORDBOX")
                                .font(.caption2.bold())
                                .tracking(2)
                                .foregroundStyle(.cyan)
                            Text("Preset automatique avancé")
                                .font(.largeTitle.bold())
                            Text("Génère un .midi.csv pour MixPilot Virtual Controller avec les commandes principales, le focus de fenêtre et les paramètres Color FX des deux canaux.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("REQUIRES_DEVICE_VALIDATION")
                            .font(.caption.bold())
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .foregroundStyle(.orange)
                            .background(.orange.opacity(0.13), in: Capsule())
                    }

                    card("Génération sécurisée", symbol: "wand.and.stars") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: preset == nil ? "arrow.down.doc" : "checkmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(preset == nil ? .cyan : .green)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(status).font(.headline)
                                    Text("Le fichier est écrit atomiquement, relu après export et n’est jamais copié dans le paquet signé de rekordbox.")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            HStack {
                                Button("GÉNÉRER LE PRESET AVANCÉ") { exportPreset() }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)

                                if let exportedURL {
                                    Button("Afficher dans le Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([exportedURL])
                                    }
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
                            }
                        }
                    }

                    card("Ce que le compilateur vérifie", symbol: "checkmark.shield.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            validationLine("En-tête @file associé à MixPilot Virtual Controller")
                            validationLine("15 colonnes par commande, comme les exports rekordbox observés")
                            validationLine("MIDI IN global, Deck 1 ou Deck 2 selon la fonction")
                            validationLine("Codes Note On 9nxx et Control Change Bnxx sur 4 chiffres hexadécimaux")
                            validationLine("Aucun code MIDI réutilisé pour deux fonctions")
                            validationLine("Commandes issues des catalogues 6.6.3 et 6.7.4 étudiés")
                            validationLine("Focus de fenêtre via SwitchActiveWindow")
                            validationLine("Color FX via CFXParameterCH1 et CFXParameterCH2")
                            validationLine("Pas de jog wheel ni de 14 bits inventés")
                        }
                    }

                    card("Import dans rekordbox", symbol: "square.and.arrow.down") {
                        VStack(alignment: .leading, spacing: 10) {
                            step(1, "Lance MixPilot pour publier le port « MixPilot Virtual Controller ».")
                            step(2, "Dans rekordbox, passe en mode PERFORMANCE puis ouvre la fenêtre MIDI.")
                            step(3, "Sélectionne « MixPilot Virtual Controller » dans la liste des appareils.")
                            step(4, "Clique sur IMPORT et choisis le fichier Advanced.midi.csv.")
                            step(5, "Dans Color FX, sélectionne Filter avant de tester les deux paramètres CFX.")
                            step(6, "Teste Load, PlayPause, Cue, Sync, navigation, faders, EQ, filtres et boucles sur une playlist de copie.")
                        }
                    }

                    if let preset {
                        card("Couverture du dernier preset", symbol: "chart.bar.fill") {
                            VStack(alignment: .leading, spacing: 10) {
                                LabeledContent("Contrôleur", value: preset.base.controllerName)
                                LabeledContent("Commandes principales", value: "\(preset.base.supportedActions.count)")
                                LabeledContent("Commandes avancées", value: "\(preset.addedActions.count)")
                                LabeledContent(
                                    "Catalogues observés",
                                    value: preset.base.observedCommandCatalogueVersions.joined(separator: ", ")
                                )

                                Text("Avancées : \(preset.addedActions.map(\.rawValue).joined(separator: ", "))")
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)

                                ForEach(preset.warnings, id: \.self) { warning in
                                    Label(warning, systemImage: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    card("Limite assumée", symbol: "waveform.badge.exclamationmark") {
                        Text("L’Echo reste manuel. Les catalogues exposent des slots FX génériques, mais ne garantissent pas qu’un message sélectionne précisément Echo sur toutes les versions. MixPilot refuse donc de fabriquer une commande ambiguë.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(30)
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 920, minHeight: 700)
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

    private func card<Content: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol).font(.title3.bold())
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.09)))
    }

    private func validationLine(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.shield")
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .background(.cyan.opacity(0.14), in: Circle())
                .foregroundStyle(.cyan)
            Text(text)
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
