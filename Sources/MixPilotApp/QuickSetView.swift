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
                        eyebrow: "Flux automatique",
                        title: "Lancer un Live en un clic",
                        subtitle: "MixPilot choisit le logiciel DJ disponible, ouvre l’application, prépare et verrouille le set, démarre la surveillance audio puis lance l’Autopilote.",
                        symbol: "bolt.fill",
                        accent: .purple
                    ) {
                        MixPilotStatusBadge(
                            title: model.isLiveRunning ? "Live en cours" : model.preparedProject == nil ? "Prêt à démarrer" : "Set détecté",
                            symbol: model.isLiveRunning ? "play.circle.fill" : model.preparedProject == nil ? "sparkles" : "checkmark.seal.fill",
                            accent: model.isLiveRunning ? .green : model.preparedProject == nil ? .purple : .cyan
                        )
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        quickStep(1, "Détecter", "MixPilot choisit le logiciel DJ lancé ou installé et l’ouvre si nécessaire.", "music.note.house.fill", .purple)
                        quickStep(2, "Préparer", "La playlist est capturée si besoin, associée au logiciel et verrouillée automatiquement.", "wand.and.stars", .cyan)
                        quickStep(3, "Jouer", "La surveillance audio démarre puis l’Autopilote prend en charge le set.", "play.circle.fill", .green)
                    }

                    MixPilotGlassCard(accent: model.isLiveRunning ? .green : .purple, elevation: .elevated) {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack(alignment: .top, spacing: 14) {
                                MixPilotPanelTitle(
                                    title: model.isLiveRunning ? "Autopilote actif" : model.preparedProject == nil ? "Prêt à lancer" : "Set prêt pour le mode automatique",
                                    symbol: model.isLiveRunning ? "speaker.wave.2.fill" : "bolt.circle.fill",
                                    subtitle: projectDescription,
                                    accent: model.isLiveRunning ? .green : .purple
                                )
                                Spacer()
                                if let project = model.preparedProject {
                                    MixPilotStatusBadge(
                                        title: project.locked ? "Plan verrouillé" : "Verrouillage automatique",
                                        symbol: project.locked ? "lock.fill" : "lock.open.fill",
                                        accent: project.locked ? .green : .cyan
                                    )
                                }
                            }

                            MixPilotNotice(
                                title: "Seulement trois vrais blocages",
                                message: "Le lancement s’arrête uniquement s’il n’y a aucun logiciel DJ compatible, aucun set de deux titres ou aucune surveillance audio. Les contrôles secondaires deviennent des avertissements supervisés.",
                                kind: .info
                            )

                            HStack(spacing: 10) {
                                Button(model.isLiveRunning ? "LIVE AUTOMATIQUE EN COURS" : "LANCER LE LIVE AUTOMATIQUEMENT") {
                                    model.startLiveAutomatically()
                                }
                                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                                .controlSize(.large)
                                .disabled(model.isLiveRunning)

                                if model.preparedProject != nil && !model.isLiveRunning {
                                    Button("PRÉPARER SANS LANCER") {
                                        model.lockPreparedProject()
                                        model.evaluatePreflight()
                                        model.selectedSection = .preflight
                                    }
                                    .buttonStyle(MixPilotSecondaryButtonStyle())
                                }
                            }

                            Text(model.runtimeStatus)
                                .font(.callout)
                                .foregroundStyle(MixPilotPalette.textSecondary)
                                .textSelection(.enabled)
                        }
                    }

                    HStack(spacing: 9) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.orange)
                        Text("La reprise manuelle reste disponible à tout moment. macOS peut encore demander une seule fois l’autorisation Accessibilité ou audio : MixPilot ne peut pas cliquer à ta place dans une fenêtre système.")
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
            return "Ouvre ta playlist dans le logiciel DJ ou prépare-la depuis Spotify ; MixPilot fera le reste."
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
