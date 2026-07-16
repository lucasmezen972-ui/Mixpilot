#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotSystem
import SwiftUI
import UniformTypeIdentifiers

struct AutomaticRekordboxMappingView: View {
    @ObservedObject var model: AppModel
    @State private var preset: RekordboxMIDIPreset?
    @State private var status = "Aucun preset généré"
    @State private var exportedURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mapping rekordbox automatique")
                            .font(.largeTitle.bold())
                        Text("Génère un fichier .midi.csv pour le contrôleur virtuel MixPilot à importer avec la fonction officielle MIDI IMPORT de rekordbox.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("REQUIRES_DEVICE_VALIDATION")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.16), in: Capsule())
                }

                GroupBox("Génération sécurisée") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: preset == nil ? "arrow.down.doc" : "checkmark.circle.fill")
                                .font(.title)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(status).font(.headline)
                                Text("Le fichier n’est jamais copié dans le paquet signé de rekordbox et aucune base musicale n’est modifiée.")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        HStack {
                            Button("GÉNÉRER LE PRESET REKORDBOX") {
                                exportPreset()
                            }
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
                    .padding(8)
                }

                GroupBox("Ce que le compilateur vérifie") {
                    VStack(alignment: .leading, spacing: 10) {
                        validationLine("En-tête @file associé à MixPilot Virtual Controller")
                        validationLine("15 colonnes par commande, comme les exports rekordbox observés")
                        validationLine("MIDI IN sur la colonne globale, Deck 1 ou Deck 2 selon l’action")
                        validationLine("Codes Note On 9nxx et Control Change Bnxx sur 4 chiffres hexadécimaux")
                        validationLine("Aucun code MIDI réutilisé pour deux fonctions")
                        validationLine("Aucune commande absente des catalogues rekordbox 6.6.3 et 6.7.4")
                        validationLine("Pas de jog wheel ni de 14 bits inventés")
                    }
                    .padding(8)
                }

                GroupBox("Import dans rekordbox") {
                    VStack(alignment: .leading, spacing: 10) {
                        step(1, "Lance MixPilot pour publier le port « MixPilot Virtual Controller ».")
                        step(2, "Dans rekordbox, passe en mode PERFORMANCE puis ouvre la fenêtre MIDI.")
                        step(3, "Sélectionne « MixPilot Virtual Controller » dans la liste des appareils.")
                        step(4, "Clique sur IMPORT et choisis le fichier MixPilot Virtual Controller.midi.csv.")
                        step(5, "Confirme que l’import écrase uniquement le mapping de ce contrôleur virtuel.")
                        step(6, "Teste Load, PlayPause, Sync, navigation, volumes et EQ sur une playlist de copie.")
                    }
                    .padding(8)
                }

                if let preset {
                    GroupBox("Couverture du dernier preset") {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledContent("Contrôleur", value: preset.controllerName)
                            LabeledContent("Commandes générées", value: "\(preset.supportedActions.count)")
                            LabeledContent("Commandes exclues", value: "\(preset.unsupportedActions.count)")
                            LabeledContent(
                                "Catalogues observés",
                                value: preset.observedCommandCatalogueVersions.joined(separator: ", ")
                            )

                            if !preset.unsupportedActions.isEmpty {
                                Text("Non générées : \(preset.unsupportedActions.map(\.rawValue).joined(separator: ", "))")
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }

                            ForEach(preset.warnings, id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                    }
                }

                GroupBox("Pourquoi certains contrôles restent manuels") {
                    Text("Les catalogues fournis confirment PlayPause, Cue, Sync, Load, BrowseUp/Down, ChannelFader, CrossFader, EQ, TempoSlider, BeatLoop4 et ReloopExit. Ils ne prouvent pas un nom stable pour le focus navigateur, le filtre ou l’Echo. MixPilot les exclut donc au lieu de fabriquer une commande qui pourrait agir au mauvais endroit.")
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .padding(30)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .frame(minWidth: 920, minHeight: 700)
    }

    private func exportPreset() {
        do {
            let generated = try RekordboxMIDIPresetGenerator().generate(profile: model.mappingProfile)
            let panel = NSSavePanel()
            panel.title = "Exporter le mapping MIDI rekordbox"
            panel.nameFieldStringValue = "MixPilot Virtual Controller.midi.csv"
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
            try RekordboxMIDIPresetValidator().validate(csv: String(decoding: data, as: UTF8.self))

            preset = generated
            exportedURL = url
            status = "Preset validé et exporté : \(url.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            preset = nil
            exportedURL = nil
            status = "Échec de génération : \(error.localizedDescription)"
        }
    }

    private func validationLine(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.shield")
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(.secondary.opacity(0.14), in: Circle())
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
