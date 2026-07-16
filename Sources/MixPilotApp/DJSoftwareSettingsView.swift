#if os(macOS)
import MixPilotCore
import SwiftUI

struct DJSoftwareSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selection = DJSoftwareSelectionStore.current

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            VStack(alignment: .leading, spacing: 22) {
                MixPilotSectionHero(
                    eyebrow: "Backend audio",
                    title: "Choisir le logiciel DJ",
                    subtitle: "Le moteur MixPilot reste identique ; seul le chemin de contrôle et d’observation change.",
                    symbol: "music.note.house.fill",
                    accent: accent
                ) { EmptyView() }

                HStack(spacing: 12) {
                    ForEach(DJSoftware.allCases) { software in
                        softwareCard(software)
                    }
                }

                MixPilotGlassCard(accent: accent) {
                    VStack(alignment: .leading, spacing: 13) {
                        MixPilotPanelTitle(
                            title: modeTitle,
                            symbol: softwareSymbol,
                            subtitle: modeDescription,
                            accent: accent
                        )
                        Text(validationDescription)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.56))
                        HStack {
                            MixPilotStatusBadge(
                                title: selection == .serato ? "MIDI direct" : selection == .rekordbox ? "MIDI + bibliothèque" : "Automix observé",
                                symbol: "checkmark.shield.fill",
                                accent: accent
                            )
                            Spacer()
                            Button("OUVRIR LE STUDIO") {
                                model.selectedSection = .studio
                            }
                            .buttonStyle(MixPilotPrimaryButtonStyle(accent: accent))
                        }
                    }
                }

                Text("Le changement est appliqué immédiatement au diagnostic et au Préflight.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))
            }
            .padding(28)
            .frame(maxWidth: 760)
        }
        .preferredColorScheme(.dark)
        .frame(width: 720, height: 470)
    }

    private func softwareCard(_ software: DJSoftware) -> some View {
        Button {
            selection = software
            DJSoftwareSelectionStore.current = software
            model.refreshEnvironment()
            model.evaluatePreflight()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(color(for: software).opacity(0.14))
                        Image(systemName: symbol(for: software))
                            .font(.title2)
                            .foregroundStyle(color(for: software))
                    }
                    .frame(width: 45, height: 45)
                    Spacer()
                    Image(systemName: selection == software ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection == software ? color(for: software) : .white.opacity(0.28))
                }
                Text(software.displayName)
                    .font(.headline)
                Text(shortDescription(for: software))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.47))
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
            .background(
                selection == software ? color(for: software).opacity(0.095) : .white.opacity(0.052),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(selection == software ? color(for: software).opacity(0.45) : .white.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var accent: Color { color(for: selection) }
    private var modeTitle: String { "Mode \(selection.displayName)" }

    private var softwareSymbol: String { symbol(for: selection) }

    private var modeDescription: String {
        switch selection {
        case .serato:
            "Contrôle direct des decks et installation d’un mapping MIDI dédié."
        case .djay:
            "Observation de la file Automix avec un parcours sans mapping obligatoire."
        case .rekordbox:
            "Import de bibliothèque, mapping MIDI avancé et contrôles Accessibilité protégés."
        }
    }

    private var validationDescription: String {
        switch selection {
        case .serato:
            "Le preset peut être installé automatiquement, mais les réactions réelles doivent être testées sur le Mac cible."
        case .djay:
            "La file Automix reste conservatrice tant que l’arbre Accessibilité de la version installée n’a pas été validé."
        case .rekordbox:
            "Les imports XML/JSON sont automatisés ; les commandes Live restent REQUIRES_DEVICE_VALIDATION."
        }
    }

    private func shortDescription(for software: DJSoftware) -> String {
        switch software {
        case .serato: "Mapping direct et contrôle des decks."
        case .djay: "Automix et observation légère."
        case .rekordbox: "Bibliothèque, MIDI et contrôle avancé."
        }
    }

    private func symbol(for software: DJSoftware) -> String {
        switch software {
        case .serato: "music.note.list"
        case .djay: "wand.and.stars.inverse"
        case .rekordbox: "record.circle"
        }
    }

    private func color(for software: DJSoftware) -> Color {
        switch software {
        case .serato: .purple
        case .djay: .cyan
        case .rekordbox: .blue
        }
    }
}
#endif
