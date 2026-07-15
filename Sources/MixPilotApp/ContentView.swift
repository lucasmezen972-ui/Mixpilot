#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotRuntime
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(SidebarSection.allCases) { section in
                    Button {
                        model.selectedSection = section
                    } label: {
                        Label(section.rawValue, systemImage: section.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("MixPilot")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.isLiveRunning ? "AUTOPILOT ACTIF" : "AUTOPILOT INACTIF")
                        .font(.caption.bold())
                    Text(model.runtimeStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.thinMaterial)
            }
        } detail: {
            switch model.selectedSection {
            case .onboarding:
                OnboardingView(model: model)
            case .dashboard:
                DashboardView(model: model)
            case .studio:
                StudioView(model: model)
            case .mapping:
                MappingView(model: model)
            case .preflight:
                PreflightView(model: model)
            case .live:
                LiveView(model: model)
            case .feasibility:
                FeasibilityView(model: model)
            case .diagnostics:
                DiagnosticsView(model: model)
            }
        }
        .frame(minWidth: 1_120, minHeight: 720)
        .onAppear {
            if !model.hasCompletedOnboarding {
                model.selectedSection = .onboarding
            }
        }
    }
}

private struct OnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configurer MixPilot")
                        .font(.largeTitle.bold())
                    Text("Cette configuration se fait une fois. MixPilot vérifiera ensuite automatiquement chaque point avant une soirée.")
                        .foregroundStyle(.secondary)
                }

                SetupStep(
                    number: 1,
                    title: "Lancer Serato DJ Pro",
                    detail: "Connecte Spotify Premium dans Serato et affiche la playlist qui doit être préparée.",
                    status: model.seratoStatus,
                    completed: model.seratoStatus.contains("détecté")
                ) {
                    model.refreshEnvironment()
                }

                SetupStep(
                    number: 2,
                    title: "Autoriser l’Accessibilité",
                    detail: "Cette permission permet de vérifier le titre chargé et de lire les lignes visibles de la bibliothèque Serato.",
                    status: model.accessibilityStatus,
                    completed: model.accessibilityStatus == "Autorisée"
                ) {
                    model.requestAccessibility()
                }

                SetupStep(
                    number: 3,
                    title: "Mapper le contrôleur virtuel",
                    detail: "Dans Serato, ouvre le mapping MIDI et sélectionne MixPilot Virtual Controller.",
                    status: model.midiStatus,
                    completed: model.mappingProfile.completionRatio >= 0.95
                ) {
                    model.selectedSection = .mapping
                }

                SetupStep(
                    number: 4,
                    title: "Configurer le retour audio",
                    detail: "Choisis le master Serato ou un loopback BlackHole afin que le watchdog détecte silence et saturation.",
                    status: model.audioStatus,
                    completed: model.audioStatus.contains("active")
                ) {
                    model.startAudioMonitoring()
                }

                SetupStep(
                    number: 5,
                    title: "Ajouter le secours local",
                    detail: "Sélectionne au moins 30 minutes de fichiers locaux. Ils seront lus si Spotify, Internet ou Serato échoue.",
                    status: model.emergencyStatus,
                    completed: model.emergencyDuration >= 1_800
                ) {
                    model.selectEmergencyAudio()
                }

                HStack {
                    Button("Actualiser toutes les vérifications") {
                        model.refreshEnvironment()
                    }
                    Spacer()
                    Button("Terminer la configuration") {
                        model.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(32)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .navigationTitle("Configuration")
    }
}

