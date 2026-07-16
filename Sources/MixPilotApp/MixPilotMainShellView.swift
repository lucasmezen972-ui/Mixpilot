#if os(macOS)
import MixPilotCore
import SwiftUI

enum MixPilotMainSurface: String, CaseIterable, Identifiable {
    case home
    case workspace

    var id: String { rawValue }
}

struct MixPilotMainShellView: View {
    @ObservedObject var model: AppModel
    @Binding var surface: MixPilotMainSurface
    @ObservedObject var cloud: MixPilotCloudCoordinator

    private var selectedSoftware: DJSoftware { DJSoftwareSelectionStore.current }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch surface {
                case .home:
                    RekordboxHubView(appModel: model)
                        .transition(.opacity.combined(with: .scale(scale: 0.992)))
                case .workspace:
                    BrandedRootView(model: model)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                MixPilotUpdateBanner(cloud: cloud)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                Spacer()
            }

            navigationDock
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
        }
        .background(Color.black)
        .animation(.snappy(duration: 0.3), value: surface)
        .animation(.snappy(duration: 0.25), value: model.selectedSection)
        .animation(.snappy(duration: 0.3), value: cloud.availableUpdate?.id)
    }

    private var navigationDock: some View {
        HStack(spacing: 6) {
            destinationButton(
                title: "Accueil",
                symbol: "sparkles.rectangle.stack.fill",
                isSelected: surface == .home
            ) {
                surface = .home
            }

            divider

            destinationButton(
                title: "Tableau de bord",
                symbol: "rectangle.grid.2x2.fill",
                section: .dashboard
            )
            destinationButton(
                title: "Studio",
                symbol: "waveform.path.ecg",
                section: .studio
            )
            destinationButton(
                title: "Préflight",
                symbol: "checkmark.shield.fill",
                section: .preflight
            )
            destinationButton(
                title: "Live",
                symbol: "play.circle.fill",
                section: .live
            )

            divider

            Button {
                cloud.checkNow()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: cloud.connectionState.isConnected ? "cloud.fill" : "cloud.slash.fill")
                        .foregroundStyle(cloud.connectionState.isConnected ? .cyan : .orange)
                    Text(cloud.connectionState.isConnected ? "CLOUD" : "HORS LIGNE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.6)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .help("\(cloud.connectionState.label) — cliquer pour vérifier les mises à jour")

            divider

            HStack(spacing: 8) {
                Circle()
                    .fill(model.isLiveRunning ? Color.green : Color.cyan)
                    .frame(width: 8, height: 8)
                    .shadow(color: model.isLiveRunning ? .green.opacity(0.75) : .cyan.opacity(0.65), radius: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.isLiveRunning ? "AUTOPILOT ACTIF" : selectedSoftware.shortName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.7)
                    Text(model.runtimeStatus)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(7)
        .foregroundStyle(.white)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .cyan.opacity(0.18), .purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.42), radius: 28, y: 12)
        .shadow(color: .cyan.opacity(0.08), radius: 24)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 30)
            .padding(.horizontal, 3)
    }

    private func destinationButton(
        title: String,
        symbol: String,
        section: SidebarSection? = nil,
        isSelected explicitSelection: Bool? = nil,
        action explicitAction: (() -> Void)? = nil
    ) -> some View {
        let selected = explicitSelection ?? (surface == .workspace && model.selectedSection == section)
        let disabledByLive = model.isLiveRunning && section != .live

        return Button {
            if let explicitAction {
                explicitAction()
            } else if let section {
                model.selectedSection = section
                surface = .workspace
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: selected ? .bold : .semibold, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? .white : .white.opacity(0.68))
            .background {
                if selected {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.82), .blue.opacity(0.78), .cyan.opacity(0.62)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .cyan.opacity(0.2), radius: 12)
                } else {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.001))
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabledByLive)
        .opacity(disabledByLive ? 0.38 : 1)
        .help(disabledByLive ? "Navigation verrouillée pendant le Live" : title)
    }
}
#endif
