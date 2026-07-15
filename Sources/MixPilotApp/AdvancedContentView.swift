#if os(macOS)
import MixPilotCore
import SwiftUI

struct AdvancedContentView: View {
    @ObservedObject var model: AppModel
    @State private var section: WorkspaceSection = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(WorkspaceSection.allCases) { item in
                    Label(item.rawValue, systemImage: item.symbol)
                        .tag(item)
                }
            }
            .navigationTitle("MixPilot")
            .frame(minWidth: 210)
        } detail: {
            switch section {
            case .dashboard:
                AdvancedDashboard(model: model)
            case .studio:
                StudioWorkspace(model: model)
            case .timeline:
                TimelineWorkspace(model: model)
            case .mapping:
                MappingAssistantWorkspace(model: model)
            case .live:
                AdvancedLiveWorkspace(model: model)
            case .diagnostics:
                AdvancedDiagnosticsWorkspace(model: model)
            }
        }
        .frame(minWidth: 1_180, minHeight: 760)
    }
}

private enum WorkspaceSection: String, CaseIterable, Identifiable {
    case dashboard = "Tableau de bord"
    case studio = "Préparation"
    case timeline = "Timeline & transitions"
    case mapping = "Assistant MIDI"
    case live = "Live"
    case diagnostics = "Diagnostics"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard: "rectangle.grid.2x2"
        case .studio: "music.note.list"
        case .timeline: "timeline.selection"
        case .mapping: "slider.horizontal.3"
        case .live: "play.circle.fill"
        case .diagnostics: "stethoscope"
        }
    }
}

private struct AdvancedDashboard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WorkspaceHeader(
                    title: "MixPilot Autopilot",
                    subtitle: "Préparation automatique, contrôle Serato et sécurité d’un set sans surveillance."
                ) {
                    Button("Actualiser") {
                        model.refreshEnvironment()
                        model.evaluatePreflight()
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    MetricCard(title: "Serato", value: model.seratoStatus, icon: "music.note.list")
                    MetricCard(title: "MIDI", value: model.midiStatus, icon: "slider.horizontal.3")
                    MetricCard(title: "Audio", value: model.audioStatus, icon: "waveform")
                    MetricCard(title: "Internet", value: model.connectivityStatus.isAvailable ? model.connectivityStatus.interfaceDescription : "Indisponible", icon: "network")
                    MetricCard(title: "Alimentation", value: powerText(model.powerStatus.connectedToPower, level: model.powerStatus.batteryLevel), icon: "bolt.fill")
                    MetricCard(title: "Secours", value: model.emergencyStatus, icon: "lifepreserver")
                }

                if let project = model.preparedProject {
                    ProjectOverview(project: project)
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
                                    report.succeeded ? "Simulation réussie" : "Simulation en échec",
                                    systemImage: report.succeeded ? "checkmark.seal.fill" : "xmark.octagon.fill"
                                )
                                Text("\(report.completedTransitions)/\(report.transitionCount) transitions")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                if let preflight = model.preflightReport {
                    PreflightSummary(report: preflight)
                }
            }
            .padding(28)
        }
        .navigationTitle("Tableau de bord")
    }

    private func powerText(_ plugged: Bool, level: Double?) -> String {
        if plugged { return "Secteur" }
        if let level { return "Batterie \(Int(level * 100)) %" }
        return "Batterie"
    }
}

