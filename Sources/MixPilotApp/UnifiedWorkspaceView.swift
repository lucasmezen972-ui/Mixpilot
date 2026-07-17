#if os(macOS)
import MixPilotCore
import SwiftUI

struct UnifiedWorkspaceView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()
            ScrollView {
                content
                    .padding(28)
                    .padding(.bottom, 110)
                    .frame(maxWidth: 1_180, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch primaryArea {
        case .prepare:
            prepareView
        case .verify:
            verifyView
        case .live:
            liveView
        case .advanced:
            advancedView
        }
    }

    private var primaryArea: PrimaryWorkspaceArea {
        switch model.selectedSection {
        case .live:
            .live
        case .preflight, .mapping:
            .verify
        case .feasibility, .diagnostics:
            .advanced
        case .onboarding, .dashboard, .studio:
            .prepare
        }
    }

    private var prepareView: some View {
        VStack(alignment: .leading, spacing: 22) {
            MixPilotSectionHero(
                eyebrow: AppLocalizedCopy.workspace("workspace.prepare.eyebrow"),
                title: AppLocalizedCopy.workspace("workspace.prepare.title"),
                subtitle: AppLocalizedCopy.workspace("workspace.prepare.subtitle"),
                symbol: "waveform.path.ecg",
                accent: .purple
            ) {
                Button(AppLocalizedCopy.workspace("workspace.prepare.choose_software")) {
                    openWindow(id: "dj-software")
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                Button(AppLocalizedCopy.workspace("workspace.prepare.demo_set")) {
                    model.createDemoProject()
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                Button(AppLocalizedCopy.workspace("workspace.prepare.import_playlist")) {
                    model.capturePlaylist()
                }
                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                .disabled(model.selectedBackend == nil)
            }

            backendSummary

            if let project = model.preparedProject {
                projectSummary(project)
                transitionList(project)
                HStack(spacing: 10) {
                    Button(AppLocalizedCopy.workspace(
                        project.locked ? "workspace.prepare.plan_locked" : "workspace.prepare.lock_plan"
                    )) {
                        model.lockPreparedProject()
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: project.locked ? .green : .cyan))
                    .disabled(project.locked)

                    Button(AppLocalizedCopy.workspace("workspace.prepare.test_transition")) {
                        openWindow(id: "rehearsal")
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                    Button(AppLocalizedCopy.workspace("workspace.prepare.refine_audio")) {
                        openWindow(id: "preparation-analysis")
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                    Button(AppLocalizedCopy.workspace("workspace.prepare.go_verify")) {
                        model.evaluatePreflight()
                        model.selectedSection = .preflight
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                }
            } else {
                emptyCard(
                    title: AppLocalizedCopy.workspace("workspace.prepare.empty_title"),
                    message: AppLocalizedCopy.workspace("workspace.prepare.empty_message"),
                    symbol: "music.note.list"
                )
            }
        }
    }

    private var verifyView: some View {
        VStack(alignment: .leading, spacing: 22) {
            MixPilotSectionHero(
                eyebrow: AppLocalizedCopy.workspace("workspace.verify.eyebrow"),
                title: AppLocalizedCopy.workspace("workspace.verify.title"),
                subtitle: AppLocalizedCopy.workspace("workspace.verify.subtitle"),
                symbol: "checkmark.shield.fill",
                accent: model.preflightReport.canStartLive ? .green : .orange
            ) {
                Button(AppLocalizedCopy.workspace("workspace.verify.refresh")) {
                    model.refreshEnvironment()
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                Button(AppLocalizedCopy.workspace("workspace.verify.configure_software")) {
                    openWindow(id: "dj-software")
                }
                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .cyan))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 14)], spacing: 14) {
                verificationTile(
                    AppLocalizedCopy.workspace("workspace.verify.tile.software"),
                    model.backendStatus,
                    "music.note.list",
                    .purple
                )
                verificationTile(
                    AppLocalizedCopy.workspace("workspace.verify.tile.commands"),
                    model.midiStatus,
                    "slider.horizontal.3",
                    .blue
                )
                verificationTile(
                    AppLocalizedCopy.workspace("workspace.verify.tile.state"),
                    model.accessibilityStatus,
                    "eye.fill",
                    .cyan
                )
                verificationTile(
                    AppLocalizedCopy.workspace("workspace.verify.tile.audio"),
                    model.audioStatus,
                    "waveform",
                    .mint
                )
                verificationTile(
                    AppLocalizedCopy.workspace("workspace.verify.tile.emergency"),
                    model.emergencyStatus,
                    "lifepreserver.fill",
                    .orange
                )
                verificationTile(
                    AppLocalizedCopy.workspace("workspace.verify.tile.final"),
                    model.preflightReport.canStartLive
                        ? AppLocalizedCopy.workspace("workspace.verify.ready")
                        : AppLocalizedCopy.workspaceFormat(
                            "workspace.verify.blockers_format",
                            model.preflightReport.failedItems.count
                        ),
                    "checkmark.seal.fill",
                    model.preflightReport.canStartLive ? .green : .red
                )
            }

            HStack(spacing: 10) {
                Button(AppLocalizedCopy.workspace("workspace.verify.allow_accessibility")) {
                    model.requestAccessibility()
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                Button(AppLocalizedCopy.workspace(
                    model.audioMonitor.isRunning
                        ? "workspace.verify.audio_active"
                        : "workspace.verify.start_audio"
                )) {
                    model.startAudioMonitoring()
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                .disabled(model.audioMonitor.isRunning)
                Button(AppLocalizedCopy.workspace("workspace.verify.choose_emergency")) {
                    model.selectEmergencyAudio()
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
            }

            VStack(spacing: 10) {
                ForEach(model.preflightReport.items) { item in
                    preflightRow(item)
                }
            }

            HStack {
                Spacer()
                Button(AppLocalizedCopy.workspace("workspace.verify.open_live")) {
                    model.selectedSection = .live
                }
                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                .disabled(!model.preflightReport.canStartLive)
            }
        }
    }

    private var liveView: some View {
        VStack(alignment: .leading, spacing: 22) {
            MixPilotSectionHero(
                eyebrow: AppLocalizedCopy.workspace("workspace.live.eyebrow"),
                title: AppLocalizedCopy.workspace(
                    model.isLiveRunning ? "workspace.live.title_running" : "workspace.live.title_ready"
                ),
                subtitle: AppLocalizedCopy.workspace("workspace.live.subtitle"),
                symbol: "play.circle.fill",
                accent: model.isLiveRunning ? .green : .cyan
            ) {
                Button(AppLocalizedCopy.workspace(
                    model.liveArmed ? "workspace.live.disarm" : "workspace.live.arm"
                )) {
                    model.armLive()
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                .disabled(model.isLiveRunning || !model.preflightReport.canStartLive)
                Button(AppLocalizedCopy.workspace("workspace.live.start")) {
                    model.startLive()
                }
                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                .disabled(!model.liveArmed || model.isLiveRunning)
                Button(
                    AppLocalizedCopy.workspace("workspace.live.take_control"),
                    role: .destructive
                ) {
                    model.takeManualControl()
                }
                .buttonStyle(MixPilotDangerButtonStyle())
                .disabled(!model.isLiveRunning)
            }

            backendSummary

            HStack(alignment: .top, spacing: 16) {
                MixPilotGlassCard(accent: .green) {
                    VStack(alignment: .leading, spacing: 12) {
                        MixPilotPanelTitle(
                            title: AppLocalizedCopy.workspace("workspace.live.current"),
                            symbol: "speaker.wave.2.fill",
                            subtitle: model.snapshot.statusMessage,
                            accent: .green
                        )
                        Text(
                            model.snapshot.currentTrack?.title
                                ?? AppLocalizedCopy.workspace("workspace.live.no_track")
                        )
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                        Text(model.snapshot.currentTrack?.artist ?? "")
                            .foregroundStyle(.white.opacity(0.55))
                        ProgressView(value: model.snapshot.progress).tint(.green)
                        Text(AppLocalizedCopy.workspaceFormat(
                            "workspace.live.deck_progress_format",
                            model.snapshot.activeDeck.rawValue,
                            model.snapshot.completedTransitions,
                            model.snapshot.totalTransitions
                        ))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                MixPilotGlassCard(accent: .cyan) {
                    VStack(alignment: .leading, spacing: 12) {
                        MixPilotPanelTitle(
                            title: AppLocalizedCopy.workspace("workspace.live.next"),
                            symbol: "forward.end.fill",
                            subtitle: AppLocalizedCopy.workspace("workspace.live.plan_on_mac"),
                            accent: .cyan
                        )
                        Text(
                            model.snapshot.nextTrack?.title
                                ?? AppLocalizedCopy.workspace("workspace.live.end_set")
                        )
                            .font(.title2.bold())
                        Text(model.audioStatus)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.58))
                        Text(model.runtimeStatus)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
            }

            if !model.runtimeEvents.isEmpty {
                MixPilotGlassCard(accent: .orange) {
                    VStack(alignment: .leading, spacing: 8) {
                        MixPilotPanelTitle(
                            title: AppLocalizedCopy.workspace("workspace.live.recent_events"),
                            symbol: "list.bullet.rectangle",
                            subtitle: AppLocalizedCopy.workspace("workspace.live.local_data"),
                            accent: .orange
                        )
                        ForEach(Array(model.runtimeEvents.suffix(8).enumerated()), id: \.offset) { _, event in
                            Text(event)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                }
            }
        }
    }

    private var advancedView: some View {
        VStack(alignment: .leading, spacing: 22) {
            MixPilotSectionHero(
                eyebrow: AppLocalizedCopy.workspace("workspace.advanced.eyebrow"),
                title: AppLocalizedCopy.workspace("workspace.advanced.title"),
                subtitle: AppLocalizedCopy.workspace("workspace.advanced.subtitle"),
                symbol: "gearshape.2.fill",
                accent: .orange
            ) {
                Button(AppLocalizedCopy.workspace("workspace.advanced.export")) {
                    model.exportDiagnostics()
                }
                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .orange))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                advancedCard(
                    AppLocalizedCopy.workspace("workspace.advanced.choice_title"),
                    AppLocalizedCopy.workspace("workspace.advanced.choice_detail"),
                    "music.note.house.fill"
                ) {
                    openWindow(id: "dj-software")
                }
                advancedCard(
                    AppLocalizedCopy.workspace("workspace.advanced.rehearsal_title"),
                    AppLocalizedCopy.workspace("workspace.advanced.rehearsal_detail"),
                    "repeat.circle.fill"
                ) {
                    openWindow(id: "rehearsal")
                }
                advancedCard(
                    AppLocalizedCopy.workspace("workspace.advanced.inspector_title"),
                    AppLocalizedCopy.workspace("workspace.advanced.inspector_detail"),
                    "waveform.path"
                ) {
                    openWindow(id: "transition-inspector")
                }
                advancedCard(
                    AppLocalizedCopy.workspace("workspace.advanced.audio_title"),
                    AppLocalizedCopy.workspace("workspace.advanced.audio_detail"),
                    "waveform.badge.magnifyingglass"
                ) {
                    openWindow(id: "preparation-analysis")
                }
                advancedCard(
                    AppLocalizedCopy.workspace("workspace.advanced.recovery_title"),
                    AppLocalizedCopy.workspace("workspace.advanced.recovery_detail"),
                    "arrow.counterclockwise.circle.fill"
                ) {
                    openWindow(id: "recovery-center")
                }
                backendAdvancedCard
            }

            MixPilotGlassCard(accent: .blue) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(AppLocalizedCopy.workspace("workspace.advanced.simulation_title"))
                            .font(.headline)
                        Text(AppLocalizedCopy.workspace("workspace.advanced.simulation_detail"))
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Button(AppLocalizedCopy.workspace(
                        model.isRunningSimulation
                            ? "workspace.advanced.simulation_running"
                            : "workspace.advanced.simulate_50"
                    )) {
                        model.runSimulation()
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .blue))
                    .disabled(model.isRunningSimulation)
                }
            }
        }
    }

    private var backendSummary: some View {
        MixPilotGlassCard(accent: .cyan) {
            HStack(spacing: 14) {
                Image(systemName: "music.note.house.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        model.selectedBackend?.displayName
                            ?? AppLocalizedCopy.workspace("workspace.backend.none")
                    )
                        .font(.headline)
                    Text(model.backendStatus)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Button(AppLocalizedCopy.workspace("workspace.backend.change")) {
                    openWindow(id: "dj-software")
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                .disabled(model.isLiveRunning)
            }
        }
    }

    private var backendAdvancedCard: some View {
        Group {
            switch model.selectedBackend {
            case .rekordbox:
                advancedCard(
                    AppLocalizedCopy.workspace("workspace.backend.rekordbox_title"),
                    AppLocalizedCopy.workspace("workspace.backend.rekordbox_detail"),
                    "record.circle"
                ) {
                    openWindow(id: "rekordbox-hub")
                }
            case .serato:
                advancedCard(
                    AppLocalizedCopy.workspace("workspace.backend.serato_title"),
                    AppLocalizedCopy.workspace("workspace.backend.serato_detail"),
                    "slider.horizontal.3"
                ) {
                    openWindow(id: "automatic-serato-mapping")
                }
            case .djay:
                advancedCard(
                    AppLocalizedCopy.workspace("workspace.backend.djay_title"),
                    AppLocalizedCopy.workspace("workspace.backend.djay_detail"),
                    "wand.and.stars"
                ) {
                    model.selectedSection = .feasibility
                }
            case nil:
                advancedCard(
                    AppLocalizedCopy.workspace("workspace.backend.not_selected_title"),
                    AppLocalizedCopy.workspace("workspace.backend.not_selected_detail"),
                    "questionmark.circle"
                ) {
                    openWindow(id: "dj-software")
                }
            }
        }
    }

    private func projectSummary(_ project: SetProject) -> some View {
        MixPilotGlassCard(accent: project.locked ? .green : .purple) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.name).font(.title2.bold())
                    Text(AppLocalizedCopy.workspaceFormat(
                        "workspace.project.summary_format",
                        project.tracks.count,
                        project.transitions.count,
                        project.reviewTransitionCount
                    ))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                MixPilotStatusBadge(
                    title: AppLocalizedCopy.workspace(
                        project.locked ? "workspace.project.locked" : "workspace.project.draft"
                    ),
                    symbol: project.locked ? "lock.fill" : "lock.open",
                    accent: project.locked ? .green : .orange
                )
            }
        }
    }

    private func transitionList(_ project: SetProject) -> some View {
        MixPilotGlassCard(accent: .cyan) {
            VStack(alignment: .leading, spacing: 10) {
                MixPilotPanelTitle(
                    title: AppLocalizedCopy.workspace("workspace.transitions.title"),
                    symbol: "arrow.left.arrow.right",
                    subtitle: AppLocalizedCopy.workspace("workspace.transitions.subtitle"),
                    accent: .cyan
                )
                ForEach(Array(project.transitions.prefix(12).enumerated()), id: \.element.id) { index, transition in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.cyan)
                            .frame(width: 24)
                        Text(transition.kind.rawValue).font(.callout.bold())
                        Spacer()
                        Text(AppLocalizedCopy.workspaceFormat(
                            "workspace.transitions.row_format",
                            transition.bars,
                            transition.confidence
                        ))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    private func verificationTile(
        _ title: String,
        _ value: String,
        _ symbol: String,
        _ accent: Color
    ) -> some View {
        MixPilotGlassCard(cornerRadius: 16, padding: 15, accent: accent) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol).foregroundStyle(accent)
                Text(title).font(.caption.bold()).foregroundStyle(.white.opacity(0.48))
                Text(value).font(.headline).lineLimit(3)
            }
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        }
    }

    private func preflightRow(_ item: PreflightItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: preflightSymbol(item.status))
                .foregroundStyle(preflightColor(item.status))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline)
                Text(item.detail).font(.callout).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private func advancedCard(
        _ title: String,
        _ detail: String,
        _ symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MixPilotGlassCard(cornerRadius: 17, padding: 16, accent: .orange) {
                HStack(spacing: 13) {
                    Image(systemName: symbol).font(.title2).foregroundStyle(.orange).frame(width: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.52))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            }
        }
        .buttonStyle(.plain)
    }

    private func emptyCard(title: String, message: String, symbol: String) -> some View {
        MixPilotGlassCard(accent: .purple) {
            VStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 46)).foregroundStyle(.purple)
                Text(title).font(.title2.bold())
                Text(message)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 580)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        }
    }

    private func preflightSymbol(_ status: PreflightItemStatus) -> String {
        switch status {
        case .passed: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .notTested: "questionmark.circle.fill"
        }
    }

    private func preflightColor(_ status: PreflightItemStatus) -> Color {
        switch status {
        case .passed: .green
        case .warning: .orange
        case .failed: .red
        case .notTested: .gray
        }
    }
}

enum PrimaryWorkspaceArea: String, CaseIterable, Identifiable {
    case prepare
    case verify
    case live
    case advanced

    var id: String { rawValue }
}
#endif
