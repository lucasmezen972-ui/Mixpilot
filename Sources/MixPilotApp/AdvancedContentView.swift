#if os(macOS)
import MixPilotCore
import SwiftUI

struct AdvancedContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            HStack(spacing: 0) {
                PremiumWorkspaceSidebar(model: model)
                Rectangle()
                    .fill(.white.opacity(0.09))
                    .frame(width: 1)
                detail
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1_180, minHeight: 760)
        .onAppear {
            if !model.hasCompletedOnboarding {
                model.selectedSection = .onboarding
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selectedSection {
        case .onboarding:
            PremiumOnboardingView(model: model)
        case .dashboard:
            PremiumDashboardView(model: model)
        case .studio:
            PremiumStudioView(model: model)
        case .mapping:
            PremiumMappingView(model: model)
        case .preflight:
            PremiumPreflightView(model: model)
        case .live:
            PremiumLiveView(model: model)
        case .feasibility:
            PremiumFeasibilityView(model: model)
        case .diagnostics:
            PremiumDiagnosticsView(model: model)
        }
    }
}

private struct PremiumWorkspaceSidebar: View {
    @ObservedObject var model: AppModel

    private var selectedSoftware: DJSoftware { DJSoftwareSelectionStore.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                MixPilotBrandLogoView(size: 42, cornerRadius: 11)
                    .shadow(color: .purple.opacity(0.22), radius: 12, y: 5)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MIXPILOT")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(1.1)
                    Text("CONTROL CENTER")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            MixPilotGlassCard(cornerRadius: 14, padding: 12, accent: .purple) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Image(systemName: softwareSymbol)
                            .foregroundStyle(.cyan)
                        Text(selectedSoftware.displayName)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Spacer()
                    }
                    Text(model.runtimeStatus)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)

            Text("NAVIGATION")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 14)
                .padding(.top, 4)

            ScrollView {
                VStack(spacing: 5) {
                    ForEach(SidebarSection.allCases) { section in
                        Button {
                            withAnimation(.snappy(duration: 0.24)) {
                                model.selectedSection = section
                            }
                        } label: {
                            HStack(spacing: 11) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(model.selectedSection == section ? .cyan.opacity(0.16) : .white.opacity(0.035))
                                    Image(systemName: section.symbol)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(model.selectedSection == section ? .cyan : .white.opacity(0.55))
                                }
                                .frame(width: 32, height: 32)

                                Text(section.rawValue)
                                    .font(.system(size: 12, weight: model.selectedSection == section ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(model.selectedSection == section ? .white : .white.opacity(0.64))
                                Spacer()
                                if model.selectedSection == section {
                                    Circle()
                                        .fill(.cyan)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: .cyan.opacity(0.7), radius: 7)
                                }
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                model.selectedSection == section ? .white.opacity(0.085) : .clear,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isLiveRunning && section != .live)
                        .opacity(model.isLiveRunning && section != .live ? 0.35 : 1)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Spacer(minLength: 4)

            MixPilotGlassCard(cornerRadius: 14, padding: 12, accent: model.isLiveRunning ? .green : .cyan) {
                VStack(alignment: .leading, spacing: 8) {
                    MixPilotStatusBadge(
                        title: model.isLiveRunning ? "Autopilot actif" : "Système prêt",
                        symbol: model.isLiveRunning ? "bolt.circle.fill" : "checkmark.circle.fill",
                        accent: model.isLiveRunning ? .green : .cyan
                    )
                    Text(model.snapshot.statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 86)
        }
        .padding(8)
        .frame(width: 242)
        .background(.black.opacity(0.16))
    }

    private var softwareSymbol: String {
        switch selectedSoftware {
        case .serato: "music.note.list"
        case .djay: "wand.and.stars.inverse"
        case .rekordbox: "record.circle"
        }
    }
}

private struct PremiumPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
                .padding(28)
                .padding(.bottom, 100)
                .frame(maxWidth: 1_220, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.hidden)
    }
}

