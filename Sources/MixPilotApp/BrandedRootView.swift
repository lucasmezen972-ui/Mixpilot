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
            Rectangle()
                .fill(.white.opacity(0.09))
                .frame(height: 1)
            AdvancedContentView(model: model)
        }
        .background(MixPilotPremiumBackground())
        .preferredColorScheme(.dark)
    }

    private var workspaceHeader: some View {
        HStack(spacing: 14) {
            MixPilotBrandLogoView(size: 48, cornerRadius: 13)
                .shadow(color: .purple.opacity(0.25), radius: 14, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("MIXPILOT")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .tracking(0.7)
                    Text("AUTOPILOT")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.cyan)
                }
                Text("TRADIKOM BY LUCAS MEZEN")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .tracking(1.05)
                    .foregroundStyle(.white.opacity(0.42))
                Text(model.selectedSection.rawValue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()

            Button {
                openWindow(id: "dj-software")
            } label: {
                MixPilotStatusBadge(
                    title: selectedSoftware.displayName,
                    symbol: softwareSymbol,
                    accent: .purple
                )
            }
            .buttonStyle(.plain)

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

            VStack(alignment: .trailing, spacing: 3) {
                MixPilotStatusBadge(
                    title: model.isLiveRunning ? "Autopilot actif" : "Système prêt",
                    symbol: model.isLiveRunning ? "bolt.circle.fill" : "checkmark.circle.fill",
                    accent: model.isLiveRunning ? .green : .cyan
                )
                Text(model.runtimeStatus)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .frame(maxWidth: 210, alignment: .trailing)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.black.opacity(0.16))
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.purple.opacity(0.28), .cyan.opacity(0.16), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
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