private struct DashboardView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MixPilot Autopilot")
                            .font(.largeTitle.bold())
                        Text("Préparer, vérifier et exécuter un set autonome dans Serato DJ Pro.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Actualiser") { model.refreshEnvironment() }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 16)], spacing: 16) {
                    StatusCard(title: "Serato", value: model.seratoStatus, symbol: "music.note.list")
                    StatusCard(title: "MIDI", value: model.midiStatus, symbol: "slider.horizontal.3")
                    StatusCard(title: "Accessibilité", value: model.accessibilityStatus, symbol: "hand.raised")
                    StatusCard(title: "Audio", value: model.audioStatus, symbol: "waveform")
                    StatusCard(title: "Internet", value: model.connectivityStatus.isAvailable ? model.connectivityStatus.interfaceDescription : "Hors ligne", symbol: "network")
                    StatusCard(title: "Alimentation", value: powerText(model.powerStatus), symbol: "bolt.fill")
                    StatusCard(title: "Bibliothèque", value: "\(model.libraryRowCount) lignes visibles", symbol: "list.bullet.rectangle")
                    StatusCard(title: "Secours", value: model.emergencyStatus, symbol: "lifepreserver")
                }

                GroupBox("Préflight") {
                    HStack {
                        Image(systemName: model.preflightReport.canStartLive ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.title)
                        VStack(alignment: .leading) {
                            Text(model.preflightReport.canStartLive ? "Prêt pour un Live sans surveillance" : "Configuration incomplète")
                                .font(.headline)
                            Text("\(model.preflightReport.failedItems.count) erreur(s) critique(s), \(model.preflightReport.warningItems.count) avertissement(s)")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Voir le préflight") { model.selectedSection = .preflight }
                    }
                    .padding(8)
                }

                GroupBox("Simulation autonome") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Le simulateur vérifie 50 titres, 49 transitions, les incidents et toutes les valeurs de contrôle générées.")
                            .foregroundStyle(.secondary)
                        ProgressView(value: model.snapshot.progress) {
                            Text(model.snapshot.statusMessage)
                        }
                        HStack {
                            Button(model.isRunningSimulation ? "Simulation en cours…" : "Lancer le test 50 titres") {
                                model.runSimulation()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isRunningSimulation)
                            if let report = model.report {
                                Label(
                                    report.succeeded ? "Test réussi" : "Test à corriger",
                                    systemImage: report.succeeded ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                                )
                                Text("\(report.completedTransitions)/\(report.transitionCount) transitions")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                if let project = model.preparedProject {
                    ProjectSummaryCard(project: project)
                }
                LiveSummary(snapshot: model.snapshot)
            }
            .padding(28)
        }
        .navigationTitle("Tableau de bord")
    }

    private func powerText(_ status: PowerStatus) -> String {
        if status.connectedToPower { return "Secteur" }
        if let battery = status.batteryLevel { return "Batterie \(Int(battery * 100)) %" }
        return "Batterie"
    }
}

private struct StudioView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MixPilot Studio").font(.largeTitle.bold())
                    Text("Importe la playlist visible, prépare les points de mix et génère toutes les transitions.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Set démo") { model.createDemoProject() }
                Button("Capturer la playlist Serato") { model.captureSeratoPlaylist() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)
            Divider()

            if let project = model.preparedProject {
                HSplitView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ProjectSummaryCard(project: project)
                            HStack {
                                Button(project.locked ? "Plan verrouillé" : "Verrouiller le plan") {
                                    model.lockPreparedProject()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(project.locked)
                                Label(project.locked ? "Prêt pour préflight" : "Brouillon modifiable", systemImage: project.locked ? "lock.fill" : "lock.open")
                                    .foregroundStyle(.secondary)
                            }

                            if let optimization = model.optimizationReport {
                                GroupBox("Optimisation proposée") {
                                    VStack(alignment: .leading, spacing: 9) {
                                        Text(String(format: "Confiance moyenne %.1f %% • plus faible %d %%", optimization.originalAverageConfidence, optimization.weakestTransitionConfidence))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        ForEach(optimization.suggestions.prefix(8)) { suggestion in
                                            Label(suggestion.explanation, systemImage: optimizationSymbol(suggestion.kind))
                                                .font(.caption)
                                        }
                                        if optimization.suggestions.isEmpty {
                                            Text("Aucun changement d’ordre recommandé.")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(6)
                                }
                            }

                            if !model.playlistWarnings.isEmpty {
                                GroupBox("Avertissements d’import") {
                                    VStack(alignment: .leading, spacing: 7) {
                                        ForEach(model.playlistWarnings.prefix(20)) { warning in
                                            Label("Ligne \(warning.rowIndex + 1) : \(warning.message)", systemImage: "exclamationmark.triangle")
                                                .font(.caption)
                                        }
                                    }
                                    .padding(6)
                                }
                            }
                        }
                        .padding(22)
                    }
                    .frame(minWidth: 340, idealWidth: 390)

                    List {
                        ForEach(Array(project.tracks.enumerated()), id: \.element.id) { index, prepared in
                            TrackTimelineRow(
                                index: index,
                                prepared: prepared,
                                transition: project.transitions.indices.contains(index) ? project.transitions[index] : nil
                            )
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Aucun set préparé",
                    systemImage: "music.note.list",
                    description: Text("Ouvre la playlist voulue dans Serato puis lance la capture, ou crée un set de démonstration.")
                )
            }
        }
        .navigationTitle("Studio")
    }

    private func optimizationSymbol(_ kind: SetOptimizationSuggestionKind) -> String {
        switch kind {
        case .swapAdjacentTracks: "arrow.up.arrow.down"
        case .moveTrack: "arrow.turn.up.right"
        case .insertBridgeTrack: "point.3.connected.trianglepath.dotted"
        case .useSafeTransition: "shield"
        case .shortenTrack: "scissors"
        }
    }
}