private struct PremiumOnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PremiumPage {
            VStack(alignment: .leading, spacing: 22) {
                MixPilotSectionHero(
                    eyebrow: "Première mise en route",
                    title: "Configurer MixPilot",
                    subtitle: "Un parcours guidé pour connecter le logiciel DJ, le MIDI, l’audio et la bibliothèque de secours.",
                    symbol: "wand.and.stars",
                    accent: .purple
                ) {
                    Button("Actualiser") { model.refreshEnvironment() }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                    PremiumSetupStep(number: 1, title: "Logiciel DJ", detail: model.seratoStatus, symbol: "music.note.list", accent: .purple)
                    PremiumSetupStep(number: 2, title: "Accessibilité", detail: model.accessibilityStatus, symbol: "hand.raised.fill", accent: .cyan)
                    PremiumSetupStep(number: 3, title: "Contrôleur MIDI", detail: model.midiStatus, symbol: "slider.horizontal.3", accent: .blue)
                    PremiumSetupStep(number: 4, title: "Surveillance audio", detail: model.audioStatus, symbol: "waveform", accent: .mint)
                    PremiumSetupStep(number: 5, title: "Musique de secours", detail: model.emergencyStatus, symbol: "lifepreserver.fill", accent: .orange)
                    PremiumSetupStep(number: 6, title: "Préflight", detail: model.preflightReport.canStartLive ? "Prêt pour le Live" : "Vérifications requises", symbol: "checkmark.shield.fill", accent: model.preflightReport.canStartLive ? .green : .yellow)
                }

                HStack(alignment: .top, spacing: 16) {
                    MixPilotGlassCard(accent: .cyan) {
                        VStack(alignment: .leading, spacing: 14) {
                            MixPilotPanelTitle(title: "Permissions système", symbol: "hand.raised.square.fill", subtitle: "Nécessaires pour observer et piloter le logiciel DJ.")
                            Text("MixPilot n’envoie aucune commande tant que le Live ou les tests ne sont pas explicitement armés.")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.58))
                            Button("Demander l’accès Accessibilité") { model.requestAccessibility() }
                                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .cyan))
                        }
                    }

                    MixPilotGlassCard(accent: .purple) {
                        VStack(alignment: .leading, spacing: 14) {
                            MixPilotPanelTitle(title: "Finaliser", symbol: "checkmark.seal.fill", subtitle: "Tu pourras modifier chaque réglage plus tard.", accent: .purple)
                            Text("Une fois terminé, MixPilot ouvre le Studio pour préparer ton premier set.")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.58))
                            Button("TERMINER LA CONFIGURATION") { model.completeOnboarding() }
                                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                        }
                    }
                }
            }
        }
    }
}

private struct PremiumSetupStep: View {
    let number: Int
    let title: String
    let detail: String
    let symbol: String
    let accent: Color

    var body: some View {
        MixPilotGlassCard(cornerRadius: 17, padding: 16, accent: accent) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(accent.opacity(0.14))
                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                }
                .frame(width: 38, height: 38)

                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
                Spacer()
            }
        }
    }
}

private struct PremiumDashboardView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PremiumPage {
            VStack(alignment: .leading, spacing: 22) {
                MixPilotSectionHero(
                    eyebrow: "Vue globale",
                    title: "Tableau de bord",
                    subtitle: "L’état du système, du set et des sécurités essentielles avant de passer en Live.",
                    symbol: "rectangle.grid.2x2.fill",
                    accent: .cyan
                ) {
                    Button("Actualiser") { model.refreshEnvironment() }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    Button(model.isRunningSimulation ? "Simulation…" : "Tester 50 titres") { model.runSimulation() }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .cyan))
                        .disabled(model.isRunningSimulation)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 14)], spacing: 14) {
                    MixPilotMetricTile(title: "Logiciel DJ", value: model.seratoStatus, symbol: "music.note.list", accent: .purple)
                    MixPilotMetricTile(title: "MIDI", value: model.midiStatus, symbol: "slider.horizontal.3", accent: .blue)
                    MixPilotMetricTile(title: "Audio", value: model.audioStatus, symbol: "waveform", accent: .mint, detail: audioLevelText)
                    MixPilotMetricTile(title: "Internet", value: networkText, symbol: "network", accent: .cyan)
                    MixPilotMetricTile(title: "Alimentation", value: powerText, symbol: "bolt.fill", accent: .yellow)
                    MixPilotMetricTile(title: "Secours", value: model.emergencyStatus, symbol: "lifepreserver.fill", accent: .orange)
                }

                HStack(alignment: .top, spacing: 16) {
                    if let project = model.preparedProject {
                        PremiumProjectSummary(project: project)
                    } else {
                        MixPilotGlassCard(accent: .purple) {
                            VStack(alignment: .leading, spacing: 14) {
                                MixPilotPanelTitle(title: "Aucun set préparé", symbol: "music.note.list", subtitle: "Commence dans le Studio.", accent: .purple)
                                Text("Importe une playlist ou crée un set de démonstration pour générer la timeline, les analyses et les transitions.")
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.55))
                                Button("OUVRIR LE STUDIO") { model.selectedSection = .studio }
                                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                            }
                        }
                    }

                    PremiumSimulationCard(model: model)
                }

                PremiumPreflightSummary(report: model.preflightReport) {
                    model.selectedSection = .preflight
                }
            }
        }
    }

    private var networkText: String {
        model.connectivityStatus.isAvailable ? model.connectivityStatus.interfaceDescription : "Indisponible"
    }

    private var powerText: String {
        if model.powerStatus.connectedToPower { return "Branché au secteur" }
        if let level = model.powerStatus.batteryLevel { return "Batterie \(Int(level * 100)) %" }
        return "État inconnu"
    }

    private var audioLevelText: String {
        model.audioLevelDB > -150 ? String(format: "%.1f dB", model.audioLevelDB) : "Aucun signal mesuré"
    }
}

