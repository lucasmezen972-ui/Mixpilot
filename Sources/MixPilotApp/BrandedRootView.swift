#if os(macOS)
import MixPilotCore
import SwiftUI

struct BrandedRootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private var selectedSoftware: DJSoftware { DJSoftwareSelectionStore.current }

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            AdvancedContentView(model: model)
        }
        .background(MixPilotPremiumBackground())
        .preferredColorScheme(.dark)
    }

    private var workspaceHeader: some View {
        HStack(spacing: 15) {
            HStack(spacing: 12) {
                MixPilotBrandLogoView(size: 44, cornerRadius: 12)
                    .shadow(color: .indigo.opacity(0.22), radius: 16, y: 7)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text("MIXPILOT")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .tracking(0.75)
                        Text("CONTROL CENTER")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1.35)
                            .foregroundStyle(.cyan)
                    }

                    HStack(spacing: 6) {
                        Text("TRADIKOM BY LUCAS MEZEN")
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                            .tracking(1.0)
                            .foregroundStyle(MixPilotPalette.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white.opacity(0.25))
                        Text(model.selectedSection.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }
            }

            Spacer(minLength: 16)

            Button {
                openWindow(id: "dj-software")
            } label: {
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.purple.opacity(0.12))
                        Image(systemName: softwareSymbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.purple)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("LOGICIEL DJ")
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(MixPilotPalette.textTertiary)
                        Text(selectedSoftware.displayName)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help("Changer de logiciel DJ")

            if selectedSoftware == .rekordbox {
                Button {
                    openWindow(id: "rekordbox-hub")
                } label: {
                    Label("REKORDBOX HUB", systemImage: "waveform.badge.magnifyingglass")
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
            } else if selectedSoftware == .serato {
                Button {
                    openWindow(id: "automatic-serato-mapping")
                } label: {
                    Label("CONFIGURER SERATO", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
            }

            runtimeState
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.18), .black.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.indigo.opacity(0.28), .cyan.opacity(0.13), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    private var runtimeState: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill((model.isLiveRunning ? Color.green : Color.cyan).opacity(0.12))
                Circle()
                    .fill(model.isLiveRunning ? Color.green : Color.cyan)
                    .frame(width: 7, height: 7)
                    .shadow(color: model.isLiveRunning ? .green.opacity(0.70) : .cyan.opacity(0.60), radius: 6)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.isLiveRunning ? "AUTOPILOT ACTIF" : "SYSTÈME PRÊT")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .tracking(0.65)
                    .foregroundStyle(model.isLiveRunning ? .green : .cyan)
                Text(model.runtimeStatus)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(MixPilotPalette.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 210, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.040), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var softwareSymbol: String {
        switch selectedSoftware {
        case .serato: "music.note.list"
        case .djay: "wand.and.stars.inverse"
        case .rekordbox: "record.circle"
        }
    }
}
#endif