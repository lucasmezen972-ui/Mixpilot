#if os(macOS)
import MixPilotCore
import SwiftUI

struct QuickSetView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MixPilotSectionHero(
                        eyebrow: AppLocalizedCopy.technical("technical.quick.title"),
                        title: AppLocalizedCopy.technical("technical.quick.title"),
                        subtitle: AppLocalizedCopy.technical("technical.quick.subtitle"),
                        symbol: "wand.and.stars",
                        accent: .purple
                    ) {
                        if let backend = model.selectedBackend {
                            MixPilotStatusBadge(
                                title: backend.displayName,
                                symbol: "music.note.house.fill",
                                accent: .cyan
                            )
                        } else {
                            MixPilotStatusBadge(
                                title: AppLocalizedCopy.technical("technical.quick.configure"),
                                symbol: "exclamationmark.triangle.fill",
                                accent: .orange
                            )
                        }
                    }

                    HStack(alignment: .top, spacing: 14) {
                        quickStep(
                            number: "1",
                            title: AppLocalizedCopy.technical("technical.quick.import"),
                            detail: AppLocalizedCopy.technical("technical.quick.subtitle"),
                            symbol: "rectangle.and.text.magnifyingglass"
                        )
                        quickStep(
                            number: "2",
                            title: AppLocalizedCopy.technical("technical.analysis.title"),
                            detail: AppLocalizedCopy.technical("technical.analysis.warning"),
                            symbol: "waveform.path.ecg"
                        )
                        quickStep(
                            number: "3",
                            title: AppLocalizedCopy.technical("technical.device.validation"),
                            detail: AppLocalizedCopy.technical("technical.device.validation_detail"),
                            symbol: "checkmark.shield.fill"
                        )
                    }

                    if model.preparedProject == nil {
                        MixPilotGlassCard(accent: .purple) {
                            VStack(spacing: 16) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 46))
                                    .foregroundStyle(.purple)
                                Text(AppLocalizedCopy.technical("technical.quick.import"))
                                    .font(.title2.bold())
                                Text(AppLocalizedCopy.technical("technical.quick.fallback"))
                                    .font(.callout)
                                    .foregroundStyle(MixPilotPalette.textSecondary)
                                    .multilineTextAlignment(.center)
                                HStack(spacing: 10) {
                                    Button(AppLocalizedCopy.technical("technical.quick.demo")) {
                                        model.createDemoProject()
                                    }
                                    .buttonStyle(MixPilotSecondaryButtonStyle())
                                    Button(AppLocalizedCopy.technical("technical.quick.import")) {
                                        model.capturePlaylist()
                                    }
                                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                                    .disabled(model.selectedBackend == nil)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 250)
                        }
                    } else if let project = model.preparedProject {
                        MixPilotGlassCard(accent: project.locked ? .green : .cyan) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill((project.locked ? Color.green : Color.cyan).opacity(0.14))
                                    Image(systemName: project.locked ? "lock.fill" : "music.note.list")
                                        .font(.title2)
                                        .foregroundStyle(project.locked ? .green : .cyan)
                                }
                                .frame(width: 54, height: 54)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.name).font(.title2.bold())
                                    Text(AppLocalizedCopy.technicalFormat(
                                        "technical.quick.ready_format",
                                        project.tracks.count,
                                        project.backend?.displayName ?? model.selectedBackend?.displayName ?? "MixPilot"
                                    ))
                                    .font(.callout)
                                    .foregroundStyle(MixPilotPalette.textSecondary)
                                }
                                Spacer()
                                MixPilotStatusBadge(
                                    title: project.locked
                                        ? AppLocalizedCopy.workspace("workspace.project.locked")
                                        : AppLocalizedCopy.workspace("workspace.project.draft"),
                                    symbol: project.locked ? "checkmark.seal.fill" : "lock.open",
                                    accent: project.locked ? .green : .orange
                                )
                            }
                        }

                        MixPilotGlassCard(accent: .cyan) {
                            VStack(alignment: .leading, spacing: 9) {
                                MixPilotPanelTitle(
                                    title: AppLocalizedCopy.technical("technical.quick.status"),
                                    symbol: "bolt.horizontal.circle.fill",
                                    subtitle: model.backendStatus,
                                    accent: .cyan
                                )
                                Text(model.runtimeStatus)
                                    .font(.callout)
                                    .foregroundStyle(MixPilotPalette.textSecondary)
                                if !model.playlistWarnings.isEmpty {
                                    ForEach(Array(model.playlistWarnings.prefix(3).enumerated()), id: \.offset) { _, warning in
                                        Text("• \(warning.description)")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }

                        HStack {
                            Button(AppLocalizedCopy.technical("technical.quick.demo")) {
                                model.createDemoProject()
                            }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                            Button(AppLocalizedCopy.technical("technical.quick.import")) {
                                model.capturePlaylist()
                            }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                            Spacer()
                            Button(AppLocalizedCopy.technical("technical.quick.continue")) {
                                model.lockPreparedProject()
                                model.evaluatePreflight()
                                model.selectedSection = .preflight
                                dismissWindow(id: "quick-set")
                            }
                            .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                        }
                    }

                    if model.selectedBackend == nil {
                        MixPilotGlassCard(accent: .orange) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                Text(AppLocalizedCopy.technical("technical.quick.no_backend"))
                                Spacer()
                                Button(AppLocalizedCopy.technical("technical.quick.configure")) {
                                    openWindow(id: "dj-software")
                                }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                            }
                        }
                    }
                }
                .padding(26)
                .frame(maxWidth: 900)
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 620)
    }

    private func quickStep(number: String, title: String, detail: String, symbol: String) -> some View {
        MixPilotGlassCard(cornerRadius: 16, padding: 14, accent: .purple) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(number)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.purple)
                        .frame(width: 22, height: 22)
                        .background(.purple.opacity(0.14), in: Circle())
                    Spacer()
                    Image(systemName: symbol).foregroundStyle(.purple)
                }
                Text(title).font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MixPilotPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
        }
    }
}
#endif