private struct PremiumSimulationCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        MixPilotGlassCard(accent: model.report?.succeeded == true ? .green : .blue) {
            VStack(alignment: .leading, spacing: 14) {
                MixPilotPanelTitle(title: "Validation automatique", symbol: "gauge.with.dots.needle.67percent", subtitle: model.snapshot.statusMessage, accent: model.report?.succeeded == true ? .green : .blue)
                ProgressView(value: model.snapshot.progress)
                    .tint(model.report?.succeeded == true ? .green : .cyan)
                if let report = model.report {
                    HStack {
                        MixPilotStatusBadge(
                            title: report.succeeded ? "Simulation réussie" : "À corriger",
                            symbol: report.succeeded ? "checkmark.seal.fill" : "xmark.octagon.fill",
                            accent: report.succeeded ? .green : .red
                        )
                        Spacer()
                        Text("\(report.completedTransitions)/\(report.transitionCount)")
                            .font(.title2.bold().monospacedDigit())
                    }
                } else {
                    Text("Lance une simulation pour vérifier les transitions, les incidents et les mécanismes de récupération.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.52))
                }
            }
        }
    }
}

private struct PremiumProjectSummary: View {
    let project: SetProject

    var body: some View {
        MixPilotGlassCard(accent: project.locked ? .green : .purple) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    MixPilotPanelTitle(title: "Plan de set", symbol: "point.topleft.down.to.point.bottomright.curvepath", subtitle: project.name, accent: .purple)
                    MixPilotStatusBadge(
                        title: project.locked ? "Verrouillé" : "Brouillon",
                        symbol: project.locked ? "lock.fill" : "lock.open",
                        accent: project.locked ? .green : .orange
                    )
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 115), spacing: 10)], spacing: 10) {
                    miniMetric("\(project.tracks.count)", "Titres", "music.note.list")
                    miniMetric("\(project.transitions.count)", "Transitions", "arrow.left.arrow.right")
                    miniMetric(premiumDurationText(project.duration), "Durée", "clock")
                    miniMetric("\(project.reviewTransitionCount)", "À vérifier", "exclamationmark.triangle")
                }
            }
        }
    }

    private func miniMetric(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbol).foregroundStyle(.cyan)
            Text(value).font(.title3.bold().monospacedDigit())
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.38))
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct PremiumStudioView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTransitionIndex = 0

    var body: some View {
        PremiumPage {
            VStack(alignment: .leading, spacing: 22) {
                MixPilotSectionHero(
                    eyebrow: "Préparation musicale",
                    title: "Studio",
                    subtitle: "Construis le set, inspecte les transitions et verrouille le plan avant le Préflight.",
                    symbol: "waveform.path.ecg",
                    accent: .purple
                ) {
                    Button("Set de démonstration") { model.createDemoProject() }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    Button("CAPTURER LA PLAYLIST") { model.captureSeratoPlaylist() }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                }

                if let project = model.preparedProject {
                    PremiumProjectSummary(project: project)

                    MixPilotGlassCard(accent: .cyan) {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                MixPilotPanelTitle(title: "Timeline du set", symbol: "timeline.selection", subtitle: "Clique sur une transition pour l’inspecter.")
                                Spacer()
                                Button(project.locked ? "Plan verrouillé" : "Verrouiller le plan") { model.lockPreparedProject() }
                                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: project.locked ? .green : .cyan))
                                    .disabled(project.locked)
                            }
                            PremiumTimelineStrip(
                                timeline: SetTimeline(project: project),
                                selectedTransitionIndex: $selectedTransitionIndex
                            )
                            .frame(height: 178)
                        }
                    }

                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 16) {
                            if let optimization = model.optimizationReport {
                                MixPilotGlassCard(accent: .mint) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        MixPilotPanelTitle(title: "Optimisation", symbol: "sparkles", subtitle: "Non destructive", accent: .mint)
                                        HStack {
                                            scoreTile("\(Int(optimization.originalAverageConfidence.rounded())) %", "Confiance")
                                            scoreTile("\(optimization.weakestTransitionConfidence) %", "Plus faible")
                                        }
                                        ForEach(optimization.suggestions.prefix(5)) { suggestion in
                                            Label("\(suggestion.explanation) (+\(suggestion.improvement))", systemImage: "lightbulb.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.65))
                                        }
                                    }
                                }
                            }

                            if !model.playlistWarnings.isEmpty {
                                MixPilotGlassCard(accent: .orange) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        MixPilotPanelTitle(title: "Avertissements d’import", symbol: "exclamationmark.triangle.fill", subtitle: "\(model.playlistWarnings.count) élément(s)", accent: .orange)
                                        ForEach(model.playlistWarnings.prefix(8)) { warning in
                                            Text("Ligne \(warning.rowIndex + 1) • \(warning.message)")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.58))
                                        }
                                    }
                                }
                            }

                            MixPilotGlassCard(accent: .purple) {
                                VStack(alignment: .leading, spacing: 12) {
                                    MixPilotPanelTitle(title: "Étape suivante", symbol: "checkmark.shield", subtitle: project.locked ? "Le plan peut être contrôlé." : "Verrouille le plan avant le Live.", accent: .purple)
                                    Button("OUVRIR LE PRÉFLIGHT") {
                                        model.evaluatePreflight()
                                        model.selectedSection = .preflight
                                    }
                                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                                }
                            }
                        }
                        .frame(width: 330)

                        if let inspection = TransitionInspection(project: project, transitionIndex: selectedTransitionIndex) {
                            PremiumTransitionInspector(inspection: inspection, isLocked: project.locked)
                                .id(inspection.plan.id)
                        } else {
                            MixPilotGlassCard {
                                ContentUnavailableView("Aucune transition", systemImage: "arrow.left.arrow.right")
                                    .frame(maxWidth: .infinity, minHeight: 260)
                            }
                        }
                    }
                } else {
                    MixPilotGlassCard(accent: .purple) {
                        VStack(spacing: 18) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 52, weight: .light))
                                .foregroundStyle(.purple)
                            Text("Aucun set préparé")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                            Text("Capture une playlist dans ton logiciel DJ ou crée un set de démonstration pour découvrir le Studio.")
                                .foregroundStyle(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 520)
                            HStack {
                                Button("SET DE DÉMONSTRATION") { model.createDemoProject() }
                                    .buttonStyle(MixPilotSecondaryButtonStyle())
                                Button("CAPTURER LA PLAYLIST") { model.captureSeratoPlaylist() }
                                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 330)
                    }
                }
            }
        }
    }

    private func scoreTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold().monospacedDigit())
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct PremiumTimelineStrip: View {
    let timeline: SetTimeline
    @Binding var selectedTransitionIndex: Int

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(timeline.segments) { segment in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("#\(segment.index + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(.cyan)
                            Spacer()
                            Text(String(format: "%.0f BPM", segment.preparedTrack.track.bpm))
                                .font(.caption2.bold().monospacedDigit())
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        Text(segment.preparedTrack.track.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(segment.preparedTrack.track.artist)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                        Spacer()
                        HStack {
                            Text(premiumTimeText(segment.startTime))
                            Spacer()
                            Text(premiumDurationText(segment.duration))
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(13)
                    .frame(width: min(260, max(170, CGFloat(segment.duration / 1.35))), height: 145)
                    .background(
                        LinearGradient(
                            colors: [.white.opacity(0.085), .purple.opacity(0.05), .cyan.opacity(0.035)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    }

                    if let transition = segment.transitionAfter {
                        Button {
                            selectedTransitionIndex = segment.index
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title2)
                                Text(transition.kind.rawValue)
                                    .font(.caption2.bold())
                                    .lineLimit(2)
                                    .frame(width: 82)
                                Text("\(transition.confidence) %")
                                    .font(.caption2.monospacedDigit())
                            }
                            .foregroundStyle(selectedTransitionIndex == segment.index ? .cyan : .white.opacity(0.46))
                            .padding(.horizontal, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct PremiumTransitionInspector: View {
    let inspection: TransitionInspection
    let isLocked: Bool

    var body: some View {
        MixPilotGlassCard(accent: .blue) {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    MixPilotPanelTitle(title: "Inspecteur de transition", symbol: "arrow.left.arrow.right.circle.fill", subtitle: inspection.plan.kind.rawValue, accent: .blue)
                    MixPilotStatusBadge(
                        title: "Confiance \(inspection.plan.confidence) %",
                        symbol: "checkmark.shield.fill",
                        accent: inspection.plan.confidence >= 75 ? .green : .orange
                    )
                }

                HStack(spacing: 12) {
                    inspectorTrack("SORTANT", inspection.outgoing, accent: .purple)
                    Image(systemName: "arrow.right")
                        .font(.title2.bold())
                        .foregroundStyle(.cyan)
                    inspectorTrack("ENTRANT", inspection.incoming, accent: .cyan)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 10)], spacing: 10) {
                    compactMetric("Risque", inspection.riskLevel, "exclamationmark.triangle")
                    compactMetric("Durée", "\(inspection.plan.bars) mesure(s)", "metronome")
                    compactMetric("Tempo cible", String(format: "%.1f BPM", inspection.plan.targetBPM), "speedometer")
                    compactMetric("Points MIX", "\(inspection.mixOutMarker.map { premiumTimeText($0.time) } ?? "—") → \(inspection.mixInMarker.map { premiumTimeText($0.time) } ?? "—")", "mappin.and.ellipse")
                }

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AUTOMATIONS")
                            .font(.caption2.bold())
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.38))
                        ForEach(inspection.plan.lanes, id: \.target.rawValue) { lane in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(lane.target.rawValue).font(.caption.bold())
                                    Spacer()
                                    Text("\(lane.points.count) pts").font(.caption2).foregroundStyle(.secondary)
                                }
                                PremiumAutomationPreview(lane: lane)
                                    .frame(height: 30)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 9) {
                        Text("RECOMMANDATIONS")
                            .font(.caption2.bold())
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.38))
                        ForEach(inspection.recommendations, id: \.self) { recommendation in
                            Label(recommendation, systemImage: "lightbulb.fill")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        if isLocked {
                            MixPilotStatusBadge(title: "Plan verrouillé", symbol: "lock.fill", accent: .green)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func inspectorTrack(_ label: String, _ prepared: PreparedTrack, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(accent)
            Text(prepared.track.title).font(.headline).lineLimit(2)
            Text(prepared.track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            HStack {
                Text(String(format: "%.1f BPM", prepared.track.bpm)).monospacedDigit()
                Spacer()
                Text("\(Int(prepared.analysis.overallConfidence * 100)) %")
            }
            .font(.caption2.bold())
            .foregroundStyle(.white.opacity(0.48))
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(accent.opacity(0.075), in: RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).stroke(accent.opacity(0.16), lineWidth: 1) }
    }

    private func compactMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                Text(value).font(.caption.bold()).lineLimit(2)
            }
            Spacer()
        }
        .padding(10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct PremiumAutomationPreview: View {
    let lane: AutomationLane

    var body: some View {
        GeometryReader { geometry in
            let maximumBeat = max(1, lane.points.map(\.beat).max() ?? 1)
            Path { path in
                for (index, point) in lane.points.enumerated() {
                    let x = geometry.size.width * point.beat / maximumBeat
                    let y = geometry.size.height * (1 - point.value)
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(
                LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
        }
        .padding(5)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct PremiumMappingView: View {
    @ObservedObject var model: AppModel
    @StateObject private var session: MappingAssistantSession

    init(model: AppModel) {
        self.model = model
        _session = StateObject(wrappedValue: MappingAssistantSession(profile: model.mappingProfile))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                mappingSidebar
                Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
                mappingDetail
            }
            .padding(.bottom, 86)
        }
    }

    private var mappingSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("MIDI MAPPING")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.blue)
                Text("Assistant")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text("\(session.completedCount)/\(session.totalCount) commandes confirmées")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))
            }

            ProgressView(value: session.progress)
                .tint(.cyan)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(MappingActionGroup.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(group.rawValue.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(0.34))
                                .padding(.horizontal, 7)
                            ForEach(session.state.steps.filter { $0.action.mappingGroup == group }) { step in
                                Button {
                                    session.jump(to: step.action)
                                } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: step.testSucceeded == true ? "checkmark.circle.fill" : step.testSucceeded == false ? "xmark.circle.fill" : "circle")
                                            .foregroundStyle(step.testSucceeded == true ? .green : step.testSucceeded == false ? .red : .white.opacity(0.35))
                                        Text(step.action.displayName)
                                            .font(.caption.bold())
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 8)
                                    .background(
                                        session.currentStep?.action == step.action ? .white.opacity(0.095) : .clear,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            HStack {
                Button("Réinitialiser") { session.reset(profile: model.mappingProfile) }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                Button("Sauvegarder") { model.saveMapping() }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .blue))
            }
        }
        .padding(22)
        .frame(width: 300)
        .background(.black.opacity(0.13))
    }

    @ViewBuilder
    private var mappingDetail: some View {
        if let step = session.currentStep {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MixPilotSectionHero(
                        eyebrow: step.action.mappingGroup.rawValue,
                        title: step.action.displayName,
                        subtitle: step.action.mappingInstruction,
                        symbol: "slider.horizontal.3",
                        accent: .blue
                    ) { EmptyView() }

                    HStack(alignment: .top, spacing: 16) {
                        MixPilotGlassCard(accent: .blue) {
                            VStack(alignment: .leading, spacing: 14) {
                                MixPilotPanelTitle(title: "Message MIDI", symbol: "dot.radiowaves.left.and.right", subtitle: "Valeurs envoyées par MixPilot", accent: .blue)
                                mappingValue("Type", step.mapping.kind == .note ? "Note" : "Control Change")
                                mappingValue("Canal", "\(Int(step.mapping.channel) + 1)")
                                mappingValue("Numéro", "\(step.mapping.number)")
                                mappingValue("Plage", "\(step.mapping.minimumRawValue)–\(step.mapping.maximumRawValue)")
                            }
                        }

                        MixPilotGlassCard(accent: .purple) {
                            VStack(alignment: .leading, spacing: 14) {
                                MixPilotPanelTitle(title: "Validation réelle", symbol: "checkmark.seal.fill", subtitle: "Confirme seulement après avoir observé le logiciel DJ.", accent: .purple)
                                Text(model.midiStatus)
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(session.status)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.45))
                                Button("ENVOYER LE TEST") { model.testMapping(step.action) }
                                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                                HStack {
                                    Button("Ça fonctionne") { session.record(succeeded: true) }
                                        .buttonStyle(MixPilotSecondaryButtonStyle())
                                    Button("À remapper") { session.record(succeeded: false) }
                                        .buttonStyle(MixPilotDangerButtonStyle())
                                }
                            }
                        }
                    }

                    HStack {
                        Button("Précédent") { session.movePrevious() }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                            .disabled(session.state.currentIndex == 0)
                        Spacer()
                        Text("Étape \(session.state.currentIndex + 1) sur \(session.totalCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.42))
                        Spacer()
                        Button("Suivant") { session.moveNext() }
                            .buttonStyle(MixPilotPrimaryButtonStyle(accent: .blue))
                            .disabled(session.state.currentIndex >= session.totalCount - 1)
                    }
                }
                .padding(28)
                .padding(.bottom, 90)
                .frame(maxWidth: 920, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
            .id(step.action.id)
        } else {
            ContentUnavailableView("Aucune commande", systemImage: "slider.horizontal.3")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func mappingValue(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.white.opacity(0.46))
            Spacer()
            Text(value).font(.headline.monospacedDigit())
        }
        .padding(10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct PremiumPreflightView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PremiumPage {
            VStack(alignment: .leading, spacing: 22) {
                MixPilotSectionHero(
                    eyebrow: "Contrôle avant départ",
                    title: "Préflight",
                    subtitle: "Le Live reste bloqué tant qu’un contrôle critique échoue.",
                    symbol: "checkmark.shield.fill",
                    accent: model.preflightReport.canStartLive ? .green : .orange
                ) {
                    Button("RELANCER LES VÉRIFICATIONS") {
                        model.refreshEnvironment()
                        model.evaluatePreflight()
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: model.preflightReport.canStartLive ? .green : .orange))
                }

                PremiumPreflightSummary(report: model.preflightReport) {
                    if model.preflightReport.canStartLive { model.selectedSection = .live }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 14)], spacing: 14) {
                    ForEach(model.preflightReport.items) { item in
                        PremiumPreflightItem(item: item)
                    }
                }

                MixPilotGlassCard(accent: .purple) {
                    VStack(alignment: .leading, spacing: 14) {
                        MixPilotPanelTitle(title: "Actions correctives", symbol: "wrench.and.screwdriver.fill", subtitle: "Les raccourcis les plus utiles pour débloquer le Live.", accent: .purple)
                        HStack {
                            Button("Autoriser l’Accessibilité") { model.requestAccessibility() }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                            Button("Démarrer l’audio") { model.startAudioMonitoring() }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                            Button("Choisir le secours") { model.selectEmergencyAudio() }
                                .buttonStyle(MixPilotSecondaryButtonStyle())
                            Button("Ouvrir le mapping MIDI") { model.selectedSection = .mapping }
                                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                        }
                    }
                }
            }
        }
    }
}