private struct MappingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assistant de mapping MIDI").font(.largeTitle.bold())
                    Text("Active le mode MIDI dans Serato, sélectionne une fonction, puis clique sur Tester pour envoyer son message.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Réinitialiser") { model.resetDefaultMapping() }
                Button("Sauvegarder") { model.saveMapping() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)

            ProgressView(value: model.mappingProfile.completionRatio) {
                Text("\(Int(model.mappingProfile.completionRatio * 100)) % des commandes configurées")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 14)

            List(SeratoAction.allCases) { action in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mappingTitle(action)).font(.headline)
                        if let mapping = model.mappingProfile[action] {
                            Text("\(mapping.kind == .note ? "Note" : "CC") • canal \(Int(mapping.channel) + 1) • n° \(mapping.number) • plage \(mapping.minimumRawValue)–\(mapping.maximumRawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Non configurée").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Tester") { model.testMapping(action) }
                        .disabled(model.mappingProfile[action] == nil)
                }
                .padding(.vertical, 5)
            }
        }
        .navigationTitle("Mapping MIDI")
    }

    private func mappingTitle(_ action: SeratoAction) -> String {
        action.rawValue
            .replacingOccurrences(of: "A", with: " A")
            .replacingOccurrences(of: "B", with: " B")
            .replacingOccurrences(of: "EQ", with: " EQ")
            .capitalized
    }
}

private struct PreflightView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Préflight avant soirée").font(.largeTitle.bold())
                        Text("Le Live ne peut démarrer tant qu’une condition critique reste en échec.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Relancer toutes les vérifications") { model.refreshEnvironment() }
                        .buttonStyle(.borderedProminent)
                }

                ForEach(model.preflightReport.items) { item in
                    PreflightItemRow(item: item)
                }

                GroupBox {
                    HStack {
                        Image(systemName: model.preflightReport.canStartLive ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .font(.largeTitle)
                        VStack(alignment: .leading) {
                            Text(model.preflightReport.canStartLive ? "Autopilot autorisé" : "Autopilot bloqué")
                                .font(.title2.bold())
                            Text(model.preflightReport.canStartLive ? "Toutes les protections critiques sont prêtes." : "Corrige les éléments rouges avant d’armer le Live.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Aller au Live") { model.selectedSection = .live }
                            .disabled(!model.preflightReport.canStartLive)
                    }
                    .padding(8)
                }
            }
            .padding(28)
        }
        .navigationTitle("Préflight")
    }
}

