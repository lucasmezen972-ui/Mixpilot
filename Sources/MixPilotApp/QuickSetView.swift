#if os(macOS)
import MixPilotCore
import SwiftUI

struct QuickSetView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MixPilotSectionHero(
                        eyebrow: "Flux express",
                        title: "Préparer un set rapidement",
                        subtitle: "Un parcours court, lisible et sécurisé pour passer d’une playlist affichée à un Préflight prêt à être contrôlé.",
                        symbol: "bolt.fill",
                        accent: .purple
                    ) {
                        MixPilotStatusBadge(
                            title: model.preparedProject == nil ? "Prêt à démarrer" : "Set détecté",
                            symbol: model.preparedProject == nil ? "sparkles" : "checkmark.seal.fill",
                            accent: model.preparedProject == nil ? .purple : .green
                        )
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        quickStep(1, "Afficher la playlist", "Place la bonne liste au premier plan dans le logiciel DJ.", "music.note.list", .purple)
                        quickStep(2, "Analyser", "MixPilot prépare BPM, structure et transitions proposées.", "waveform.badge.magnifyingglass", .cyan)
                        quickStep(3, "Sécuriser", "Le plan est verrouillé puis contrôlé dans le Préflight.", "checkmark.shield.fill", .green)
                    }

                    MixPilotGlassCard(accent: model.preparedProject == nil ? .purple : .green, elevation: .elevated) {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack(alignment: .top, spacing: 14) {
                                MixPilotPanelTitle(
                                    title: model.preparedProject == nil ? "Prêt à capturer" : "Set préparé",
                                    symbol: model.preparedProject == nil ? "tray.and.arrow.down.fill" : "checkmark.seal.fill",
                                    subtitle: projectDescription,
                                    accent: model.preparedProject == nil ? .purple : .green
                                )
                                Spacer()
                                if let project = model.preparedProject {
                                    MixPilotStatusBadge(
                                        title: project.locked ? "Plan verrouillé" : "Plan préparé",
                                        symbol: project.locked ? "lock.fill" : "music.note.list",
                                        accent: project.locked ? .green : .orange
                                    )
                                }
                            }

                            MixPilotNotice(
                                title: "Séquence automatique contrôlée",
                                message: "La capture prépare le projet, verrouille le plan et ouvre le Préflight. Aucune commande Live n’est envoyée pendant cette étape.",
                                kind: .info
                            )

                            HStack(spacing: 10) {
                                Button("CAPTURER ET PRÉPARER") {
                                    model.captureSeratoPlaylist()
                                    model.lockPreparedProject()
                                    model.selectedSection = .preflight
                                    model.refreshEnvironment()
                                }
                                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                                .controlSize(.large)

                                if model.preparedProject != nil {
                                    Button("ACTUALISER LE PRÉFLIGHT") {
                                        model.evaluatePreflight()
                                        model.selectedSection = .preflight
                                    }
                                    .buttonStyle(MixPilotSecondaryButtonStyle())
                                }
                            }
                        }
                    }

                    HStack(spacing: 9) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.cyan)
                        Text("La bibliothèque du logiciel DJ n’est jamais modifiée et le Live reste bloqué tant que les contrôles critiques ne sont pas validés.")
                            .font(.caption)
                            .foregroundStyle(MixPilotPalette.textTertiary)
                    }
                }
                .padding(28)
                .frame(maxWidth: 760, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .mixPilotWindowSurface(minWidth: 700, minHeight: 470)
    }

    private var projectDescription: String {
        guard let project = model.preparedProject else {
            return "Ouvre la playlist voulue avant de lancer la préparation express."
        }
        return "\(project.tracks.count) titres • \(project.transitions.count) transitions • \(premiumQuickDuration(project.duration))"
    }

    private func quickStep(_ number: Int, _ title: String, _ detail: String, _ symbol: String, _ accent: Color) -> some View {
        MixPilotGlassCard(cornerRadius: 16, padding: 14, accent: accent, interactive: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(String(format: "%02d", number))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(accent)
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(accent.opacity(0.12))
                        Image(systemName: symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 30, height: 30)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MixPilotPalette.textTertiary)
                    .lineSpacing(1.5)
            }
            .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        }
    }
}

private func premiumQuickDuration(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int(seconds / 60))
    return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
}
#endif