private struct PremiumPreflightSummary: View {
    let report: PreflightReport
    let action: () -> Void

    var body: some View {
        MixPilotGlassCard(accent: report.canStartLive ? .green : .red) {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(.white.opacity(0.08), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: completion)
                        .stroke(report.canStartLive ? .green : .orange, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(completion * 100)) %")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 6) {
                    MixPilotStatusBadge(
                        title: report.canStartLive ? "Prêt pour le Live" : "Live bloqué",
                        symbol: report.canStartLive ? "checkmark.shield.fill" : "xmark.shield.fill",
                        accent: report.canStartLive ? .green : .red
                    )
                    Text(report.canStartLive ? "Toutes les sécurités critiques sont validées." : "Corrige les contrôles en échec avant d’armer l’Autopilot.")
                        .font(.headline)
                    Text("\(report.failedItems.count) échec(s) • \(report.warningItems.count) avertissement(s)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if report.canStartLive {
                    Button("PASSER AU LIVE", action: action)
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                }
            }
        }
    }

    private var completion: Double {
        guard !report.items.isEmpty else { return 0 }
        let passed = report.items.filter { $0.status == .passed }.count
        let warnings = report.items.filter { $0.status == .warning }.count
        return min(1, (Double(passed) + Double(warnings) * 0.55) / Double(report.items.count))
    }
}

