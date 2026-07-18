#if os(macOS)
import MixPilotCore
import MixPilotMIDI
import MixPilotSystem
import SwiftUI

@MainActor
final class RehearsalWorkspaceModel: ObservableObject {
    @Published var transitionIndex = 0
    @Published var selectedVariantID: UUID?
    @Published var outgoingDeck: DeckID = .a
    @Published private(set) var variants: [RehearsalVariant] = []
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Choisis une transition à répéter"
    @Published private(set) var lastRecord: RehearsalRunRecord?

    private let capture = PreparationAudioCapture()
    private let rehearsalEngine = RehearsalEngine()
    private let measurementBuilder = RehearsalMeasurementBuilder()
    private var projectID: UUID?

    var selectedVariant: RehearsalVariant? {
        variants.first { $0.id == selectedVariantID } ?? variants.first
    }

    func synchronize(project: SetProject?) {
        guard let project else {
            variants = []
            selectedVariantID = nil
            projectID = nil
            status = "Aucun set préparé"
            return
        }
        guard projectID != project.id || variants.isEmpty else { return }
        projectID = project.id
        transitionIndex = min(transitionIndex, max(0, project.transitions.count - 1))
        loadVariants(project: project)
    }

    func selectTransition(_ index: Int, project: SetProject) {
        transitionIndex = min(max(0, index), max(0, project.transitions.count - 1))
        loadVariants(project: project)
    }

    func selectVariant(_ id: UUID) {
        selectedVariantID = id
    }

    func run(project: SetProject, mappingProfile: MIDIMappingProfile) {
        guard !isRunning else { return }
        guard mappingProfile.completionRatio >= 0.95 else {
            status = "Le mapping MIDI doit être confirmé avant la répétition"
            return
        }
        guard project.transitions.indices.contains(transitionIndex),
              project.tracks.indices.contains(transitionIndex),
              project.tracks.indices.contains(transitionIndex + 1),
              let selectedVariant else {
            status = "Transition indisponible"
            return
        }

        isRunning = true
        status = "Capture et exécution de \(selectedVariant.label)…"
        lastRecord = nil

        Task {
            do {
                let controller = try CoreMIDIController()
                let sender = MappedMIDIController(controller: controller, profile: mappingProfile)
                let executor = TransitionExecutor(sender: sender)
                try capture.start(maximumDuration: max(30, expectedDuration(selectedVariant.plan) + 15))
                let summary = try await executor.execute(
                    plan: selectedVariant.plan,
                    outgoingDeck: outgoingDeck,
                    framesPerSecond: 30
                )
                let analysis = try capture.stopAndAnalyze()
                let outgoing = project.tracks[transitionIndex].track
                let incoming = project.tracks[transitionIndex + 1].track
                var observation = measurementBuilder.makeObservation(
                    analysis: analysis,
                    plan: selectedVariant.plan,
                    outgoing: outgoing,
                    incoming: incoming
                )
                observation.executionCompleted = observation.executionCompleted && summary.completed
                let evaluated = rehearsalEngine.evaluate(
                    variant: selectedVariant,
                    observation: observation
                )
                replaceVariant(evaluated)
                lastRecord = RehearsalRunRecord(
                    transitionIndex: transitionIndex,
                    variant: evaluated,
                    observation: observation,
                    analysis: analysis
                )
                let result = rehearsalEngine.selectBest(variants)
                selectedVariantID = result.selectedVariantID ?? evaluated.id
                status = "Mesure terminée • score \(evaluated.score?.total ?? 0)/100"
            } catch is CancellationError {
                capture.cancel()
                status = "Répétition annulée"
            } catch {
                capture.cancel()
                status = "Échec de la répétition : \(error.localizedDescription)"
            }
            isRunning = false
        }
    }

    func cancel() {
        capture.cancel()
        isRunning = false
        status = "Répétition arrêtée"
    }

    private func loadVariants(project: SetProject) {
        guard project.transitions.indices.contains(transitionIndex) else {
            variants = []
            selectedVariantID = nil
            status = "Aucune transition disponible"
            return
        }
        variants = rehearsalEngine.variants(for: project.transitions[transitionIndex])
        selectedVariantID = variants.first?.id
        lastRecord = nil
        status = "\(variants.count) variante(s) prête(s) à mesurer"
    }

    private func replaceVariant(_ variant: RehearsalVariant) {
        if let index = variants.firstIndex(where: { $0.id == variant.id }) {
            variants[index] = variant
        }
    }

    private func expectedDuration(_ plan: TransitionPlan) -> TimeInterval {
        Double(max(1, plan.bars) * 4) * 60 / max(40, plan.targetBPM)
    }
}

struct RehearsalWorkspace: View {
    @ObservedObject var model: AppModel
    @StateObject private var rehearsal = RehearsalWorkspaceModel()

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            HStack(spacing: 0) {
                transitionSidebar
                Rectangle().fill(.white.opacity(0.09)).frame(width: 1)
                detail
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1_120, minHeight: 760)
        .onAppear { rehearsal.synchronize(project: model.preparedProject) }
    }

    private var transitionSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("REHEARSAL")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.orange)
                Text("Répétitions")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text("Choisis une transition réelle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }

            if let project = model.preparedProject, !project.transitions.isEmpty {
                MixPilotStatusBadge(
                    title: "\(project.transitions.count) transitions",
                    symbol: "arrow.left.arrow.right",
                    accent: .orange
                )

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(project.transitions.indices, id: \.self) { index in
                            let outgoing = project.tracks[index].track
                            let incoming = project.tracks[index + 1].track
                            Button {
                                rehearsal.selectTransition(index, project: project)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("#\(index + 1)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.orange)
                                        Spacer()
                                        Text("\(project.transitions[index].confidence) %")
                                            .font(.caption2.bold().monospacedDigit())
                                            .foregroundStyle(project.transitions[index].confidence >= 75 ? .green : .orange)
                                    }
                                    Text(outgoing.title).font(.caption.bold()).lineLimit(1)
                                    Text("→ \(incoming.title)")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.47))
                                        .lineLimit(1)
                                    Text(project.transitions[index].kind.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.34))
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(rehearsal.transitionIndex == index ? .white.opacity(0.095) : .clear, in: RoundedRectangle(cornerRadius: 11))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 11)
                                        .stroke(rehearsal.transitionIndex == index ? .orange.opacity(0.28) : .clear, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                Text("Prépare d’abord un set dans le Studio.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            MixPilotGlassCard(cornerRadius: 14, padding: 12, accent: rehearsal.isRunning ? .red : .orange) {
                VStack(alignment: .leading, spacing: 7) {
                    MixPilotStatusBadge(
                        title: rehearsal.isRunning ? "Mesure en cours" : "État",
                        symbol: rehearsal.isRunning ? "record.circle.fill" : "gauge.with.dots.needle.67percent",
                        accent: rehearsal.isRunning ? .red : .orange
                    )
                    Text(rehearsal.status)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(4)
                }
            }
        }
        .padding(20)
        .frame(width: 315)
        .background(.black.opacity(0.15))
    }

    @ViewBuilder
    private var detail: some View {
        if let project = model.preparedProject, !project.transitions.isEmpty,
           project.transitions.indices.contains(rehearsal.transitionIndex) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    let outgoing = project.tracks[rehearsal.transitionIndex].track
                    let incoming = project.tracks[rehearsal.transitionIndex + 1].track

                    MixPilotSectionHero(
                        eyebrow: "Mesure réelle",
                        title: "\(outgoing.title) → \(incoming.title)",
                        subtitle: "Exécution MIDI, capture temporaire et comparaison des variantes.",
                        symbol: "waveform.badge.magnifyingglass",
                        accent: rehearsal.isRunning ? .red : .orange
                    ) {
                        Picker("Deck sortant", selection: $rehearsal.outgoingDeck) {
                            Text("Deck A").tag(DeckID.a)
                            Text("Deck B").tag(DeckID.b)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                        Button("Actualiser") { rehearsal.synchronize(project: model.preparedProject) }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                        ForEach(rehearsal.variants) { variant in
                            variantCard(variant)
                        }
                    }

                    MixPilotGlassCard(accent: rehearsal.isRunning ? .red : .green) {
                        VStack(alignment: .leading, spacing: 15) {
                            MixPilotPanelTitle(
                                title: rehearsal.isRunning ? "Mesure en cours" : "Exécution et analyse",
                                symbol: rehearsal.isRunning ? "record.circle.fill" : "play.fill",
                                subtitle: rehearsal.status,
                                accent: rehearsal.isRunning ? .red : .green
                            )
                            HStack {
                                Button(rehearsal.isRunning ? "RÉPÉTITION EN COURS…" : "EXÉCUTER ET MESURER") {
                                    rehearsal.run(project: project, mappingProfile: model.mappingProfile)
                                }
                                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                                .disabled(rehearsal.isRunning || rehearsal.selectedVariant == nil)

                                Button("ARRÊTER") { rehearsal.cancel() }
                                    .buttonStyle(MixPilotDangerButtonStyle())
                                    .disabled(!rehearsal.isRunning)

                                Spacer()
                                Label("Audio brut supprimé après analyse", systemImage: "lock.shield.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }
                    }

                    if let record = rehearsal.lastRecord, let score = record.variant.score {
                        MixPilotGlassCard(accent: .green) {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    MixPilotPanelTitle(title: "Dernière mesure locale", symbol: "checkmark.seal.fill", subtitle: record.variant.label, accent: .green)
                                    Spacer()
                                    Text("\(score.total)/100")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundStyle(.green)
                                        .monospacedDigit()
                                }
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 10)], spacing: 10) {
                                    resultMetric("Tempo", record.analysis.beatGrid.map { String(format: "%.1f BPM", $0.bpm) } ?? "Non détecté", "metronome")
                                    resultMetric("Silence maximal", String(format: "%.2f s", record.observation.silenceDuration), "speaker.slash.fill")
                                    resultMetric("Écart temporel", String(format: "%.0f ms", record.observation.beatOffsetMilliseconds), "timer")
                                    resultMetric("Écart de niveau", String(format: "%.1f dB", record.observation.levelDifferenceDB), "speaker.wave.2.fill")
                                    resultMetric("Saturation", record.observation.clippingFrameCount == 0 ? "Non" : "Détectée", "waveform.badge.exclamationmark")
                                    resultMetric("Validation", record.validationKind, "checkmark.shield.fill")
                                }
                            }
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 1_060, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        } else {
            ContentUnavailableView(
                "Aucun set à répéter",
                systemImage: "waveform.badge.magnifyingglass",
                description: Text("Prépare d’abord une playlist dans le Studio.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func variantCard(_ variant: RehearsalVariant) -> some View {
        Button {
            rehearsal.selectVariant(variant.id)
        } label: {
            MixPilotGlassCard(cornerRadius: 17, padding: 16, accent: rehearsal.selectedVariantID == variant.id ? .orange : .blue) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: rehearsal.selectedVariantID == variant.id ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(rehearsal.selectedVariantID == variant.id ? .orange : .white.opacity(0.3))
                        Text(variant.label).font(.headline)
                        Spacer()
                        if let score = variant.score {
                            Text("\(score.total)/100")
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(score.total >= 75 ? .green : .orange)
                        } else {
                            Text("Non mesurée").font(.caption).foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    Text("\(variant.plan.kind.rawValue) • \(variant.plan.bars) mesures • \(String(format: "%.1f", variant.plan.targetBPM)) BPM")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                    if let score = variant.score {
                        Text(score.reasons.joined(separator: " • "))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.36))
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }

    private func resultMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(.green)
            Text(value).font(.headline.monospacedDigit()).lineLimit(2)
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.36))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }
}
#endif
