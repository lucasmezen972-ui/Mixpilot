#if os(macOS)
import MixPilotCore
import SwiftUI

struct AdvancedContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedSection) {
                ForEach(SidebarSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.symbol)
                        .tag(section)
                }
            }
            .navigationTitle("MixPilot")
            .frame(minWidth: 215)
        } detail: {
            switch model.selectedSection {
            case .onboarding:
                FinalOnboardingView(model: model)
            case .dashboard:
                FinalDashboardView(model: model)
            case .studio:
                FinalStudioView(model: model)
            case .mapping:
                FinalMappingView(model: model)
            case .preflight:
                FinalPreflightView(model: model)
            case .live:
                FinalLiveView(model: model)
            case .feasibility:
                FinalFeasibilityView(model: model)
            case .diagnostics:
                FinalDiagnosticsView(model: model)
            }
        }
        .frame(minWidth: 1_180, minHeight: 760)
        .onAppear {
            if !model.hasCompletedOnboarding {
                model.selectedSection = .onboarding
            }
        }
    }
}

private struct FinalOnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FinalHeader(
                    title: "Configurer MixPilot",
                    subtitle: "Les réglages manuels ne seront demandés qu’une fois, au moment des tests réels sur le Mac."
                ) { EmptyView() }

                OnboardingStep(number: 1, title: "Serato DJ Pro", detail: model.seratoStatus, icon: "music.note.list")
                OnboardingStep(number: 2, title: "Permission Accessibilité", detail: model.accessibilityStatus, icon: "hand.raised")
                OnboardingStep(number: 3, title: "Port MIDI virtuel", detail: model.midiStatus, icon: "slider.horizontal.3")
                OnboardingStep(number: 4, title: "Surveillance audio", detail: model.audioStatus, icon: "waveform")
                OnboardingStep(number: 5, title: "Bibliothèque de secours", detail: model.emergencyStatus, icon: "lifepreserver")

                HStack {
                    Button("Demander l’accès Accessibilité") { model.requestAccessibility() }
                    Button("Actualiser") { model.refreshEnvironment() }
                    Button("Terminer la configuration") { model.completeOnboarding() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(32)
            .frame(maxWidth: 850, alignment: .leading)
        }
        .navigationTitle("Configuration")
    }
}

private struct FinalDashboardView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FinalHeader(
                    title: "MixPilot Autopilot",
                    subtitle: "Préparer, valider et exécuter un set autonome dans Serato DJ Pro."
                ) {
                    Button("Actualiser") { model.refreshEnvironment() }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    FinalMetricCard(title: "Serato", value: model.seratoStatus, icon: "music.note.list")
                    FinalMetricCard(title: "MIDI", value: model.midiStatus, icon: "slider.horizontal.3")
                    FinalMetricCard(title: "Audio", value: model.audioStatus, icon: "waveform")
                    FinalMetricCard(title: "Internet", value: networkText(model), icon: "network")
                    FinalMetricCard(title: "Alimentation", value: powerText(model), icon: "bolt.fill")
                    FinalMetricCard(title: "Secours", value: model.emergencyStatus, icon: "lifepreserver")
                }

                if let project = model.preparedProject {
                    FinalProjectSummary(project: project)
                }

                GroupBox("Validation automatique") {
                    VStack(alignment: .leading, spacing: 12) {
                        ProgressView(value: model.snapshot.progress) {
                            Text(model.snapshot.statusMessage)
                        }
                        HStack {
                            Button(model.isRunningSimulation ? "Simulation en cours…" : "Tester 50 titres") {
                                model.runSimulation()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isRunningSimulation)

                            if let report = model.report {
                                Label(
                                    report.succeeded ? "Simulation réussie" : "Simulation à corriger",
                                    systemImage: report.succeeded ? "checkmark.seal.fill" : "xmark.octagon.fill"
                                )
                                Text("\(report.completedTransitions)/\(report.transitionCount) transitions")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                FinalPreflightSummary(report: model.preflightReport)
            }
            .padding(28)
        }
        .navigationTitle("Tableau de bord")
    }

    private func networkText(_ model: AppModel) -> String {
        model.connectivityStatus.isAvailable
            ? model.connectivityStatus.interfaceDescription
            : "Indisponible"
    }

    private func powerText(_ model: AppModel) -> String {
        if model.powerStatus.connectedToPower { return "Secteur" }
        if let level = model.powerStatus.batteryLevel { return "Batterie \(Int(level * 100)) %" }
        return "Batterie"
    }
}

