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
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("MixPilot")
        } detail: {
            switch model.selectedSection {
            case .dashboard:
                DashboardView(model: model)
            case .studio:
                StudioView(model: model)
            case .mapping:
                MappingView(model: model)
            case .live:
                LiveView(model: model)
            case .feasibility:
                FeasibilityView(model: model)
            case .diagnostics:
                DiagnosticsView(model: model)
            }
        }
        .frame(minWidth: 1_080, minHeight: 700)
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

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 16)], spacing: 16) {
                    StatusCard(title: "Serato", value: model.seratoStatus, symbol: "music.note.list")
                    StatusCard(title: "MIDI", value: model.midiStatus, symbol: "slider.horizontal.3")
                    StatusCard(title: "Accessibilité", value: model.accessibilityStatus, symbol: "hand.raised")
                    StatusCard(title: "Audio", value: model.audioStatus, symbol: "waveform")
                    StatusCard(title: "Bibliothèque", value: "\(model.libraryRowCount) lignes visibles", symbol: "list.bullet.rectangle")
                    StatusCard(title: "Secours", value: model.emergencyStatus, symbol: "lifepreserver")
                }

                GroupBox("Simulation autonome") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Le simulateur utilise la même machine à états que le mode réel et vérifie un set de 50 titres avec incidents injectés.")
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
}

private struct StudioView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MixPilot Studio").font(.largeTitle.bold())
                    Text("Capture la playlist visible dans Serato, prépare les marqueurs et génère toutes les transitions.")
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
                    VStack(alignment: .leading, spacing: 16) {
                        ProjectSummaryCard(project: project)

                        HStack {
                            Button(project.locked ? "Plan verrouillé" : "Verrouiller le plan") {
                                model.lockPreparedProject()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(project.locked)

                            Label(
                                project.locked ? "Prêt pour Live" : "Modifiable",
                                systemImage: project.locked ? "lock.fill" : "lock.open"
                            )
                            .foregroundStyle(.secondary)
                        }

                        if !model.playlistWarnings.isEmpty {
                            GroupBox("Avertissements d'import") {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(model.playlistWarnings.prefix(30)) { warning in
                                            Label("Ligne \(warning.rowIndex + 1) : \(warning.message)", systemImage: "exclamationmark.triangle")
                                                .font(.caption)
                                        }
                                    }
                                }
                                .frame(maxHeight: 180)
                            }
                        }
                        Spacer()
                    }
                    .padding(22)
                    .frame(minWidth: 320, idealWidth: 360)

                    List {
                        ForEach(Array(project.tracks.enumerated()), id: \.element.id) { index, prepared in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text("\(index + 1). \(prepared.track.title)")
                                        .font(.headline)
                                    Spacer()
                                    Text(String(format: "%.1f BPM", prepared.track.bpm))
                                        .foregroundStyle(.secondary)
                                }
                                Text(prepared.track.artist)
                                    .foregroundStyle(.secondary)
                                HStack {
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
}

private struct MappingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mapping MIDI").font(.largeTitle.bold())
                    Text("Profil transmis par le port virtuel MixPilot Virtual Controller.")
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
                    VStack(alignment: .leading) {
                        Text(action.rawValue)
                            .font(.headline)
                        if let mapping = model.mappingProfile[action] {
                            Text(mapping.kind == .note ? "Note MIDI" : "Control Change")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Non configurée")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let mapping = model.mappingProfile[action] {
                        Text("Canal \(Int(mapping.channel) + 1)")
                        Text("N° \(mapping.number)")
                            .monospacedDigit()
                        Text("\(mapping.minimumRawValue)–\(mapping.maximumRawValue)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Mapping MIDI")
    }
}

private struct LiveView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("AUTOPILOT")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(model.snapshot.state.rawValue.uppercased())
                        .font(.title.bold())
                    Text(model.runtimeStatus)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressView(value: model.snapshot.progress)
                    .frame(width: 260)
            }

            HStack(spacing: 18) {
                DeckCard(title: "DECK \(model.snapshot.activeDeck.rawValue)", track: model.snapshot.currentTrack, status: "EN COURS")
                DeckCard(title: "DECK \(model.snapshot.activeDeck.opposite.rawValue)", track: model.snapshot.nextTrack, status: "PROCHAIN")
            }

            GroupBox("Préflight et sécurité") {
                HStack(spacing: 20) {
                    Label(model.seratoStatus, systemImage: "music.note.list")
                    Label(model.midiStatus, systemImage: "slider.horizontal.3")
                    Label(model.audioStatus, systemImage: "waveform")
                    Text(String(format: "%.1f dB", model.audioLevelDB)).monospacedDigit()
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

                    Button(model.isLiveRunning ? "Live en cours…" : "DÉMARRER LE SET") {
                        model.startLive()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLiveRunning || !model.liveArmed || model.preparedProject?.locked != true)

                    Button("Surveiller l'audio") { model.startAudioMonitoring() }
                    Button("Choisir secours") { model.selectEmergencyAudio() }
                    Button("Tester secours") { model.playEmergencyAudio() }
                    Button("Arrêter secours") { model.stopEmergencyAudio() }
                    Spacer()
                    Button("REPRENDRE LE CONTRÔLE", role: .destructive) {
                        model.takeManualControl()
                    }
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
                .frame(minHeight: 100, maxHeight: 180)
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
                Text("Feasibility Lab")
                    .font(.largeTitle.bold())
                Text("Les validations simulées et réelles restent volontairement séparées.")
                    .foregroundStyle(.secondary)

                FeasibilityRow(name: "Port MIDI virtuel", status: model.midiStatus, isReal: model.midiStatus.contains("actif"))
                FeasibilityRow(name: "Détection de Serato", status: model.seratoStatus, isReal: model.seratoStatus.contains("détecté"))
                FeasibilityRow(name: "Permission Accessibilité", status: model.accessibilityStatus, isReal: model.accessibilityStatus.contains("Autorisée"))
                FeasibilityRow(name: "Lignes de bibliothèque", status: "\(model.libraryRowCount) lignes accessibles", isReal: model.libraryRowCount > 0)
                FeasibilityRow(name: "Capture audio", status: model.audioStatus, isReal: model.audioStatus.contains("active"))
                FeasibilityRow(name: "Secours local", status: model.emergencyStatus, isReal: !model.emergencyStatus.contains("Aucun"))

                HStack {
                    Button("Demander l'accès Accessibilité") { model.requestAccessibility() }
                    Button("Démarrer la surveillance audio") { model.startAudioMonitoring() }
                    Button("Choisir le secours") { model.selectEmergencyAudio() }
                    Button("Relancer les vérifications") {
                        model.refreshEnvironment()
                        model.configureMIDI()
                    }
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
                LabeledContent("Planificateur", value: "SIMULATED_SUCCESS")
                LabeledContent("Exécuteur beat-par-beat", value: "AUTOMATED_TEST_PENDING")
                LabeledContent("Contrôle Serato", value: "REQUIRES_SERATO_VALIDATION")
                LabeledContent("Streaming Spotify", value: "Géré uniquement par Serato")
            }
        }
        .formStyle(.grouped)
        .padding(22)
        .navigationTitle("Diagnostics")
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
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 34)
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
                Text(track?.title ?? "Aucun titre")
                    .font(.title2.bold())
                Text(track?.artist ?? "—")
                    .foregroundStyle(.secondary)
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
            Image(systemName: isReal ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                .font(.title2)
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(status).foregroundStyle(.secondary)
            }
            Spacer()
            Text(isReal ? "REAL" : "À VALIDER")
                .font(.caption.bold())
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif
