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

    private var compatibilityPaused: Bool {
        cloud.activeCompatibilityOverride?.blockLive == true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch surface {
                case .home:
                    DJSoftwareSettingsView(model: model)
                case .workspace:
                    UnifiedWorkspaceView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            statusBanners.zIndex(20)
            navigationDock
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .zIndex(30)

            if compatibilityPaused {
                compatibilityPauseOverlay.zIndex(100)
            }
        }
        .background(MixPilotPremiumBackground())
        .animation(.snappy(duration: 0.28), value: surface)
        .animation(.snappy(duration: 0.24), value: model.selectedSection)
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
    }

    private var navigationDock: some View {
        HStack(spacing: 8) {
            HStack(spacing: 9) {
                MixPilotBrandLogoView(size: 32, cornerRadius: 9)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MIXPILOT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                    Text(AppLocalizedCopy.text("app.brand.subtitle"))
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.horizontal, 4)

            divider

            destination(AppLocalizedCopy.text("app.nav.prepare"), "waveform.path.ecg", section: .studio)
            destination(AppLocalizedCopy.text("app.nav.verify"), "checkmark.shield.fill", section: .preflight)
            destination(AppLocalizedCopy.text("app.nav.live"), "play.circle.fill", section: .live)
            destination(AppLocalizedCopy.text("app.nav.advanced"), "gearshape.2.fill", section: .feasibility)

            divider
            servicesStatus
            divider
            runtimeSummary
        }
        .padding(8)
        .foregroundStyle(.white)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .fixedSize(horizontal: true, vertical: false)
    }

    private func destination(
        _ title: String,
        _ symbol: String,
        section: SidebarSection
    ) -> some View {
        let selected = surface == .workspace && primarySection(for: model.selectedSection) == section
        let disabled = model.isLiveRunning && section != .live
        return Button {
            model.selectedSection = section
            surface = .workspace
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 10.5, weight: selected ? .bold : .semibold, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? .white : .white.opacity(0.68))
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selected
                          ? AnyShapeStyle(LinearGradient(
                              colors: [.indigo.opacity(0.86), .blue.opacity(0.72), .cyan.opacity(0.52)],
                              startPoint: .leading,
                              endPoint: .trailing
                          ))
                          : AnyShapeStyle(.white.opacity(0.001)))
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled || (compatibilityPaused && section == .live))
        .opacity(disabled ? 0.36 : 1)
        .help(disabled ? AppLocalizedCopy.text("app.nav.live_locked_help") : title)
    }

    private func primarySection(for section: SidebarSection) -> SidebarSection {
        switch section {
        case .onboarding, .dashboard, .studio:
            .studio
        case .mapping, .preflight:
            .preflight
        case .live:
            .live
        case .feasibility, .diagnostics:
            .feasibility
        }
    }

    private var servicesStatus: some View {
        Button { cloud.checkNow() } label: {
            HStack(spacing: 7) {
                Image(systemName: cloud.connectionState.isConnected ? "arrow.triangle.2.circlepath" : "arrow.triangle.2.circlepath.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(cloud.connectionState.isConnected ? .cyan : .orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(AppLocalizedCopy.text("app.services.title"))
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.5)
                    Text(AppLocalizedCopy.text(
                        cloud.connectionState.isConnected ? "app.services.available" : "app.services.optional"
                    ))
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(MixPilotPalette.textTertiary)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .help(AppLocalizedCopy.text("app.services.check_help"))
    }

    private var runtimeSummary: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(model.isLiveRunning ? Color.green : Color.cyan)
                .frame(width: 7, height: 7)
                .shadow(color: model.isLiveRunning ? .green.opacity(0.75) : .cyan.opacity(0.65), radius: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(
                    model.isLiveRunning
                        ? AppLocalizedCopy.text("app.runtime.active")
                        : (model.selectedBackend?.displayName.uppercased()
                           ?? AppLocalizedCopy.text("app.runtime.choose_backend"))
                )
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.55)
                Text(model.runtimeStatus)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(MixPilotPalette.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 180, alignment: .leading)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.10))
            .frame(width: 1, height: 30)
            .padding(.horizontal, 2)
    }

    private var compatibilityPauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.90).ignoresSafeArea()
            MixPilotGlassCard(cornerRadius: 28, padding: 34, accent: .red, elevation: .elevated) {
                VStack(spacing: 18) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.red)
                    Text(AppLocalizedCopy.text("app.compatibility_pause.title"))
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                    Text(
                        cloud.activeCompatibilityOverride?.warnings.first
                            ?? AppLocalizedCopy.text("app.compatibility_pause.default_warning")
                    )
                        .font(.callout)
                        .foregroundStyle(MixPilotPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 620)
                    Text(AppLocalizedCopy.text("app.compatibility_pause.detail"))
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Button(AppLocalizedCopy.text("app.compatibility_pause.open_verify")) {
                        model.selectedSection = .preflight
                        surface = .workspace
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .red))
                }
            }
            .frame(maxWidth: 760)
            .padding(32)
        }
    }
}
#endif