private struct FinalStudioView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTransitionIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            FinalHeader(
                title: "Studio de préparation",
                subtitle: "Import, analyse, optimisation, timeline et inspection des transitions."
            ) {
                Button("Set de démonstration") { model.createDemoProject() }
                Button("Capturer la playlist Serato") { model.captureSeratoPlaylist() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)

            Divider()

            if let project = model.preparedProject {
                HSplitView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            FinalProjectSummary(project: project)

                            GroupBox("Actions") {
                                VStack(alignment: .leading, spacing: 10) {
                                    Button(project.locked ? "Plan verrouillé" : "Verrouiller le plan") {
                                        model.lockPreparedProject()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(project.locked)

                                    Button("Ouvrir le préflight") {
                                        model.selectedSection = .preflight
                                        model.evaluatePreflight()
                                    }

                                    Text(project.locked
                                         ? "Le plan est figé pour éviter une modification accidentelle avant le Live."
                                         : "Inspecte les transitions avant de verrouiller le plan.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(6)
                            }

                            if let optimization = model.optimizationReport {
                                GroupBox("Optimisation non destructive") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Confiance moyenne : \(Int(optimization.originalAverageConfidence.rounded())) %")
                                        Text("Transition la plus faible : \(optimization.weakestTransitionConfidence) %")
                                        ForEach(optimization.suggestions.prefix(6)) { suggestion in
                                            Label(
                                                "\(suggestion.explanation) (+\(suggestion.improvement))",
                                                systemImage: "lightbulb"
                                            )
                                            .font(.caption)
                                        }
                                    }
                                    .padding(6)
                                }
                            }

                            if !model.playlistWarnings.isEmpty {
                                GroupBox("Avertissements d’import") {
                                    VStack(alignment: .leading, spacing: 7) {
                                        ForEach(model.playlistWarnings.prefix(20)) { warning in
                                            Label(
                                                "Ligne \(warning.rowIndex + 1) : \(warning.message)",
                                                systemImage: "exclamationmark.triangle"
                                            )
                                            .font(.caption)
                                        }
                                    }
                                    .padding(6)
                                }
                            }
                        }
                        .padding(22)
                    }
                    .frame(minWidth: 330, idealWidth: 370)

                    VStack(spacing: 0) {
                        FinalTimelineStrip(
                            timeline: SetTimeline(project: project),
                            selectedTransitionIndex: $selectedTransitionIndex
                        )
                        .frame(height: 230)
                        .padding(18)

                        Divider()

                        if let inspection = TransitionInspection(
                            project: project,
                            transitionIndex: selectedTransitionIndex
                        ) {
                            FinalTransitionInspector(inspection: inspection, isLocked: project.locked)
                                .id(inspection.plan.id)
                        } else {
                            ContentUnavailableView("Aucune transition", systemImage: "arrow.left.arrow.right")
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Aucun set préparé",
                    systemImage: "music.note.list",
                    description: Text("Ouvre la playlist voulue dans Serato puis lance la capture, ou génère un set de démonstration.")
                )
            }
        }
        .navigationTitle("Studio")
    }
}

private struct FinalTimelineStrip: View {
    let timeline: SetTimeline
    @Binding var selectedTransitionIndex: Int

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(timeline.segments) { segment in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("#\(segment.index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(segment.preparedTrack.track.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(segment.preparedTrack.track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack {
                            Text(finalTimeText(segment.startTime))
                            Spacer()
                            Text(finalDurationText(segment.duration))
                        }
                        .font(.caption.monospacedDigit())
                    }
                    .padding(14)
                    .frame(width: segmentWidth(segment.duration), height: 150)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        Text(String(format: "%.0f BPM", segment.preparedTrack.track.bpm))
                            .font(.caption2.bold())
                            .padding(7)
                    }

                    if let transition = segment.transitionAfter {
                        Button {
                            selectedTransitionIndex = segment.index
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title2)
                                Text(transition.kind.rawValue)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .frame(width: 90)
                                Text("\(transition.confidence) %")
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 8)
                            .foregroundStyle(selectedTransitionIndex == segment.index ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func segmentWidth(_ duration: TimeInterval) -> CGFloat {
        min(300, max(175, CGFloat(duration / 1.25)))
    }
}

