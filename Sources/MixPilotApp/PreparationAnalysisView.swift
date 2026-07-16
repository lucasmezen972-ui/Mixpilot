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
            status = "Capture temporaire en cours. Joue la zone voulue dans le logiciel DJ."
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

    func stopAndPreview(
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
            let refinement = try appModel.previewLocalAudioAnalysis(
                analysis,
                for: trackID,
                capturedStartTime: capturedStartTime
            )
            lastChanges = refinement.changes
            status = "Prévisualisation terminée. Aucun échantillon brut n’a été conservé."
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
        ZStack {
            MixPilotPremiumBackground()

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    trackSidebar
                    Rectangle().fill(.white.opacity(0.09)).frame(width: 1)
                    detail
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1_020, minHeight: 720)
        .onAppear {
            selectedTrackID = selectedTrackID ?? model.preparedProject?.tracks.first?.id
        }
    }

    private var trackSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("AUDIO PREP")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.mint)
                Text("Morceaux")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text("Sélectionne le titre analysé")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }

            if let project = model.preparedProject, !project.tracks.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(project.tracks) { prepared in
                            Button {
                                selectedTrackID = prepared.id
                                capturedStartTime = 0
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9).fill(selectedTrackID == prepared.id ? .mint.opacity(0.14) : .white.opacity(0.04))
                                        Image(systemName: "waveform")
                                            .foregroundStyle(selectedTrackID == prepared.id ? .mint : .white.opacity(0.35))
                                    }
                                    .frame(width: 34, height: 34)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(prepared.track.title).font(.caption.bold()).lineLimit(1)
                                        Text("\(prepared.track.artist) • \(String(format: "%.1f", prepared.track.bpm)) BPM")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.4))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(selectedTrackID == prepared.id ? .white.opacity(0.085) : .clear, in: RoundedRectangle(cornerRadius: 11))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                Text("Aucun projet préparé")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            MixPilotGlassCard(cornerRadius: 14, padding: 12, accent: session.isCapturing ? .red : .mint) {
                VStack(alignment: .leading, spacing: 7) {
                    MixPilotStatusBadge(
                        title: session.isCapturing ? "Capture active" : "Prêt",
                        symbol: session.isCapturing ? "record.circle.fill" : "checkmark.circle.fill",
                        accent: session.isCapturing ? .red : .mint
                    )
                    Text(session.status)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(4)
                }
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(.black.opacity(0.15))
    }

    @ViewBuilder
    private var detail: some View {
        if let selectedTrack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MixPilotSectionHero(
                        eyebrow: "Analyse locale",
                        title: "Analyse audio de préparation",
                        subtitle: "Capture temporaire du retour audio ; seules les caractéristiques numériques sont conservées.",
                        symbol: "waveform.badge.magnifyingglass",
                        accent: session.isCapturing ? .red : .mint
                    ) {
                        if session.isCapturing {
                            MixPilotStatusBadge(title: "Capture", symbol: "record.circle.fill", accent: .red)
                        }
                    }

                    MixPilotGlassCard(accent: .purple) {
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(.purple.opacity(0.14))
                                Image(systemName: "music.note")
                                    .font(.system(size: 29, weight: .semibold))
                                    .foregroundStyle(.purple)
                            }
                            .frame(width: 62, height: 62)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(selectedTrack.track.title)
                                    .font(.system(size: 23, weight: .bold, design: .rounded))
                                Text(selectedTrack.track.artist)
                                    .foregroundStyle(.white.opacity(0.5))
                                HStack(spacing: 14) {
                                    Label(String(format: "%.1f BPM", selectedTrack.track.bpm), systemImage: "metronome")
                                    Label("\(selectedTrack.analysis.markers.count) marqueurs", systemImage: "bookmark.fill")
                                    Label("Confiance \(Int(selectedTrack.analysis.overallConfidence * 100)) %", systemImage: "gauge.with.dots.needle.67percent")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                        }
                    }

                    HStack(alignment: .top, spacing: 16) {
                        MixPilotGlassCard(accent: .cyan) {
                            VStack(alignment: .leading, spacing: 14) {
                                MixPilotPanelTitle(title: "Zone capturée", symbol: "scope", subtitle: "Position absolue dans le morceau.", accent: .cyan)
                                HStack {
                                    Text("Position de départ")
                                    Spacer()
                                    Text(analysisTimeText(capturedStartTime))
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(.cyan)
                                }
                                Slider(value: $capturedStartTime, in: 0...max(1, selectedTrack.track.duration - 10), step: 1)
                                    .tint(.cyan)
                                    .disabled(session.isCapturing)
                                Text("Place le logiciel DJ à cette position avant la capture. Les marqueurs seront recalés dans le temps absolu du titre.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.46))
                            }
                        }

                        MixPilotGlassCard(accent: session.isCapturing ? .red : .mint) {
                            VStack(alignment: .leading, spacing: 14) {
                                MixPilotPanelTitle(title: "Capture temporaire", symbol: session.isCapturing ? "record.circle.fill" : "waveform", subtitle: session.status, accent: session.isCapturing ? .red : .mint)
                                HStack {
                                    Text(analysisTimeText(session.capturedDuration))
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                    Spacer()
                                    Text("MAX 03:00")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white.opacity(0.38))
                                }
                                ProgressView(value: min(1, session.capturedDuration / 180))
                                    .tint(session.isCapturing ? .red : .mint)
                                HStack {
                                    Button("DÉMARRER") { session.start() }
                                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .mint))
                                        .disabled(session.isCapturing)
                                    Button("ARRÊTER ET ANALYSER") {
                                        session.stopAndPreview(
                                            appModel: model,
                                            trackID: selectedTrack.id,
                                            capturedStartTime: capturedStartTime
                                        )
                                    }
                                    .buttonStyle(MixPilotSecondaryButtonStyle())
                                    .disabled(!session.isCapturing)
                                    Button("ANNULER") { session.cancel() }
                                        .buttonStyle(MixPilotDangerButtonStyle())
                                        .disabled(!session.isCapturing)
                                }
                            }
                        }
                    }

                    if let analysis = session.lastAnalysis {
                        PremiumAnalysisResultView(analysis: analysis, changes: session.lastChanges)
                    }

                    MixPilotGlassCard(accent: .orange) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill").foregroundStyle(.orange)
                            Text("L’audio brut reste uniquement en mémoire pendant l’analyse puis est supprimé. MixPilot conserve seulement des valeurs numériques et les marqueurs proposés.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.52))
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 1_020, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        } else {
            ContentUnavailableView(
                "Sélectionne un morceau",
                systemImage: "waveform.badge.magnifyingglass",
                description: Text("La capture sera comparée uniquement au titre choisi.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedTrack: PreparedTrack? {
        guard let selectedTrackID else { return nil }
        return model.preparedProject?.tracks.first { $0.id == selectedTrackID }
    }
}

private struct PremiumAnalysisResultView: View {
    let analysis: LocalAudioAnalysis
    let changes: [String]

    var body: some View {
        MixPilotGlassCard(accent: .green) {
            VStack(alignment: .leading, spacing: 15) {
                MixPilotPanelTitle(title: "Résultat de l’analyse", symbol: "checkmark.seal.fill", subtitle: "Données numériques uniquement", accent: .green)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                    metric("Durée", String(format: "%.1f s", analysis.duration), "clock")
                    metric("BPM", analysis.beatGrid.map { String(format: "%.1f", $0.bpm) } ?? "Non détecté", "metronome")
                    metric("Confiance", analysis.beatGrid.map { "\(Int($0.confidence * 100)) %" } ?? "—", "gauge")
                    metric("Onsets", "\(analysis.onsets.count)", "waveform.path")
                    metric("Sections", "\(analysis.energySections.count)", "square.stack.3d.up.fill")
                }
                if !changes.isEmpty {
                    Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
                    ForEach(changes, id: \.self) { change in
                        Label(change, systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(.green)
            Text(value).font(.title3.bold().monospacedDigit()).lineLimit(2)
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }
}

private func analysisTimeText(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(seconds.rounded()))
    return String(format: "%02d:%02d", value / 60, value % 60)
}
#endif