private struct PremiumPreflightItem: View {
    let item: PreflightItem

    var body: some View {
        MixPilotGlassCard(cornerRadius: 16, padding: 15, accent: accent) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.14))
                    Image(systemName: symbol)
                        .foregroundStyle(accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title).font(.headline)
                        Spacer()
                        Text(item.status.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                    }
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private var accent: Color {
        switch item.status {
        case .passed: .green
        case .warning: .orange
        case .failed: .red
        case .notTested: .gray
        }
    }

    private var symbol: String {
        switch item.status {
        case .passed: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .notTested: "clock.fill"
        }
    }
}

private struct PremiumLiveView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PremiumPage {
            VStack(alignment: .leading, spacing: 20) {
                MixPilotSectionHero(
                    eyebrow: "Performance sécurisée",
                    title: "Mode Live",
                    subtitle: "Console temps réel, surveillance audio et reprise manuelle immédiate.",
                    symbol: "play.circle.fill",
                    accent: model.isLiveRunning ? .green : .red
                ) {
                    MixPilotStatusBadge(
                        title: model.isLiveRunning ? "Autopilot actif" : model.liveArmed ? "Live armé" : "Live désarmé",
                        symbol: model.isLiveRunning ? "bolt.fill" : model.liveArmed ? "lock.shield.fill" : "lock.open",
                        accent: model.isLiveRunning ? .green : model.liveArmed ? .orange : .gray
                    )
                    Button("Préflight") { model.selectedSection = .preflight }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                }

                HStack(spacing: 16) {
                    PremiumDeckCard(
                        label: "DECK \(model.snapshot.activeDeck.rawValue)",
                        status: "EN COURS",
                        track: model.snapshot.currentTrack,
                        accent: .purple,
                        active: true
                    )
                    ZStack {
                        Circle().fill(.white.opacity(0.06))
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.title2.bold())
                            .foregroundStyle(.cyan)
                    }
                    .frame(width: 54, height: 54)
                    PremiumDeckCard(
                        label: "DECK \(model.snapshot.activeDeck.opposite.rawValue)",
                        status: "PROCHAIN",
                        track: model.snapshot.nextTrack,
                        accent: .cyan,
                        active: false
                    )
                }