private struct FinalTransitionInspector: View {
    let inspection: TransitionInspection
    let isLocked: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 18) {
                    FinalInspectorTrack(label: "SORTANT", prepared: inspection.outgoing)
                    Image(systemName: "arrow.right").font(.title)
                    FinalInspectorTrack(label: "ENTRANT", prepared: inspection.incoming)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                    FinalMetricCard(title: "Type", value: inspection.plan.kind.rawValue, icon: "arrow.left.arrow.right")
                    FinalMetricCard(title: "Confiance", value: "\(inspection.plan.confidence) %", icon: "checkmark.shield")
                    FinalMetricCard(title: "Risque", value: inspection.riskLevel, icon: "exclamationmark.triangle")
                    FinalMetricCard(title: "Durée", value: "\(inspection.plan.bars) mesure(s)", icon: "metronome")
                    FinalMetricCard(title: "Tempo cible", value: String(format: "%.1f BPM", inspection.plan.targetBPM), icon: "speedometer")
                    FinalMetricCard(
                        title: "Points MIX",
                        value: "\(inspection.mixOutMarker.map { finalTimeText($0.time) } ?? "—") → \(inspection.mixInMarker.map { finalTimeText($0.time) } ?? "—")",
                        icon: "mappin.and.ellipse"
                    )
                }

                HStack(alignment: .top, spacing: 18) {
                    GroupBox("Courbes d’automation") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(inspection.plan.lanes, id: \.target.rawValue) { lane in
                                HStack {
                                    Text(lane.target.rawValue).font(.callout.bold())
                                    Spacer()
                                    Text("\(lane.points.count) points").foregroundStyle(.secondary)
                                }
                                FinalAutomationPreview(lane: lane).frame(height: 34)
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxWidth: .infinity)

                    GroupBox("Recommandations") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(inspection.recommendations, id: \.self) { recommendation in
                                Label(recommendation, systemImage: "lightbulb")
                                    .font(.callout)
                            }
                            if isLocked {
                                Label("Plan verrouillé", systemImage: "lock.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(22)
        }
    }
}

private struct FinalMappingView: View {
    @ObservedObject var model: AppModel
    @StateObject private var session: MappingAssistantSession

    init(model: AppModel) {
        self.model = model
        _session = StateObject(wrappedValue: MappingAssistantSession(profile: model.mappingProfile))
    }

