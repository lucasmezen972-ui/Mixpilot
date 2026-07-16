#if os(macOS)
import MixPilotCore
import SwiftUI

struct BrandedRootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private var selectedSoftware: DJSoftware { DJSoftwareSelectionStore.current }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 15) {
                MixPilotBrandLogoView(size: 60, cornerRadius: 15)
                    .shadow(color: .purple.opacity(0.22), radius: 14, y: 6)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("MixPilot")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("AUTOPILOT")
                            .font(.caption2.black())
                            .tracking(1.5)
                            .foregroundStyle(.cyan)
                    }
                    Text("by Lucas Mezen • Serato, djay et rekordbox")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                softwarePill

                if selectedSoftware == .rekordbox {
                    Button {
                        openWindow(id: "rekordbox-hub")
                    } label: {
                        Label("REKORDBOX HUB", systemImage: "waveform.badge.magnifyingglass")
                            .font(.caption.bold())
                            .tracking(0.7)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                    .background(
                        LinearGradient(
                            colors: [.purple.opacity(0.82), .blue.opacity(0.82)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 11)
                    )
                } else {
                    Button {
                        openWindow(id: selectedSoftware == .serato
                            ? "automatic-serato-mapping"
                            : "dj-software")
                    } label: {
                        Label(
                            selectedSoftware == .serato ? "CONFIGURER SERATO" : "CONFIGURER LE BACKEND",
                            systemImage: "slider.horizontal.3"
                        )
                        .font(.caption.bold())
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Label(
                        model.isLiveRunning ? "AUTOPILOT ACTIF" : "SYSTÈME PRÊT",
                        systemImage: model.isLiveRunning ? "bolt.circle.fill" : "checkmark.circle.fill"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(model.isLiveRunning ? .green : .secondary)
                    Text(model.runtimeStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 190, alignment: .trailing)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    LinearGradient(
                        colors: [.purple.opacity(0.075), .blue.opacity(0.055), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )

            Divider()

            AdvancedContentView(model: model)
        }
    }

    private var softwarePill: some View {
        Label(selectedSoftware.displayName.uppercased(), systemImage: softwareSymbol)
            .font(.caption2.bold())
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.55), in: Capsule())
            .onTapGesture { openWindow(id: "dj-software") }
            .help("Changer de logiciel DJ")
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
