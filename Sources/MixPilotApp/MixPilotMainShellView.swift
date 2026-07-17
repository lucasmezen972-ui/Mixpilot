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
    private var compatibilityPaused: Bool { cloud.activeCompatibilityOverride?.blockLive == true }

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

            statusBanners
                .zIndex(20)

            navigationDock
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .zIndex(30)

            if compatibilityPaused {
                compatibilityPauseOverlay
                    .zIndex(100)
            }
        }
        .background(MixPilotPremiumBackground())
        .animation(.snappy(duration: 0.30), value: surface)
        .animation(.snappy(duration: 0.25), value: model.selectedSection)
        .animation(.snappy(duration: 0.30), value: cloud.availableUpdate?.id)
        .animation(.snappy(duration: 0.30), value: cloud.availableMapping?.id)
        .animation(.snappy(duration: 0.30), value: cloud.activeCompatibilityOverride?.id)
        .animation(.snappy(duration: 0.30), value: cloud.stagedMapping?.mappingVersion)
        .onChange(of: compatibilityPaused) { _, paused in
            guard paused else { return }
            model.takeManualControl()
            model.selectedSection = .preflight
            surface = .workspace
        }
    }

    private var statusBanners: some View {
        VStack(spacing: 10) {
            MixPilotCompatibilityWarningBanner(cloud: cloud)
            MixPilotRemoteMappingBanner(cloud: cloud)
            MixPilotUpdateBanner(cloud: cloud)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .allowsHitTesting(true)
    }

    private var compatibilityPauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.90)
                .ignoresSafeArea()

            RadialGradient(
                colors: [.red.opacity(0.18), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()

            MixPilotGlassCard(cornerRadius: 28, padding: 34, accent: .red, elevation: .elevated) {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(.red.opacity(0.13))
                        Circle()
                            .strokeBorder(.red.opacity(0.30), lineWidth: 1)
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                    .frame(width: 82, height: 82)

                    VStack(spacing: 8) {
                        MixPilotStatusBadge(
                            title: "Sécurité prioritaire",
                            symbol: "exclamationmark.shield.fill",
                            accent: .red
                        )
                        Text("Mode Live temporairement suspendu")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text(cloud.activeCompatibilityOverride?.warnings.first
                             ?? "Cette combinaison de versions nécessite une validation supplémentaire avant le prochain Live.")
                            .font(.callout)
                            .foregroundStyle(MixPilotPalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 620)
                    }

                    MixPilotNotice(
                        title: "Aucune commande automatique ne sera envoyée",
                        message: "MixPilot reprend le contrôle manuel, ouvre le Préflight et attend une validation réelle du mapping avant de réautoriser le Live.",
                        kind: .danger
                    )
                    .frame(maxWidth: 660)

                    HStack(spacing: 10) {
                        if cloud.availableMapping != nil {
                            Button("PRÉPARER LE MAPPING") {
                                cloud.installAvailableMapping()
                            }
                            .buttonStyle(MixPilotPrimaryButtonStyle(accent: .red))
                        }

                        Button("REVÉRIFIER LA COMPATIBILITÉ") {
                            cloud.checkNow()
                        }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    }
                }
            }
            .frame(maxWidth: 760)
            .padding(32)
        }
        .transition(.opacity)
    }

    private var navigationDock: some View {
        HStack(spacing: 8) {
            HStack(spacing: 9) {
                MixPilotBrandLogoView(size: 32, cornerRadius: 9)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MIXPILOT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.0)
                    Text("AUTOPILOT")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .tracking(1.25)
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 5)

            dockDivider

            destinationButton(
                title: "Accueil",
                symbol: "sparkles.rectangle.stack.fill",
                isSelected: surface == .home
            ) {
                surface = .home
            }

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

            dockDivider

            cloudButton

            dockDivider

            runtimeSummary
        }
        .padding(8)
        .foregroundStyle(.white)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.black.opacity(0.16))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .cyan.opacity(0.13), .indigo.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.48), radius: 30, y: 14)
        .shadow(color: .cyan.opacity(0.055), radius: 26)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var cloudButton: some View {
        Button {
            cloud.checkNow()
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill((cloud.connectionState.isConnected ? Color.cyan : Color.orange).opacity(0.13))
                    Image(systemName: cloud.connectionState.isConnected ? "cloud.fill" : "cloud.slash.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(cloud.connectionState.isConnected ? .cyan : .orange)
                }
                .frame(width: 25, height: 25)

                VStack(alignment: .leading, spacing: 1) {
                    Text(cloud.connectionState.isConnected ? "CLOUD ACTIF" : "HORS LIGNE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.55)
                    Text("Vérifier")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(MixPilotPalette.textTertiary)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .help("\(cloud.connectionState.label) — vérifier les mises à jour et mappings")
    }

    private var runtimeSummary: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill((model.isLiveRunning ? Color.green : Color.cyan).opacity(0.13))
                Circle()
                    .fill(model.isLiveRunning ? Color.green : Color.cyan)
                    .frame(width: 7, height: 7)
                    .shadow(color: model.isLiveRunning ? .green.opacity(0.75) : .cyan.opacity(0.65), radius: 7)
            }
            .frame(width: 25, height: 25)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.isLiveRunning ? "AUTOPILOT ACTIF" : selectedSoftware.shortName.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.65)
                Text(model.runtimeStatus)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(MixPilotPalette.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 170, alignment: .leading)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
    }

    private var dockDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.10))
            .frame(width: 1, height: 30)
            .padding(.horizontal, 2)
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
        let disabledByCompatibility = compatibilityPaused && section == .live
        let disabled = disabledByLive || disabledByCompatibility

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
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: selected ? .bold : .semibold, design: .rounded))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? .white : .white.opacity(0.68))
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.indigo.opacity(0.86), .blue.opacity(0.72), .cyan.opacity(0.52)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(.white.opacity(0.17), lineWidth: 1)
                        }
                        .shadow(color: .cyan.opacity(0.14), radius: 10, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.white.opacity(0.001))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.36 : 1)
        .help(disabledByCompatibility
              ? "Mode Live suspendu par une règle de compatibilité validée"
              : disabledByLive
                  ? "Navigation verrouillée pendant le Live"
                  : title)
    }
}
#endif