private struct StudioWorkspace: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(
                title: "Préparation du set",
                subtitle: "Importe l’ordre visible dans Serato, analyse les titres et verrouille le plan final."
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
                            ProjectOverview(project: project)

                            GroupBox("Actions") {
                                VStack(alignment: .leading, spacing: 10) {
                                    Button(project.locked ? "Plan verrouillé" : "Verrouiller le plan") {
                                        model.lockPreparedProject()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(project.locked)

                                    Button("Évaluer le préflight") {
                                        model.evaluatePreflight()
                                    }

                                    Text(project.locked
                                         ? "Toute modification nécessite de recréer une version du plan."
                                         : "Passe dans Timeline & transitions pour vérifier les enchaînements.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(6)
                            }

                            if !model.playlistWarnings.isEmpty {
                                GroupBox("Avertissements d’import") {
                                    VStack(alignment: .leading, spacing: 7) {
                                        ForEach(model.playlistWarnings.prefix(30)) { warning in
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
                    .frame(minWidth: 330, idealWidth: 380)

                    List(Array(project.tracks.enumerated()), id: \.element.id) { index, prepared in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text("\(index + 1). \(prepared.track.title)")
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "%.1f BPM", prepared.track.bpm))
                                    .monospacedDigit()
                            }
                            Text(prepared.track.artist)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 14) {
                                Label(prepared.track.profile.rawValue, systemImage: "music.quarternote.3")
                                Text("Analyse \(Int(prepared.analysis.overallConfidence * 100)) %")
                                if project.transitions.indices.contains(index) {
                                    let transition = project.transitions[index]
                                    Text("→ \(transition.kind.rawValue) • \(transition.confidence) %")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Aucun set préparé",
                    systemImage: "music.note.list",
                    description: Text("Ouvre la playlist dans Serato et lance la capture, ou génère un set de démonstration.")
                )
            }
        }
        .navigationTitle("Préparation")
    }
}

private struct TimelineWorkspace: View {
    @ObservedObject var model: AppModel
    @State private var selectedTransitionIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(
                title: "Timeline & inspecteur",
                subtitle: "Visualise l’ordre, les chevauchements, les cue points et le plan MIDI de chaque transition."
            ) {
                if let project = model.preparedProject {
                    Text(project.locked ? "Plan verrouillé" : "Plan modifiable")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)

            Divider()

            if let project = model.preparedProject, let timeline = model.setTimeline {
                VStack(spacing: 0) {
                    TimelineStrip(
                        timeline: timeline,
                        selectedTransitionIndex: $selectedTransitionIndex
                    )
                    .frame(height: 230)
                    .padding(20)

                    Divider()

                    if let inspection = model.transitionInspection(at: selectedTransitionIndex) {
                        TransitionInspector(
                            inspection: inspection,
                            isLocked: project.locked,
                            onApply: { kind, bars in
                                model.updateTransition(at: selectedTransitionIndex, kind: kind, bars: bars)
                            }
                        )
                        .id(inspection.plan.id)
                    } else {
                        ContentUnavailableView("Aucune transition", systemImage: "arrow.left.arrow.right")
                    }
                }
            } else {
                ContentUnavailableView(
                    "Timeline indisponible",
                    systemImage: "timeline.selection",
                    description: Text("Prépare d’abord une playlist dans l’espace Préparation.")
                )
            }
        }
        .navigationTitle("Timeline")
    }
}

private struct TimelineStrip: View {
    let timeline: SetTimeline
    @Binding var selectedTransitionIndex: Int

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: 0) {
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
                            Text(timeText(segment.startTime))
                            Spacer()
                            Text(durationText(segment.duration))
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

private struct TransitionInspector: View {
    let inspection: TransitionInspection
    let isLocked: Bool
    let onApply: (TransitionKind, Int) -> Void

    @State private var selectedKind: TransitionKind
    @State private var selectedBars: Int

    init(
        inspection: TransitionInspection,
        isLocked: Bool,
        onApply: @escaping (TransitionKind, Int) -> Void
    ) {
        self.inspection = inspection
        self.isLocked = isLocked
        self.onApply = onApply
        _selectedKind = State(initialValue: inspection.plan.kind)
        _selectedBars = State(initialValue: inspection.plan.bars)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 18) {
                    InspectorTrackCard(label: "SORTANT", prepared: inspection.outgoing)
                    Image(systemName: "arrow.right")
                        .font(.title)
                        .frame(maxHeight: .infinity)
                    InspectorTrackCard(label: "ENTRANT", prepared: inspection.incoming)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                    MetricCard(title: "Confiance", value: "\(inspection.plan.confidence) %", icon: "checkmark.shield")
                    MetricCard(title: "Risque", value: inspection.riskLevel, icon: "exclamationmark.triangle")
                    MetricCard(title: "Tempo cible", value: String(format: "%.1f BPM", inspection.plan.targetBPM), icon: "metronome")
                    MetricCard(title: "Points MIX", value: markerText(inspection.mixOutMarker, inspection.mixInMarker), icon: "mappin.and.ellipse")
                }

                GroupBox("Réglage de la transition") {
                    HStack(spacing: 20) {
                        Picker("Type", selection: $selectedKind) {
                            ForEach(TransitionKind.allCases, id: \.self) { kind in
                                Text(kind.rawValue).tag(kind)
                            }
                        }
                        .frame(width: 260)

                        Stepper("\(selectedBars) mesure(s)", value: $selectedBars, in: 1...32)
                            .frame(width: 180)

                        Button("Appliquer") {
                            onApply(selectedKind, selectedBars)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLocked)

                        if isLocked {
                            Label("Plan verrouillé", systemImage: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(6)
                }

                HStack(alignment: .top, spacing: 18) {
                    GroupBox("Courbes d’automation") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(inspection.plan.lanes, id: \.target.rawValue) { lane in
                                HStack {
                                    Text(lane.target.rawValue)
                                        .font(.callout.bold())
                                    Spacer()
                                    Text("\(lane.points.count) points")
                                        .foregroundStyle(.secondary)
                                }
                                AutomationLanePreview(lane: lane)
                                    .frame(height: 34)
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
                        }
                        .padding(6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
    }

    private func markerText(_ out: CueMarker?, _ input: CueMarker?) -> String {
        "\(out.map { timeText($0.time) } ?? "—") → \(input.map { timeText($0.time) } ?? "—")"
    }
}

private struct InspectorTrackCard: View {
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

private struct AutomationLanePreview: View {
    let lane: AutomationLane

    var body: some View {
        GeometryReader { geometry in
            let maxBeat = max(1, lane.points.map(\.beat).max() ?? 1)
            Path { path in
                for (index, point) in lane.points.enumerated() {
                    let x = geometry.size.width * point.beat / maxBeat
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

private struct MappingAssistantWorkspace: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(
                title: "Assistant de mapping MIDI",
                subtitle: "Associe chaque commande de Serato au port MixPilot et confirme son comportement réel."
            ) {
                Button("Recommencer") { model.beginMappingWizard() }
                Button("Sauvegarder le profil") { model.saveMapping() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)

            ProgressView(value: model.mappingWizard.progress) {
                Text("\(model.mappingWizard.completedStepCount)/\(model.mappingWizard.steps.count) commandes confirmées")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 14)

            Divider()

            HSplitView {
                List(selection: Binding(
                    get: { model.mappingWizard.currentStep?.action },
                    set: { action in if let action { model.jumpMappingWizard(to: action) } }
                )) {
                    ForEach(MappingActionGroup.allCases, id: \.self) { group in
                        Section(group.rawValue) {
                            ForEach(model.mappingWizard.steps.filter { $0.action.mappingGroup == group }) { step in
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
                .frame(minWidth: 260, idealWidth: 310)

                if let step = model.mappingWizard.currentStep {
                    MappingStepEditor(model: model, step: step)
                        .id(step.action.id + "-\(step.mapping.number)-\(step.mapping.channel)")
                } else {
                    ContentUnavailableView("Aucune commande", systemImage: "slider.horizontal.3")
                }
            }
        }
        .navigationTitle("Assistant MIDI")
        .onAppear {
            if model.mappingWizard.steps.isEmpty { model.beginMappingWizard() }
        }
    }
}

private struct MappingStepEditor: View {
    @ObservedObject var model: AppModel
    let step: MappingWizardStep

    @State private var kind: MIDIMessageKind
    @State private var channel: Int
    @State private var number: Int
    @State private var minimum: Int
    @State private var maximum: Int
    @State private var momentary: Bool

    init(model: AppModel, step: MappingWizardStep) {
        self.model = model
        self.step = step
        _kind = State(initialValue: step.mapping.kind)
        _channel = State(initialValue: Int(step.mapping.channel))
        _number = State(initialValue: Int(step.mapping.number))
        _minimum = State(initialValue: Int(step.mapping.minimumRawValue))
        _maximum = State(initialValue: Int(step.mapping.maximumRawValue))
        _momentary = State(initialValue: step.mapping.isMomentary)
    }

    var body: some View {
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

                GroupBox("Message MIDI") {
                    Form {
                        Picker("Type", selection: $kind) {
                            Text("Note").tag(MIDIMessageKind.note)
                            Text("Control Change").tag(MIDIMessageKind.controlChange)
                        }
                        Stepper("Canal \(channel + 1)", value: $channel, in: 0...15)
                        Stepper("Numéro \(number)", value: $number, in: 0...127)
                        Stepper("Minimum \(minimum)", value: $minimum, in: 0...127)
                        Stepper("Maximum \(maximum)", value: $maximum, in: 0...127)
                        Toggle("Commande momentanée", isOn: $momentary)
                    }
                    .formStyle(.grouped)
                    .frame(minHeight: 235)
                }

                HStack {
                    Button("Appliquer ces valeurs") {
                        model.updateCurrentMapping(
                            kind: kind,
                            channel: channel,
                            number: number,
                            minimum: minimum,
                            maximum: maximum,
                            momentary: momentary
                        )
                    }
                    Button("Envoyer le test") {
                        model.updateCurrentMapping(
                            kind: kind,
                            channel: channel,
                            number: number,
                            minimum: minimum,
                            maximum: maximum,
                            momentary: momentary
                        )
                        model.testCurrentMappingStep()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Ça fonctionne") { model.markCurrentMappingConfirmed(true) }
                    Button("À remapper", role: .destructive) { model.markCurrentMappingConfirmed(false) }
                }

                Text(model.mappingWizardStatus)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Précédent") { model.moveMappingWizardPrevious() }
                        .disabled(model.mappingWizard.currentIndex == 0)
                    Spacer()
                    Text("Étape \(model.mappingWizard.currentIndex + 1) / \(model.mappingWizard.steps.count)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Suivant") { model.moveMappingWizardNext() }
                        .disabled(model.mappingWizard.currentIndex >= model.mappingWizard.steps.count - 1)
                }
            }
            .padding(28)
        }
    }
}

private struct AdvancedLiveWorkspace: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkspaceHeader(
                    title: "Mode Live",
                    subtitle: "Le démarrage reste bloqué tant que le préflight n’est pas entièrement sûr."
                ) {
                    Button("Relancer le préflight") { model.evaluatePreflight() }
                }

                HStack(spacing: 16) {
                    LiveDeckCard(label: "DECK \(model.snapshot.activeDeck.rawValue)", status: "EN COURS", track: model.snapshot.currentTrack)
                    LiveDeckCard(label: "DECK \(model.snapshot.activeDeck.opposite.rawValue)", status: "PROCHAIN", track: model.snapshot.nextTrack)
                }

                if let report = model.preflightReport {
                    PreflightDetails(report: report)
                } else {
                    Button("Évaluer les conditions de lancement") { model.evaluatePreflight() }
                        .buttonStyle(.borderedProminent)
                }

                GroupBox("Commandes de sécurité") {
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
                        .disabled(model.isLiveRunning || !model.liveArmed || model.preflightReport?.canStartLive != true)

                        Button("Surveiller l’audio") { model.startAudioMonitoring() }
                        Button("Choisir le secours") { model.selectEmergencyAudio() }
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

private struct AdvancedDiagnosticsWorkspace: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkspaceHeader(
                    title: "Diagnostics",
                    subtitle: "Rapport anonymisable pour distinguer les validations automatiques des tests Serato réels."
                ) {
                    Button("Exporter TXT") { model.exportDiagnostics(asJSON: false) }
                    Button("Exporter JSON") { model.exportDiagnostics(asJSON: true) }
                        .buttonStyle(.borderedProminent)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                    MetricCard(title: "Serato", value: model.seratoStatus, icon: "music.note.list")
                    MetricCard(title: "MIDI", value: model.midiStatus, icon: "slider.horizontal.3")
                    MetricCard(title: "Accessibilité", value: model.accessibilityStatus, icon: "hand.raised")
                    MetricCard(title: "Audio", value: model.audioStatus, icon: "waveform")
                    MetricCard(title: "Réseau", value: model.connectivityStatus.isAvailable ? model.connectivityStatus.interfaceDescription : "Indisponible", icon: "network")
                    MetricCard(title: "Bibliothèque", value: "\(model.libraryRowCount) lignes", icon: "list.bullet.rectangle")
                }

                GroupBox("État de validation") {
                    VStack(alignment: .leading, spacing: 9) {
                        ValidationRow(name: "Moteur Core", status: "AUTOMATED_SUCCESS")
                        ValidationRow(name: "Simulation 50 titres", status: model.report?.succeeded == true ? "AUTOMATED_SUCCESS" : "NOT_RUN_IN_APP")
                        ValidationRow(name: "Build macOS", status: "CI_VALIDATED")
                        ValidationRow(name: "Contrôle réel Serato", status: "REQUIRES_SERATO_VALIDATION")
                        ValidationRow(name: "Spotify", status: "CONTROLLED_BY_SERATO")
                        ValidationRow(name: "DMG", status: "DEFERRED_UNTIL_RELEASE_CANDIDATE")
                    }
                    .padding(6)
                }

                if let preflight = model.preflightReport {
                    PreflightDetails(report: preflight)
                }

                GroupBox("Aperçu du rapport") {
                    Text(model.makeDiagnosticReport().plainText())
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }

                Text(model.diagnosticsStatus)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
        }
        .navigationTitle("Diagnostics")
    }
}

private struct WorkspaceHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let actions: Actions

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

private struct MetricCard: View {
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

private struct ProjectOverview: View {
    let project: SetProject

    var body: some View {
        GroupBox("Plan de set") {
            VStack(alignment: .leading, spacing: 10) {
                Text(project.name).font(.headline)
                HStack(spacing: 16) {
                    Label("\(project.tracks.count) titres", systemImage: "music.note.list")
                    Label("\(project.transitions.count) transitions", systemImage: "arrow.left.arrow.right")
                    Label(durationText(project.duration), systemImage: "clock")
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

private struct LiveDeckCard: View {
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

private struct PreflightSummary: View {
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

private struct PreflightDetails: View {
    let report: PreflightReport

    var body: some View {
        GroupBox(report.canStartLive ? "Préflight validé" : "Préflight bloquant") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(report.items) { item in
                    HStack(alignment: .top) {
                        Image(systemName: icon(item.status))
                            .frame(width: 22)
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

    private func icon(_ status: PreflightItemStatus) -> String {
        switch status {
        case .passed: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .notTested: "clock.fill"
        }
    }
}

private struct ValidationRow: View {
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

private func timeText(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%02d:%02d", total / 60, total % 60)
}

private func durationText(_ seconds: TimeInterval) -> String {
    let totalMinutes = max(0, Int(seconds / 60))
    return totalMinutes >= 60
        ? "\(totalMinutes / 60) h \(totalMinutes % 60) min"
        : "\(totalMinutes) min"
}
#endif