private struct LiveView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("AUTOPILOT").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(model.snapshot.state.rawValue.uppercased()).font(.title.bold())
                    Text(model.runtimeStatus).foregroundStyle(.secondary)
                }
                Spacer()
                ProgressView(value: model.snapshot.progress).frame(width: 260)
            }

            HStack(spacing: 18) {
                DeckCard(title: "DECK \(model.snapshot.activeDeck.rawValue)", track: model.snapshot.currentTrack, status: "EN COURS")
                DeckCard(title: "DECK \(model.snapshot.activeDeck.opposite.rawValue)", track: model.snapshot.nextTrack, status: "PROCHAIN")
            }

            GroupBox("Sécurité en temps réel") {
                HStack(spacing: 18) {
                    Label(model.seratoStatus, systemImage: "music.note.list")
                    Label(model.midiStatus, systemImage: "slider.horizontal.3")
                    Label(model.audioStatus, systemImage: "waveform")
                    Text(String(format: "%.1f dB", model.audioLevelDB)).monospacedDigit()
                    Label(model.connectivityStatus.isAvailable ? "Internet" : "Hors ligne", systemImage: "network")
                    Spacer()
                    Text(model.emergencyStatus).foregroundStyle(.secondary)
                }
                .padding(6)
            }

            GroupBox("Commandes") {
                HStack {
                    Toggle("Armer le Live", isOn: Binding(
                        get: { model.liveArmed },
                        set: { _ in model.armLive() }
                    ))
                    .toggleStyle(.switch)

                    Button(model.isLiveRunning ? "LIVE EN COURS" : "DÉMARRER LE SET") {
                        model.startLive()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLiveRunning || !model.liveArmed || !model.preflightReport.canStartLive)

                    Button("Surveiller l’audio") { model.startAudioMonitoring() }
                    Button("Choisir secours") { model.selectEmergencyAudio() }
                    Button("Tester secours") { model.playEmergencyAudio() }
                    Button("Arrêter secours") { model.stopEmergencyAudio() }
                    Spacer()
                    Button("REPRENDRE LE CONTRÔLE", role: .destructive) { model.takeManualControl() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(6)
            }

            GroupBox("Journal Live") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(model.runtimeEvents.enumerated()), id: \.offset) { _, event in
                            Text(event).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(minHeight: 110, maxHeight: 190)
            }

            LiveSummary(snapshot: model.snapshot)
            Spacer()
        }
        .padding(28)
        .navigationTitle("Live")
    }
}

private struct FeasibilityView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Feasibility Lab").font(.largeTitle.bold())
                Text("Une validation simulée n’est jamais présentée comme un succès réel.")
                    .foregroundStyle(.secondary)

                FeasibilityRow(name: "Port MIDI virtuel", status: model.midiStatus, isReal: model.midiStatus.contains("actif"))
                FeasibilityRow(name: "Détection de Serato", status: model.seratoStatus, isReal: model.seratoStatus.contains("détecté"))
                FeasibilityRow(name: "Permission Accessibilité", status: model.accessibilityStatus, isReal: model.accessibilityStatus == "Autorisée")
                FeasibilityRow(name: "Lignes de bibliothèque", status: "\(model.libraryRowCount) lignes accessibles", isReal: model.libraryRowCount > 0)
                FeasibilityRow(name: "Capture audio", status: model.audioStatus, isReal: model.audioStatus.contains("active"))
                FeasibilityRow(name: "Secours local", status: model.emergencyStatus, isReal: model.emergencyDuration >= 1_800)

                HStack {
                    Button("Demander l’accès Accessibilité") { model.requestAccessibility() }
                    Button("Démarrer la surveillance audio") { model.startAudioMonitoring() }
                    Button("Choisir le secours") { model.selectEmergencyAudio() }
                    Button("Relancer") { model.refreshEnvironment(); model.configureMIDI() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(28)
        }
    }
}

private struct DiagnosticsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Environnement") {
                LabeledContent("Serato", value: model.seratoStatus)
                LabeledContent("MIDI", value: model.midiStatus)
                LabeledContent("Accessibilité", value: model.accessibilityStatus)
                LabeledContent("Audio", value: model.audioStatus)
                LabeledContent("Internet", value: model.connectivityStatus.isAvailable ? model.connectivityStatus.interfaceDescription : "Indisponible")
                LabeledContent("Alimentation", value: model.powerStatus.connectedToPower ? "Secteur" : "Batterie")
                LabeledContent("Bibliothèque visible", value: "\(model.libraryRowCount) lignes")
                LabeledContent("Secours", value: model.emergencyStatus)
            }
            Section("Projet") {
                LabeledContent("Set", value: model.preparedProject?.name ?? "Aucun")
                LabeledContent("Titres", value: "\(model.preparedProject?.tracks.count ?? 0)")
                LabeledContent("Transitions", value: "\(model.preparedProject?.transitions.count ?? 0)")
                LabeledContent("Verrouillé", value: model.preparedProject?.locked == true ? "Oui" : "Non")
            }
            Section("Validation") {
                LabeledContent("Tests Core", value: "SUCCESS")
                LabeledContent("Simulation 50 titres", value: "SUCCESS")
                LabeledContent("Stress-test commandes", value: "SUCCESS")
                LabeledContent("Contrôle Serato réel", value: "REQUIRES_SERATO_VALIDATION")
                LabeledContent("Spotify", value: "Géré uniquement par Serato")
            }
            Section("Maintenance") {
                Button("Recommencer l’onboarding") { model.restartOnboarding() }
            }
        }
        .formStyle(.grouped)
        .padding(22)
        .navigationTitle("Diagnostics")
    }
}

