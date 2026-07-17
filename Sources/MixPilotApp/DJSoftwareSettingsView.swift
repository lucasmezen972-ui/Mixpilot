#if os(macOS)
import MixPilotCore
import SwiftUI

struct DJSoftwareSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    MixPilotSectionHero(
                        eyebrow: AppLocalizedCopy.text("app.backend.hero.eyebrow"),
                        title: AppLocalizedCopy.text("app.backend.hero.title"),
                        subtitle: AppLocalizedCopy.text("app.backend.hero.subtitle"),
                        symbol: "music.note.house.fill",
                        accent: .cyan
                    ) {
                        Button(AppLocalizedCopy.text("app.backend.refresh")) { model.refreshEnvironment() }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 300), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(DJBackendIdentifier.allCases) { backend in
                            backendCard(backend)
                        }
                    }

                    MixPilotGlassCard(accent: .cyan) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.cyan)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(AppLocalizedCopy.text("app.backend.equal.title"))
                                    .font(.headline)
                                Text(AppLocalizedCopy.text("app.backend.equal.detail"))
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                            Spacer()
                        }
                    }
                }
                .padding(30)
                .frame(maxWidth: 1_120, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1_020, minHeight: 700)
        .onAppear { model.refreshEnvironment() }
    }

    private func backendCard(_ backend: DJBackendIdentifier) -> some View {
        let descriptor = model.backendDescriptors.first { $0.identifier == backend }
        let selected = model.selectedBackend == backend
        let accent = color(for: backend)
        let environment = descriptor?.environment
        let capabilities = descriptor?.capabilities ?? DJBackendCapabilities()
        let readyCount = DJCapability.allCases.filter { capabilities[$0].isConfirmedForLive }.count
        let availableCount = DJCapability.allCases.filter { capabilities[$0].canBePlanned }.count
        let missing = configurationSummary(backend, descriptor: descriptor)

        return MixPilotGlassCard(cornerRadius: 22, padding: 20, accent: accent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(accent.opacity(0.14))
                        Image(systemName: symbol(for: backend))
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(backend.displayName)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                        Text(productSubtitle(for: backend))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.52))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: selected ? "checkmark.seal.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected ? accent : .white.opacity(0.24))
                }

                HStack(spacing: 8) {
                    MixPilotStatusBadge(
                        title: installationLabel(environment),
                        symbol: environment?.isInstalled == true ? "checkmark.circle.fill" : "arrow.down.circle",
                        accent: environment?.isInstalled == true ? .green : .orange
                    )
                    if let version = environment?.softwareVersion {
                        MixPilotStatusBadge(
                            title: AppLocalizedCopy.format("app.backend.version_format", version),
                            symbol: "number",
                            accent: .blue
                        )
                    }
                }

                Text(modeDescription(for: backend))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.66))
                    .frame(minHeight: 42, alignment: .topLeading)

                VStack(spacing: 9) {
                    capabilityRow(
                        AppLocalizedCopy.text("app.backend.capability.prepare_set"),
                        available: true,
                        accent: accent
                    )
                    capabilityRow(
                        AppLocalizedCopy.text(
                            backend == .djay
                                ? "app.backend.capability.automix"
                                : "app.backend.capability.deck_control"
                        ),
                        available: backend == .djay
                            ? capabilities[.automix].canBePlanned
                            : capabilities[.playPause].canBePlanned,
                        accent: accent
                    )
                    capabilityRow(
                        AppLocalizedCopy.text("app.backend.capability.library"),
                        available: capabilities[.libraryReading].canBePlanned,
                        accent: accent
                    )
                    capabilityRow(
                        AppLocalizedCopy.text("app.backend.capability.manual"),
                        available: true,
                        accent: accent
                    )
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppLocalizedCopy.text("app.backend.compatibility"))
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.36))
                        Text(AppLocalizedCopy.format(
                            "app.backend.compatibility_summary_format",
                            readyCount,
                            availableCount
                        ))
                            .font(.caption.bold())
                    }
                    Spacer()
                    Text(AppLocalizedCopy.text(
                        environment?.isRunning == true ? "app.backend.connected" : "app.backend.check"
                    ))
                        .font(.caption.bold())
                        .foregroundStyle(environment?.isRunning == true ? .green : .orange)
                }
                .padding(11)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 4) {
                    Text(missing.title)
                        .font(.caption.bold())
                        .foregroundStyle(missing.ready ? .green : .orange)
                    Text(missing.detail)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 45, alignment: .topLeading)

                HStack(spacing: 8) {
                    Button(AppLocalizedCopy.text("app.backend.configure")) {
                        model.selectBackend(backend)
                        model.selectedSection = .mapping
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())

                    Button(AppLocalizedCopy.text("app.backend.test")) {
                        model.selectBackend(backend)
                        model.refreshEnvironment()
                        model.evaluatePreflight()
                        model.selectedSection = .preflight
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())

                    Button(AppLocalizedCopy.text(selected ? "app.backend.used" : "app.backend.use")) {
                        model.selectBackend(backend)
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: accent))
                    .disabled(selected || model.isLiveRunning)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if selected {
                Text(AppLocalizedCopy.text("app.backend.active"))
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.12), in: Capsule())
                    .padding(13)
            }
        }
    }

    private func capabilityRow(_ title: String, available: Bool, accent: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: available ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(available ? accent : .white.opacity(0.28))
            Text(title)
                .font(.caption)
                .foregroundStyle(available ? .white.opacity(0.72) : .white.opacity(0.4))
            Spacer()
        }
    }

    private func installationLabel(_ environment: DJBackendEnvironment?) -> String {
        guard let environment else {
            return AppLocalizedCopy.text("app.backend.install.unknown")
        }
        if !environment.isInstalled {
            return AppLocalizedCopy.text("app.backend.install.not_installed")
        }
        return AppLocalizedCopy.text(
            environment.isRunning ? "app.backend.install.open" : "app.backend.install.installed"
        )
    }

    private func configurationSummary(
        _ backend: DJBackendIdentifier,
        descriptor: DJBackendDescriptor?
    ) -> (title: String, detail: String, ready: Bool) {
        guard let descriptor else {
            return (
                AppLocalizedCopy.text("app.backend.summary.verification_required"),
                AppLocalizedCopy.text("app.backend.summary.no_analysis"),
                false
            )
        }
        if !descriptor.environment.isInstalled {
            return (
                AppLocalizedCopy.text("app.backend.summary.software_not_installed"),
                AppLocalizedCopy.format("app.backend.summary.install_format", backend.displayName),
                false
            )
        }
        if !descriptor.environment.isRunning {
            return (
                AppLocalizedCopy.text("app.backend.summary.launch"),
                AppLocalizedCopy.format("app.backend.summary.open_format", backend.displayName),
                false
            )
        }
        let critical: [DJCapability] = backend == .djay
            ? [.automix, .trackStateReading]
            : [.trackLoading, .playPause, .channelVolume]
        let pending = critical.filter { !descriptor.capabilities[$0].isConfirmedForLive }
        if pending.isEmpty {
            return (
                AppLocalizedCopy.text("app.backend.summary.ready"),
                AppLocalizedCopy.text("app.backend.summary.ready_detail"),
                true
            )
        }
        return (
            AppLocalizedCopy.format("app.backend.summary.pending_title_format", pending.count),
            AppLocalizedCopy.text("app.backend.summary.pending_detail"),
            false
        )
    }

    private func productSubtitle(for backend: DJBackendIdentifier) -> String {
        switch backend {
        case .djay:
            AppLocalizedCopy.text("app.backend.subtitle.djay")
        case .rekordbox:
            AppLocalizedCopy.text("app.backend.subtitle.rekordbox")
        case .serato:
            AppLocalizedCopy.text("app.backend.subtitle.serato")
        }
    }

    private func modeDescription(for backend: DJBackendIdentifier) -> String {
        switch backend {
        case .djay:
            AppLocalizedCopy.text("app.backend.mode.djay")
        case .rekordbox:
            AppLocalizedCopy.text("app.backend.mode.rekordbox")
        case .serato:
            AppLocalizedCopy.text("app.backend.mode.serato")
        }
    }

    private func symbol(for backend: DJBackendIdentifier) -> String {
        switch backend {
        case .djay: "wand.and.stars.inverse"
        case .rekordbox: "record.circle"
        case .serato: "music.note.list"
        }
    }

    private func color(for backend: DJBackendIdentifier) -> Color {
        switch backend {
        case .djay: .cyan
        case .rekordbox: .blue
        case .serato: .purple
        }
    }
}
#endif