    var body: some View {
        VStack(spacing: 0) {
            FinalHeader(
                title: "Assistant de mapping MIDI",
                subtitle: "Serato apprend chaque message envoyé par MixPilot ; confirme ensuite que la commande a bien réagi."
            ) {
                Button("Réinitialiser les validations") { session.reset(profile: model.mappingProfile) }
                Button("Sauvegarder le profil") { model.saveMapping() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)

            ProgressView(value: session.progress) {
                Text("\(session.completedCount)/\(session.totalCount) commandes confirmées")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 14)

            Divider()

            HSplitView {
                List(selection: Binding(
                    get: { session.currentStep?.action },
                    set: { action in if let action { session.jump(to: action) } }
                )) {
                    ForEach(MappingActionGroup.allCases, id: \.self) { group in
                        Section(group.rawValue) {
                            ForEach(session.state.steps.filter { $0.action.mappingGroup == group }) { step in
                                HStack {
                                    Image(systemName: step.testSucceeded == true
                                          ? "checkmark.circle.fill"
                                          : step.testSucceeded == false ? "xmark.circle.fill" : "circle")
                                    Text(step.action.displayName)
                                }
                                .tag(step.action)
                            }
                        }
                    }
                }
                .frame(minWidth: 265, idealWidth: 310)

                if let step = session.currentStep {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            Text(step.action.mappingGroup.rawValue.uppercased())
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(step.action.displayName)
                                .font(.largeTitle.bold())
                            Text(step.action.mappingInstruction)
                                .font(.title3)
                                .foregroundStyle(.secondary)

                            GroupBox("Message envoyé") {
                                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                                    GridRow { Text("Type"); Text(step.mapping.kind == .note ? "Note" : "Control Change") }
                                    GridRow { Text("Canal"); Text("\(Int(step.mapping.channel) + 1)") }
                                    GridRow { Text("Numéro"); Text("\(step.mapping.number)") }
                                    GridRow { Text("Plage"); Text("\(step.mapping.minimumRawValue)–\(step.mapping.maximumRawValue)") }
                                }
                                .padding(8)
                            }

                            HStack {
                                Button("Envoyer le test") { model.testMapping(step.action) }
                                    .buttonStyle(.borderedProminent)
                                Button("Ça fonctionne") { session.record(succeeded: true) }
                                Button("À remapper", role: .destructive) { session.record(succeeded: false) }
                            }

                            Text(model.midiStatus).foregroundStyle(.secondary)
                            Text(session.status).foregroundStyle(.secondary)

                            HStack {
                                Button("Précédent") { session.movePrevious() }
                                    .disabled(session.state.currentIndex == 0)
                                Spacer()
                                Button("Suivant") { session.moveNext() }
                                    .disabled(session.state.currentIndex >= session.totalCount - 1)
                            }
                        }
                        .padding(28)
                    }
                    .id(step.action.id)
                } else {
                    ContentUnavailableView("Aucune commande", systemImage: "slider.horizontal.3")
                }
            }
        }
        .navigationTitle("Mapping MIDI")
    }
}

private struct FinalPreflightView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FinalHeader(
                    title: "Préflight",
                    subtitle: "Le Live reste bloqué tant qu’un contrôle critique échoue."
                ) {
                    Button("Relancer les vérifications") {
                        model.refreshEnvironment()
                        model.evaluatePreflight()
                    }
                    .buttonStyle(.borderedProminent)
                }

                FinalPreflightDetails(report: model.preflightReport)

                HStack {
                    Button("Demander l’accès Accessibilité") { model.requestAccessibility() }
                    Button("Démarrer la surveillance audio") { model.startAudioMonitoring() }
                    Button("Choisir le secours") { model.selectEmergencyAudio() }
                    Button("Ouvrir l’assistant MIDI") { model.selectedSection = .mapping }
                }
            }
            .padding(28)
        }
        .navigationTitle("Préflight")
    }
}

private struct FinalLiveView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FinalHeader(
                    title: "Mode Live",
                    subtitle: "Exécution du plan verrouillé, surveillance audio et reprise manuelle immédiate."
                ) {
                    Button("Préflight") { model.selectedSection = .preflight }
                }

                HStack(spacing: 16) {
                    FinalDeckCard(label: "DECK \(model.snapshot.activeDeck.rawValue)", status: "EN COURS", track: model.snapshot.currentTrack)
                    FinalDeckCard(label: "DECK \(model.snapshot.activeDeck.opposite.rawValue)", status: "PROCHAIN", track: model.snapshot.nextTrack)
                }

                FinalPreflightSummary(report: model.preflightReport)

                GroupBox("Commandes") {
                    HStack {
                        Toggle("Armer le Live", isOn: Binding(
                            get: { model.liveArmed },
                            set: { _ in model.armLive() }
                        ))
                        .toggleStyle(.switch)

                        Button(model.isLiveRunning ? "Live en cours…" : "DÉMARRER LE SET") {
                            model.startLive()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isLiveRunning || !model.liveArmed || !model.preflightReport.canStartLive)

                        Button("Tester le secours") { model.playEmergencyAudio() }
                        Spacer()
                        Button("REPRENDRE LE CONTRÔLE", role: .destructive) {
                            model.takeManualControl()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(6)
                }

                ProgressView(value: model.snapshot.progress) {
                    Text(model.snapshot.statusMessage)
                }

                GroupBox("Journal Live") {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(model.runtimeEvents.enumerated()), id: \.offset) { _, event in
                                Text(event).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                }
            }
            .padding(28)
        }
        .navigationTitle("Live")
    }
}