                MixPilotGlassCard(accent: model.isLiveRunning ? .green : .red) {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.snapshot.statusMessage)
                                    .font(.title3.bold())
                                Text("\(model.snapshot.completedTransitions)/\(model.snapshot.totalTransitions) transitions")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Text("\(Int(model.snapshot.progress * 100)) %")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        ProgressView(value: model.snapshot.progress)
                            .tint(model.isLiveRunning ? .green : .cyan)
                            .scaleEffect(y: 1.7)

                        HStack(spacing: 12) {
                            Toggle("Armer le Live", isOn: Binding(
                                get: { model.liveArmed },
                                set: { _ in model.armLive() }
                            ))
                            .toggleStyle(.switch)
                            .tint(.orange)

                            Button(model.isLiveRunning ? "LIVE EN COURS" : "DÉMARRER LE SET") { model.startLive() }
                                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                                .disabled(model.isLiveRunning || !model.liveArmed || !model.preflightReport.canStartLive)

                            Button("Tester le secours") { model.playEmergencyAudio() }
                                .buttonStyle(MixPilotSecondaryButtonStyle())

                            Spacer()

                            Button("REPRENDRE LE CONTRÔLE") { model.takeManualControl() }
                                .buttonStyle(MixPilotDangerButtonStyle())
                        }
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    PremiumPreflightSummary(report: model.preflightReport) {
                        model.selectedSection = .preflight
                    }

                    MixPilotGlassCard(accent: .blue) {
                        VStack(alignment: .leading, spacing: 12) {
                            MixPilotPanelTitle(title: "Journal Live", symbol: "list.bullet.rectangle.fill", subtitle: "Événements les plus récents", accent: .blue)
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 7) {
                                    ForEach(Array(model.runtimeEvents.suffix(100).enumerated()), id: \.offset) { _, event in
                                        HStack(alignment: .top, spacing: 8) {
                                            Circle().fill(.cyan.opacity(0.8)).frame(width: 5, height: 5).padding(.top, 5)
                                            Text(event)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.white.opacity(0.58))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    if model.runtimeEvents.isEmpty {
                                        Text("Le journal apparaîtra au démarrage du set.")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }
                            }
                            .frame(minHeight: 150, maxHeight: 230)
                        }
                    }
                }
            }
        }
    }
}

private struct PremiumDeckCard: View {
    let label: String
    let status: String
    let track: Track?
    let accent: Color
    let active: Bool

    var body: some View {
        MixPilotGlassCard(cornerRadius: 22, padding: 20, accent: accent) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    MixPilotStatusBadge(title: label, symbol: "record.circle", accent: accent)
                    Spacer()
                    if active {
                        HStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { index in
                                Capsule()
                                    .fill(accent.opacity(0.45 + Double(index) * 0.1))
                                    .frame(width: 3, height: CGFloat(9 + index * 3))
                            }
                        }
                    }
                    Text(status)
                        .font(.caption2.bold())
                        .foregroundStyle(active ? .green : .white.opacity(0.45))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(track?.title ?? "Aucun titre")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(track?.artist ?? "—")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                HStack {
                    Label(track.map { String(format: "%.1f BPM", $0.bpm) } ?? "— BPM", systemImage: "metronome")
                    Spacer()
                    Text(track?.profile.rawValue ?? "—")
                }
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
        }
    }
}

private struct PremiumFeasibilityView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PremiumPage {
            VStack(alignment: .leading, spacing: 22) {
                MixPilotSectionHero(
                    eyebrow: "Validation technique",
                    title: "Feasibility Lab",
                    subtitle: "Ce qui est automatisé, ce qui est observé et ce qui doit encore être validé sur le matériel réel.",
                    symbol: "checklist.checked",
                    accent: .blue
                ) {
                    Button("Actualiser") { model.refreshEnvironment() }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .blue))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                    PremiumValidationCard(name: "Moteur et transitions", status: "AUTOMATED_SUCCESS", validated: true, symbol: "gearshape.2.fill")
                    PremiumValidationCard(name: "Simulation 50 titres", status: model.report?.succeeded == true ? "AUTOMATED_SUCCESS" : "À lancer", validated: model.report?.succeeded == true, symbol: "gauge.with.dots.needle.67percent")
                    PremiumValidationCard(name: "Port MIDI", status: model.midiStatus, validated: model.midiStatus.lowercased().contains("actif"), symbol: "slider.horizontal.3")
                    PremiumValidationCard(name: "Logiciel DJ réel", status: model.seratoStatus, validated: model.seratoStatus.lowercased().contains("détecté"), symbol: "music.note.list")
                    PremiumValidationCard(name: "Bibliothèque", status: "\(model.libraryRowCount) lignes", validated: model.libraryRowCount > 0, symbol: "books.vertical.fill")
                    PremiumValidationCard(name: "Capture audio", status: model.audioStatus, validated: model.audioStatus.lowercased().contains("active"), symbol: "waveform")
                    PremiumValidationCard(name: "Secours local 30 min", status: model.emergencyStatus, validated: model.emergencyDuration >= 1_800, symbol: "lifepreserver.fill")
                    PremiumValidationCard(name: "Préflight", status: model.preflightReport.canStartLive ? "READY_FOR_LIVE" : "BLOCKED", validated: model.preflightReport.canStartLive, symbol: "checkmark.shield.fill")
                }

                MixPilotGlassCard(accent: .orange) {
                    VStack(alignment: .leading, spacing: 12) {
                        MixPilotPanelTitle(title: "Règle de validation", symbol: "exclamationmark.shield.fill", subtitle: "Une CI verte ne remplace pas un test réel.", accent: .orange)
                        Text("Les actions MIDI, l’observation Accessibilité et le comportement du logiciel DJ doivent être validés sur le Mac cible avec une playlist de test avant une prestation publique.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
            }
        }
    }
}