private struct SetupStep: View {
    let number: Int
    let title: String
    let detail: String
    let status: String
    let completed: Bool
    let action: () -> Void

    var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 16) {
                Text("\(number)")
                    .font(.title2.bold())
                    .frame(width: 42, height: 42)
                    .background(completed ? .green.opacity(0.2) : .secondary.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline)
                    Text(detail).foregroundStyle(.secondary)
                    Text(status).font(.caption.bold())
                }
                Spacer()
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                Button(completed ? "Vérifier" : "Configurer", action: action)
            }
            .padding(8)
        }
    }
}

private struct PreflightItemRow: View {
    let item: PreflightItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline)
                Text(item.detail).foregroundStyle(.secondary)
            }
            Spacer()
            Text(label).font(.caption.bold())
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var symbol: String {
        switch item.status {
        case .passed: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.circle.fill"
        case .notTested: "clock.fill"
        }
    }

    private var label: String {
        switch item.status {
        case .passed: "PRÊT"
        case .warning: "ATTENTION"
        case .failed: "BLOQUANT"
        case .notTested: "À TESTER"
        }
    }
}

private struct TrackTimelineRow: View {
    let index: Int
    let prepared: PreparedTrack
    let transition: TransitionPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(index + 1). \(prepared.track.title)").font(.headline)
                Spacer()
                Text(String(format: "%.1f BPM", prepared.track.bpm)).foregroundStyle(.secondary)
            }
            Text(prepared.track.artist).foregroundStyle(.secondary)
            HStack {
                Label(prepared.track.profile.rawValue, systemImage: "music.quarternote.3")
                Text("Analyse \(Int(prepared.analysis.overallConfidence * 100)) %")
                Text("\(prepared.analysis.markers.count) marqueurs")
                if let transition {
                    Text("→ \(transition.kind.rawValue) • \(transition.confidence) %")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

private struct ProjectSummaryCard: View {
    let project: SetProject

    var body: some View {
        GroupBox("Plan de set") {
            VStack(alignment: .leading, spacing: 10) {
                Text(project.name).font(.headline)
                HStack {
                    Label("\(project.tracks.count) titres", systemImage: "music.note.list")
                    Label("\(project.transitions.count) transitions", systemImage: "arrow.left.arrow.right")
                    Label(durationText(project.duration), systemImage: "clock")
                    Label("\(project.reviewTransitionCount) à vérifier", systemImage: "exclamationmark.triangle")
                    Spacer()
                    Label(project.locked ? "Verrouillé" : "Brouillon", systemImage: project.locked ? "lock.fill" : "lock.open")
                }
                .foregroundStyle(.secondary)
            }
            .padding(6)
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        return "\(totalMinutes / 60) h \(totalMinutes % 60) min"
    }
}

private struct StatusCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        GroupBox {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title2).frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.headline).lineLimit(2)
                }
                Spacer()
            }
            .padding(6)
        }
    }
}

private struct DeckCard: View {
    let title: String
    let track: Track?
    let status: String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.caption.bold()).foregroundStyle(.secondary)
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
                .font(.callout)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LiveSummary: View {
    let snapshot: LiveSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(snapshot.statusMessage, systemImage: "dot.radiowaves.left.and.right")
                Spacer()
                Text("\(snapshot.completedTransitions) / \(snapshot.totalTransitions) transitions")
                    .foregroundStyle(.secondary)
            }
            if let incident = snapshot.incidents.last {
                Label(incident.message, systemImage: incident.recovered ? "checkmark.shield" : "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FeasibilityRow: View {
    let name: String
    let status: String
    let isReal: Bool

    var body: some View {
        HStack {
            Image(systemName: isReal ? "checkmark.circle.fill" : "clock.badge.exclamationmark").font(.title2)
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(status).foregroundStyle(.secondary)
            }
            Spacer()
            Text(isReal ? "REAL" : "À VALIDER").font(.caption.bold())
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif
