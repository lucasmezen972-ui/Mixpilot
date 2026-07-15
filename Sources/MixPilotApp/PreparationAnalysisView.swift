#if os(macOS)
import Combine
import MixPilotCore
import MixPilotSystem
import SwiftUI

@MainActor
final class PreparationAnalysisSessionModel: ObservableObject {
    @Published private(set) var isCapturing = false
    @Published private(set) var capturedDuration: TimeInterval = 0
    @Published private(set) var status = "Sélectionne un morceau puis démarre la capture."
    @Published private(set) var lastAnalysis: LocalAudioAnalysis?
    @Published private(set) var lastChanges: [String] = []

    private let capture = PreparationAudioCapture()
    private var durationTask: Task<Void, Never>?

    deinit {
        durationTask?.cancel()
        capture.cancel()
    }

    func start(maximumDuration: TimeInterval = 180) {
        guard !isCapturing else { return }
        do {
            try capture.start(maximumDuration: maximumDuration)
            isCapturing = true
            capturedDuration = 0
            lastAnalysis = nil
            lastChanges = []
            status = "Capture temporaire en cours. Joue la zone voulue dans Serato."
            durationTask?.cancel()
            durationTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard let self else { return }
                    self.capturedDuration = self.capture.capturedDuration
                }
            }
        } catch {
            status = "Impossible de démarrer : \(error.localizedDescription)"
        }
    }

    func stopAndApply(
        appModel: AppModel,
        trackID: UUID,
        capturedStartTime: TimeInterval
    ) {
        guard isCapturing else { return }
        durationTask?.cancel()
        durationTask = nil
        do {
            let analysis = try capture.stopAndAnalyze()
            isCapturing = false
            capturedDuration = analysis.duration
            lastAnalysis = analysis
            let refinement = try appModel.applyLocalAudioAnalysis(
                analysis,
                to: trackID,
                capturedStartTime: capturedStartTime
            )
            lastChanges = refinement.changes
            status = "Analyse appliquée. Les échantillons bruts ont été supprimés de la mémoire."
        } catch {
            isCapturing = false
            status = "Analyse impossible : \(error.localizedDescription)"
        }
    }

    func cancel() {
        durationTask?.cancel()
        durationTask = nil
        capture.cancel()
        isCapturing = false
        capturedDuration = 0
        status = "Capture annulée. Aucun échantillon n’a été conservé."
    }
}

struct PreparationAnalysisView: View {
    @ObservedObject var model: AppModel
    @StateObject private var session = PreparationAnalysisSessionModel()
    @State private var selectedTrackID: UUID?
    @State private var capturedStartTime = 0.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Analyse audio de préparation").font(.largeTitle.bold())
                    Text("Capture temporaire du retour audio : seules les caractéristiques numériques sont conservées.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if session.isCapturing {
                    Label("CAPTURE", systemImage: "record.circle.fill")
                        .font(.headline)
                }
            }
            .padding(28)

            Divider()

            if let project = model.preparedProject, !project.tracks.isEmpty {
                HSplitView {
                    List(selection: $selectedTrackID) {
                        ForEach(project.tracks) { prepared in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(prepared.track.title).font(.headline)
                                Text("\(prepared.track.artist) • \(String(format: "%.1f", prepared.track.bpm)) BPM")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(prepared.id)
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(minWidth: 280, idealWidth: 330)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let selectedTrack {
                                GroupBox("Morceau sélectionné") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(selectedTrack.track.title).font(.title2.bold())
                                        Text(selectedTrack.track.artist).foregroundStyle(.secondary)
                                        HStack {
                                            Label(String(format: "%.1f BPM", selectedTrack.track.bpm), systemImage: "metronome")
                                            Label("\(selectedTrack.analysis.markers.count) marqueurs", systemImage: "bookmark")
                                            Label("Confiance \(Int(selectedTrack.analysis.overallConfidence * 100)) %", systemImage: "gauge")
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding(8)
                                }

                                GroupBox("Zone capturée") {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("Position de départ dans le morceau")
                                            Spacer()
                                            Text(timeText(capturedStartTime)).monospacedDigit()
                                        }
                                        Slider(value: $capturedStartTime, in: 0...max(1, selectedTrack.track.duration - 10), step: 1)
                                            .disabled(session.isCapturing)
                                        Text("Place Serato à cette position avant la capture. MixPilot replacera les marqueurs dans le temps absolu du morceau.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(8)
                                }

                                GroupBox("Capture") {
                                    VStack(alignment: .leading, spacing: 12) {
                                        ProgressView(value: min(1, session.capturedDuration / 180)) {
                                            Text(session.status)
                                        } currentValueLabel: {
                                            Text(timeText(session.capturedDuration)).monospacedDigit()
                                        }

                                        HStack {
                                            Button("Démarrer") { session.start() }
                                                .buttonStyle(.borderedProminent)
                                                .disabled(session.isCapturing || project.locked)
                                            Button("Arrêter et appliquer") {
                                                session.stopAndApply(
                                                    appModel: model,
                                                    trackID: selectedTrack.id,
                                                    capturedStartTime: capturedStartTime
                                                )
                                            }
                                            .disabled(!session.isCapturing)
                                            Button("Annuler", role: .destructive) { session.cancel() }
                                                .disabled(!session.isCapturing)
                                        }

                                        if project.locked {
                                            Label("Le projet est verrouillé. Duplique-le ou prépare l’analyse avant verrouillage.", systemImage: "lock.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(8)
                                }

                                if let analysis = session.lastAnalysis {
                                    AnalysisResultView(analysis: analysis, changes: session.lastChanges)
                                }
                            } else {
                                ContentUnavailableView(
                                    "Sélectionne un morceau",
                                    systemImage: "waveform.badge.magnifyingglass",
                                    description: Text("La capture sera appliquée uniquement au titre choisi.")
                                )
                            }
                        }
                        .padding(24)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Aucun projet préparé",
                    systemImage: "music.note.list",
                    description: Text("Importe d’abord une playlist dans MixPilot Studio.")
                )
            }
        }
        .frame(minWidth: 980, minHeight: 680)
        .onAppear {
            selectedTrackID = selectedTrackID ?? model.preparedProject?.tracks.first?.id
        }
    }

    private var selectedTrack: PreparedTrack? {
        guard let selectedTrackID else { return nil }
        return model.preparedProject?.tracks.first { $0.id == selectedTrackID }
    }

    private func timeText(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

private struct AnalysisResultView: View {
    let analysis: LocalAudioAnalysis
    let changes: [String]

    var body: some View {
        GroupBox("Résultat de l’analyse") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    metric("Durée", String(format: "%.1f s", analysis.duration))
                    metric("BPM", analysis.beatGrid.map { String(format: "%.1f", $0.bpm) } ?? "Non détecté")
                    metric("Confiance", analysis.beatGrid.map { "\(Int($0.confidence * 100)) %" } ?? "—")
                    metric("Onsets", "\(analysis.onsets.count)")
                    metric("Sections", "\(analysis.energySections.count)")
                }
                Divider()
                ForEach(changes, id: \.self) { change in
                    Label(change, systemImage: "checkmark.circle")
                }
            }
            .padding(8)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