private struct PremiumValidationCard: View {
    let name: String
    let status: String
    let validated: Bool
    let symbol: String

    var body: some View {
        MixPilotGlassCard(cornerRadius: 17, padding: 16, accent: validated ? .green : .orange) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill((validated ? Color.green : Color.orange).opacity(0.13))
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(validated ? .green : .orange)
                }
                .frame(width: 43, height: 43)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.headline)
                    Text(status)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(2)
                }
                Spacer()
                MixPilotStatusBadge(
                    title: validated ? "Validé" : "À valider",
                    symbol: validated ? "checkmark.circle.fill" : "clock.badge.exclamationmark",
                    accent: validated ? .green : .orange
                )
            }
        }
    }
}

private struct PremiumDiagnosticsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PremiumPage {
            VStack(alignment: .leading, spacing: 22) {
                MixPilotSectionHero(
                    eyebrow: "Observabilité",
                    title: "Diagnostics",
                    subtitle: "Inspecte l’environnement et exporte un rapport expurgé de toute donnée sensible.",
                    symbol: "stethoscope",
                    accent: .mint
                ) {
                    Button("EXPORTER LE DIAGNOSTIC") { model.exportDiagnostics() }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .mint))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                    MixPilotMetricTile(title: "Logiciel DJ", value: model.seratoStatus, symbol: "music.note.list", accent: .purple)
                    MixPilotMetricTile(title: "MIDI", value: model.midiStatus, symbol: "slider.horizontal.3", accent: .blue)
                    MixPilotMetricTile(title: "Accessibilité", value: model.accessibilityStatus, symbol: "hand.raised.fill", accent: .cyan)
                    MixPilotMetricTile(title: "Audio", value: model.audioStatus, symbol: "waveform", accent: .mint)
                    MixPilotMetricTile(title: "Réseau", value: model.connectivityStatus.isAvailable ? model.connectivityStatus.interfaceDescription : "Indisponible", symbol: "network", accent: .cyan)
                    MixPilotMetricTile(title: "Secours", value: model.emergencyStatus, symbol: "lifepreserver.fill", accent: .orange)
                }

                HStack(alignment: .top, spacing: 16) {
                    MixPilotGlassCard(accent: .green) {
                        VStack(alignment: .leading, spacing: 12) {
                            MixPilotPanelTitle(title: "État de validation", symbol: "checkmark.seal.fill", subtitle: "Sources automatiques et validations terrain.", accent: .green)
                            validationLine("Moteur Core", "AUTOMATED_SUCCESS", .green)
                            validationLine("Simulation 50 titres", model.report?.succeeded == true ? "AUTOMATED_SUCCESS" : "NOT_RUN_IN_APP", model.report?.succeeded == true ? .green : .orange)
                            validationLine("Build macOS", "CI_VALIDATED", .green)
                            validationLine("Contrôle réel", "REQUIRES_DEVICE_VALIDATION", .orange)
                            validationLine("Streaming", "CONTROLLED_BY_DJ_BACKEND", .blue)
                            validationLine("DMG", "CI_PACKAGED", .green)
                        }
                    }

                    MixPilotGlassCard(accent: .blue) {
                        VStack(alignment: .leading, spacing: 12) {
                            MixPilotPanelTitle(title: "Journal Runtime", symbol: "terminal.fill", subtitle: "Derniers événements de l’Autopilot.", accent: .blue)
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 7) {
                                    ForEach(Array(model.runtimeEvents.suffix(80).enumerated()), id: \.offset) { _, event in
                                        Text(event)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.white.opacity(0.55))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    if model.runtimeEvents.isEmpty {
                                        Text("Aucun événement Runtime enregistré.")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }
                            }
                            .frame(minHeight: 170, maxHeight: 260)
                        }
                    }
                }

                PremiumPreflightSummary(report: model.preflightReport) {
                    model.selectedSection = .preflight
                }
            }
        }
    }

    private func validationLine(_ name: String, _ status: String, _ accent: Color) -> some View {
        HStack {
            Circle().fill(accent).frame(width: 7, height: 7).shadow(color: accent.opacity(0.5), radius: 5)
            Text(name).font(.callout)
            Spacer()
            Text(status)
                .font(.caption2.bold().monospaced())
                .foregroundStyle(accent)
                .textSelection(.enabled)
        }
        .padding(.vertical, 3)
    }
}

private func premiumTimeText(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%02d:%02d", total / 60, total % 60)
}

private func premiumDurationText(_ seconds: TimeInterval) -> String {
    let totalMinutes = max(0, Int(seconds / 60))
    return totalMinutes >= 60
        ? "\(totalMinutes / 60) h \(totalMinutes % 60) min"
        : "\(totalMinutes) min"
}
#endif