private struct FinalFeasibilityView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FinalHeader(
                    title: "Feasibility Lab",
                    subtitle: "Les validations automatiques restent séparées des futurs tests Serato réels."
                ) {
                    Button("Actualiser") { model.refreshEnvironment() }
                }

                FinalValidationCard(name: "Moteur et transitions", status: "AUTOMATED_SUCCESS", validated: true)
                FinalValidationCard(name: "Simulation 50 titres", status: model.report?.succeeded == true ? "AUTOMATED_SUCCESS" : "À lancer", validated: model.report?.succeeded == true)
                FinalValidationCard(name: "Port MIDI", status: model.midiStatus, validated: model.midiStatus.contains("actif"))
                FinalValidationCard(name: "Serato réel", status: model.seratoStatus, validated: model.seratoStatus.contains("détecté"))
                FinalValidationCard(name: "Bibliothèque Serato", status: "\(model.libraryRowCount) lignes", validated: model.libraryRowCount > 0)
                FinalValidationCard(name: "Capture audio réelle", status: model.audioStatus, validated: model.audioStatus.contains("active"))
                FinalValidationCard(name: "Secours local 30 min", status: model.emergencyStatus, validated: model.emergencyDuration >= 1_800)
            }
            .padding(28)
        }
        .navigationTitle("Feasibility Lab")
    }
}

private struct FinalDiagnosticsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FinalHeader(
                    title: "Diagnostics",
                    subtitle: "Exporte un rapport JSON et Markdown expurgé de toute donnée sensible."
                ) {
                    Button("Exporter le diagnostic…") { model.exportDiagnostics() }
                        .buttonStyle(.borderedProminent)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                    FinalMetricCard(title: "Serato", value: model.seratoStatus, icon: "music.note.list")
                    FinalMetricCard(title: "MIDI", value: model.midiStatus, icon: "slider.horizontal.3")
                    FinalMetricCard(title: "Accessibilité", value: model.accessibilityStatus, icon: "hand.raised")
                    FinalMetricCard(title: "Audio", value: model.audioStatus, icon: "waveform")
                    FinalMetricCard(title: "Réseau", value: model.connectivityStatus.isAvailable ? model.connectivityStatus.interfaceDescription : "Indisponible", icon: "network")
                    FinalMetricCard(title: "Secours", value: model.emergencyStatus, icon: "lifepreserver")
                }

                GroupBox("État de validation") {
                    VStack(alignment: .leading, spacing: 9) {
                        FinalValidationLine(name: "Moteur Core", status: "AUTOMATED_SUCCESS")
                        FinalValidationLine(name: "Simulation 50 titres", status: model.report?.succeeded == true ? "AUTOMATED_SUCCESS" : "NOT_RUN_IN_APP")
                        FinalValidationLine(name: "Build macOS", status: "CI_VALIDATED")
                        FinalValidationLine(name: "Contrôle réel Serato", status: "REQUIRES_SERATO_VALIDATION")
                        FinalValidationLine(name: "Spotify", status: "CONTROLLED_BY_SERATO")
                        FinalValidationLine(name: "DMG", status: "DEFERRED_UNTIL_RELEASE_CANDIDATE")
                    }
                    .padding(6)
                }

                FinalPreflightDetails(report: model.preflightReport)
            }
            .padding(28)
        }
        .navigationTitle("Diagnostics")
    }
}

private struct FinalHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    let actions: Actions

    init(title: String, subtitle: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.largeTitle.bold())
                Text(subtitle).foregroundStyle(.secondary)
            }
            Spacer()
            HStack { actions }
        }
    }
}

private struct FinalMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        GroupBox {
            HStack(spacing: 13) {
                Image(systemName: icon).font(.title2).frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.headline).lineLimit(2)
                }
                Spacer()
            }
            .padding(7)
        }
    }
}

private struct FinalProjectSummary: View {
    let project: SetProject

    var body: some View {
        GroupBox("Plan de set") {
            VStack(alignment: .leading, spacing: 10) {
                Text(project.name).font(.headline)
                HStack(spacing: 14) {
                    Label("\(project.tracks.count) titres", systemImage: "music.note.list")
                    Label("\(project.transitions.count) transitions", systemImage: "arrow.left.arrow.right")
                    Label(finalDurationText(project.duration), systemImage: "clock")
                    Label("\(project.reviewTransitionCount) à vérifier", systemImage: "exclamationmark.triangle")
                    Spacer()
                    Label(project.locked ? "Verrouillé" : "Brouillon", systemImage: project.locked ? "lock.fill" : "lock.open")
                }
                .foregroundStyle(.secondary)
            }
            .padding(7)
        }
    }
}

private struct FinalInspectorTrack: View {
    let label: String
    let prepared: PreparedTrack

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(label).font(.caption.bold()).foregroundStyle(.secondary)
                Text(prepared.track.title).font(.title3.bold())
                Text(prepared.track.artist).foregroundStyle(.secondary)
                HStack {
                    Label(String(format: "%.1f BPM", prepared.track.bpm), systemImage: "metronome")
                    Label(prepared.track.profile.rawValue, systemImage: "music.quarternote.3")
                    Spacer()
                    Text("Analyse \(Int(prepared.analysis.overallConfidence * 100)) %")
                }
                .font(.caption)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FinalAutomationPreview: View {
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
            .stroke(.primary, lineWidth: 2)
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct FinalDeckCard: View {
    let label: String
    let status: String
    let track: Track?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(label).font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    Text(status).font(.caption.bold())
                }
                Text(track?.title ?? "Aucun titre").font(.title2.bold())
                Text(track?.artist ?? "—").foregroundStyle(.secondary)
                HStack {
                    Label(track.map { String(format: "%.1f BPM", $0.bpm) } ?? "— BPM", systemImage: "metronome")
                    Spacer()
                    Text(track?.profile.rawValue ?? "—")
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FinalPreflightSummary: View {
    let report: PreflightReport

    var body: some View {
        GroupBox("Préflight") {
            HStack {
                Label(
                    report.canStartLive ? "Prêt pour le Live" : "Live bloqué",
                    systemImage: report.canStartLive ? "checkmark.shield.fill" : "xmark.shield.fill"
                )
                Spacer()
                Text("\(report.failedItems.count) échec(s) • \(report.warningItems.count) avertissement(s)")
                    .foregroundStyle(.secondary)
            }
            .padding(7)
        }
    }
}

private struct FinalPreflightDetails: View {
    let report: PreflightReport

    var body: some View {
        GroupBox(report.canStartLive ? "Préflight validé" : "Préflight bloquant") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(report.items) { item in
                    HStack(alignment: .top) {
                        Image(systemName: preflightIcon(item.status)).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.headline)
                            Text(item.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.status.rawValue.uppercased()).font(.caption.bold())
                    }
                }
            }
            .padding(7)
        }
    }

    private func preflightIcon(_ status: PreflightItemStatus) -> String {
        switch status {
        case .passed: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .notTested: "clock.fill"
        }
    }
}

private struct FinalValidationCard: View {
    let name: String
    let status: String
    let validated: Bool

    var body: some View {
        HStack {
            Image(systemName: validated ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                .font(.title2)
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(status).foregroundStyle(.secondary)
            }
            Spacer()
            Text(validated ? "VALIDÉ" : "À VALIDER").font(.caption.bold())
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct FinalValidationLine: View {
    let name: String
    let status: String

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(status).font(.caption.bold()).textSelection(.enabled)
        }
    }
}

private struct OnboardingStep: View {
    let number: Int
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(.quaternary, in: Circle())
            Image(systemName: icon).font(.title2).frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }
}

private func finalTimeText(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%02d:%02d", total / 60, total % 60)
}

private func finalDurationText(_ seconds: TimeInterval) -> String {
    let totalMinutes = max(0, Int(seconds / 60))
    return totalMinutes >= 60
        ? "\(totalMinutes / 60) h \(totalMinutes % 60) min"
        : "\(totalMinutes) min"
}
#endif
