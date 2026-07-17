#if os(macOS)
import MixPilotCore
import SwiftUI

struct DJSoftwareSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selection = DJSoftwareSelectionStore.current

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MixPilotSectionHero(
                        eyebrow: "Backend de contrôle",
                        title: "Choisir le logiciel DJ",
                        subtitle: "MixPilot conserve le même moteur de préparation et de sécurité. Le logiciel choisi détermine uniquement les moyens d’observation et de contrôle.",
                        symbol: "music.note.house.fill",
                        accent: accent
                    ) {
                        MixPilotStatusBadge(
                            title: selection.displayName,
                            symbol: softwareSymbol,
                            accent: accent
                        )
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 12)], spacing: 12) {
                        ForEach(DJSoftware.allCases) { software in
                            softwareCard(software)
                        }
                    }

                    MixPilotGlassCard(accent: accent, elevation: .elevated) {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack(alignment: .top, spacing: 14) {
                                MixPilotPanelTitle(
                                    title: modeTitle,
                                    symbol: softwareSymbol,
                                    subtitle: modeDescription,
                                    accent: accent
                                )
                                Spacer()
                                MixPilotStatusBadge(
                                    title: selection == .serato ? "MIDI direct" : selection == .rekordbox ? "MIDI + bibliothèque" : "Automix observé",
                                    symbol: "checkmark.shield.fill",
                                    accent: accent
                                )
                            }

                            MixPilotNotice(
                                title: "Niveau de validation",
                                message: validationDescription,
                                kind: selection == .djay ? .warning : .info
                            )

                            HStack(spacing: 10) {
                                Button("OUVRIR LE STUDIO") {
                                    model.selectedSection = .studio
                                }
                                .buttonStyle(MixPilotPrimaryButtonStyle(accent: accent))

                                Button("ACTUALISER LE DIAGNOSTIC") {
                                    model.refreshEnvironment()
                                    model.evaluatePreflight()
                                }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                            }
                        }
                    }

                    HStack(spacing: 9) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(accent)
                        Text("Le changement est appliqué immédiatement au diagnostic, au Studio et au Préflight.")
                            .font(.caption)
                            .foregroundStyle(MixPilotPalette.textTertiary)
                    }
                }
                .padding(28)
                .frame(maxWidth: 820, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .mixPilotWindowSurface(minWidth: 760, minHeight: 520)
    }

    private func softwareCard(_ software: DJSoftware) -> some View {
        let selected = selection == software
        let softwareAccent = color(for: software)

        return Button {
            selection = software
            DJSoftwareSelectionStore.current = software
            model.refreshEnvironment()
            model.evaluatePreflight()
        } label: {
            MixPilotGlassCard(
                cornerRadius: 18,
                padding: 16,
                accent: softwareAccent,
                elevation: selected ? .elevated : .standard,
                interactive: true
            ) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(softwareAccent.opacity(0.13))
                            Image(systemName: symbol(for: software))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(softwareAccent)
                        }
                        .frame(width: 46, height: 46)

                        Spacer()

                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(selected ? softwareAccent : .white.opacity(0.25))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(software.displayName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text(shortDescription(for: software))
                            .font(.caption)
                            .foregroundStyle(MixPilotPalette.textTertiary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(1.5)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(selected ? softwareAccent : .white.opacity(0.22))
                            .frame(width: 6, height: 6)
                        Text(selected ? "SÉLECTIONNÉ" : "SÉLECTIONNER")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(selected ? softwareAccent : MixPilotPalette.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Utiliser \(software.displayName)")
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
            "Les imports XML et JSON sont automatisés ; les commandes Live restent soumises à une validation réelle du contrôleur."
        }
    }

    private func shortDescription(for software: DJSoftware) -> String {
        switch software {
        case .serato: "Mapping direct et contrôle détaillé des decks."
        case .djay: "Automix et observation légère, sans preset imposé."
        case .rekordbox: "Bibliothèque, MIDI et contrôle avancé versionné."
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