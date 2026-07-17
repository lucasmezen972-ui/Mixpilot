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

            HStack(spacing: 0) {
                trackSidebar
                detail
            }
        }
        .mixPilotWindowSurface(minWidth: 1_040, minHeight: 740)
        .onAppear {
            selectedTrackID = selectedTrackID ?? model.preparedProject?.tracks.first?.id
        }
    }

    private var trackSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            MixPilotSidebarHeader(
                eyebrow: "Audio Prep",
                title: "Morceaux",
                subtitle: "Sélectionne le titre à affiner",
                accent: .mint,
                symbol: "waveform"
            )

            if let project = model.preparedProject, !project.tracks.isEmpty {
                MixPilotStatusBadge(
                    title: "\(project.tracks.count) titre(s)",
                    symbol: "music.note.list",
                    accent: .mint
                )

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(project.tracks) { prepared in
                            trackButton(prepared)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                MixPilotNotice(
                    title: "Aucun set préparé",
                    message: "Prépare d’abord un projet dans le Studio pour afficher les morceaux analysables.",
                    kind: .warning
                )
            }

            Spacer(minLength: 10)

            MixPilotGlassCard(cornerRadius: 14, padding: 12, accent: session.isCapturing ? .red : .mint, elevation: .flat) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        MixPilotStatusBadge(
                            title: session.isCapturing ? "Capture active" : "Prêt",
                            symbol: session.isCapturing ? "record.circle.fill" : "checkmark.circle.fill",
                            accent: session.isCapturing ? .red : .mint
                        )
                        Spacer()
                        if session.isCapturing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.red)
                        }
                    }
                    Text(session.status)
                        .font(.caption2)
                        .foregroundStyle(MixPilotPalette.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(5)
                }
            }
        }
        .padding(20)
        .padding(.bottom, 82)
        .frame(width: 310)
        .mixPilotSidebarSurface()
    }

    private func trackButton(_ prepared: PreparedTrack) -> some View {
        let selected = selectedTrackID == prepared.id
        return Button {
            selectedTrackID = prepared.id
            capturedStartTime = 0
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selected ? .mint.opacity(0.14) : .white.opacity(0.035))
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected ? .mint : .white.opacity(0.34))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prepared.track.title)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text("\(prepared.track.artist) • \(String(format: "%.1f", prepared.track.bpm)) BPM")
                        .font(.caption2)
                        .foregroundStyle(MixPilotPalette.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                if selected {
                    Circle()
                        .fill(.mint)
                        .frame(width: 6, height: 6)
                        .shadow(color: .mint.opacity(0.55), radius: 5)
                }
            }
            .padding(8)
            .background(selected ? .white.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(selected ? .mint.opacity(0.20) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        if let selectedTrack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MixPilotSectionHero(
                        eyebrow: "Analyse locale",
                        title: "Analyse audio de préparation",
                        subtitle: "Capture temporaire du retour audio : seules les caractéristiques numériques et les marqueurs proposés sont conservés.",
                        symbol: "waveform.badge.magnifyingglass",
                        accent: session.isCapturing ? .red : .mint
                    ) {
                        if session.isCapturing {
                            MixPilotStatusBadge(title: "Capture en cours", symbol: "record.circle.fill", accent: .red)
                        } else {
                            MixPilotStatusBadge(title: "Données locales", symbol: "lock.shield.fill", accent: .mint)
                        }
                    }

                    selectedTrackCard(selectedTrack)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], spacing: 16) {
                        captureZoneCard(selectedTrack)
                        captureControlCard(selectedTrack)
                    }

                    if let analysis = session.lastAnalysis {
                        PremiumAnalysisResultView(analysis: analysis, changes: session.lastChanges)
                    } else {
                        MixPilotNotice(
                            title: "Aucune mesure récente",
                            message: "Place le morceau sur la zone voulue, démarre la capture puis arrête-la pour générer une prévisualisation non destructive.",
                            kind: .info
                        )
                    }

                    MixPilotNotice(
                        title: "Confidentialité audio",
                        message: "L’audio brut reste uniquement en mémoire pendant l’analyse puis est supprimé. MixPilot conserve seulement des valeurs numériques et les marqueurs proposés.",
                        kind: .warning
                    )
                }
                .padding(28)
                .padding(.bottom, 100)
                .frame(maxWidth: 1_040, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        } else {
            VStack {
                MixPilotEmptyState(
                    title: model.preparedProject == nil ? "Aucun set préparé" : "Sélectionne un morceau",
                    message: model.preparedProject == nil
                        ? "Prépare un projet dans le Studio avant d’ouvrir l’analyse audio locale."
                        : "La capture sera comparée uniquement au morceau choisi dans la colonne de gauche.",
                    symbol: "waveform.badge.magnifyingglass",
                    accent: .mint
                ) {
                    if model.preparedProject == nil {
                        Button("OUVRIR LE STUDIO") {
                            model.selectedSection = .studio
                        }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .mint))
                    }
                }
                .frame(maxWidth: 680)
                .padding(32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func selectedTrackCard(_ selectedTrack: PreparedTrack) -> some View {
        MixPilotGlassCard(accent: .purple, elevation: .elevated) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(.purple.opacity(0.13))
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(.purple.opacity(0.22), lineWidth: 1)
                    Image(systemName: "music.note")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.purple)
                }
                .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedTrack.track.title)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(selectedTrack.track.artist)
                        .font(.callout)
                        .foregroundStyle(MixPilotPalette.textSecondary)
                    HStack(spacing: 12) {
                        MixPilotStatusBadge(title: String(format: "%.1f BPM", selectedTrack.track.bpm), symbol: "metronome", accent: .purple)
                        MixPilotStatusBadge(title: "\(selectedTrack.analysis.markers.count) marqueurs", symbol: "bookmark.fill", accent: .cyan)
                        MixPilotStatusBadge(title: "Confiance \(Int(selectedTrack.analysis.overallConfidence * 100)) %", symbol: "gauge.with.dots.needle.67percent", accent: .green)
                    }
                }
                Spacer(minLength: 12)
            }
        }
    }

    private func captureZoneCard(_ selectedTrack: PreparedTrack) -> some View {
        MixPilotGlassCard(accent: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                MixPilotPanelTitle(
                    title: "Zone capturée",
                    symbol: "scope",
                    subtitle: "Position absolue dans le morceau",
                    accent: .cyan
                )
                HStack {
                    Text("Position de départ")
                        .font(.callout)
                        .foregroundStyle(MixPilotPalette.textSecondary)
                    Spacer()
                    Text(analysisTimeText(capturedStartTime))
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.cyan)
                }
                Slider(value: $capturedStartTime, in: 0...max(1, selectedTrack.track.duration - 10), step: 1)
                    .tint(.cyan)
                    .disabled(session.isCapturing)
                MixPilotNotice(
                    title: "Repère temporel",
                    message: "Place le logiciel DJ à cette position avant la capture. Les marqueurs seront recalés dans le temps absolu du titre.",
                    kind: .info
                )
            }
        }
    }

    private func captureControlCard(_ selectedTrack: PreparedTrack) -> some View {
        MixPilotGlassCard(accent: session.isCapturing ? .red : .mint, elevation: session.isCapturing ? .elevated : .standard) {
            VStack(alignment: .leading, spacing: 14) {
                MixPilotPanelTitle(
                    title: "Capture temporaire",
                    symbol: session.isCapturing ? "record.circle.fill" : "waveform",
                    subtitle: session.status,
                    accent: session.isCapturing ? .red : .mint
                )
                HStack {
                    Text(analysisTimeText(session.capturedDuration))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    Text("MAX 03:00")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(MixPilotPalette.textTertiary)
                }
                ProgressView(value: min(1, session.capturedDuration / 180))
                    .tint(session.isCapturing ? .red : .mint)
                HStack(spacing: 9) {
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

    private var selectedTrack: PreparedTrack? {
        guard let selectedTrackID else { return nil }
        return model.preparedProject?.tracks.first { $0.id == selectedTrackID }
    }
}

private struct PremiumAnalysisResultView: View {
    let analysis: LocalAudioAnalysis
    let changes: [String]

    var body: some View {
        MixPilotGlassCard(accent: .green, elevation: .elevated) {
            VStack(alignment: .leading, spacing: 15) {
                MixPilotPanelTitle(
                    title: "Résultat de l’analyse",
                    symbol: "checkmark.seal.fill",
                    subtitle: "Données numériques uniquement",
                    accent: .green
                )
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    metric("Durée", String(format: "%.1f s", analysis.duration), "clock")
                    metric("BPM", analysis.beatGrid.map { String(format: "%.1f", $0.bpm) } ?? "Non détecté", "metronome")
                    metric("Confiance", analysis.beatGrid.map { "\(Int($0.confidence * 100)) %" } ?? "—", "gauge")
                    metric("Onsets", "\(analysis.onsets.count)", "waveform.path")
                    metric("Sections", "\(analysis.energySections.count)", "square.stack.3d.up.fill")
                }
                if !changes.isEmpty {
                    MixPilotSectionDivider(accent: .green)
                    ForEach(changes, id: \.self) { change in
                        Label(change, systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(MixPilotPalette.textSecondary)
                    }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.green.opacity(0.11))
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .lineLimit(2)
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(MixPilotPalette.textTertiary)
            }
            Spacer()
        }
        .padding(11)
        .background(.white.opacity(0.038), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(.white.opacity(0.065), lineWidth: 1)
        }
    }
}

private func analysisTimeText(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(seconds.rounded()))
    return String(format: "%02d:%02d", value / 60, value % 60)
}
#endif