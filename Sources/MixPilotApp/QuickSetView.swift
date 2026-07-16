#if os(macOS)
import MixPilotCore
import SwiftUI

struct QuickSetView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            VStack(alignment: .leading, spacing: 22) {
                MixPilotSectionHero(
                    eyebrow: "Flux express",
                    title: "Préparer un set rapidement",
                    subtitle: "Capture la playlist visible, génère les transitions, verrouille le plan et ouvre le Préflight.",
                    symbol: "bolt.fill",
                    accent: .purple
                ) { EmptyView() }

                HStack(spacing: 12) {
                    quickStep(1, "Afficher la playlist", "Dans le logiciel DJ sélectionné.", "music.note.list", .purple)
                    quickStep(2, "Analyser", "BPM, durée et transitions.", "waveform.badge.magnifyingglass", .cyan)
                    quickStep(3, "Sécuriser", "Verrouillage et Préflight.", "checkmark.shield.fill", .green)
                }

                MixPilotGlassCard(accent: .purple) {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            MixPilotPanelTitle(
                                title: model.preparedProject == nil ? "Prêt à capturer" : "Set préparé",
                                symbol: model.preparedProject == nil ? "tray.and.arrow.down.fill" : "checkmark.seal.fill",
                                subtitle: projectDescription,
                                accent: model.preparedProject == nil ? .purple : .green
                            )
                            Spacer()
                            if let project = model.preparedProject {
                                MixPilotStatusBadge(
                                    title: project.locked ? "Verrouillé" : "Préparé",
                                    symbol: project.locked ? "lock.fill" : "music.note.list",
                                    accent: project.locked ? .green : .orange
                                )
                            }
                        }

                        Button("CAPTURER, PRÉPARER ET OUVRIR LE PRÉFLIGHT") {
                            model.captureSeratoPlaylist()
                            model.lockPreparedProject()
                            model.selectedSection = .preflight
                            model.refreshEnvironment()
                        }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                        .controlSize(.large)
                    }
                }

                Text("La capture n’écrit rien dans la bibliothèque du logiciel DJ et le Live reste bloqué tant que le Préflight n’est pas validé.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
        .frame(width: 700, height: 440)
    }

    private var projectDescription: String {
        guard let project = model.preparedProject else {
            return "Ouvre la playlist voulue avant de lancer la préparation."
        }
        return "\(project.tracks.count) titres • \(project.transitions.count) transitions • \(premiumQuickDuration(project.duration))"
    }

    private func quickStep(_ number: Int, _ title: String, _ detail: String, _ symbol: String, _ accent: Color) -> some View {
        MixPilotGlassCard(cornerRadius: 15, padding: 13, accent: accent) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundStyle(accent)
                    Spacer()
                    Image(systemName: symbol).foregroundStyle(accent)
                }
                Text(title).font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private func premiumQuickDuration(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int(seconds / 60))
    return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
}
#endif
