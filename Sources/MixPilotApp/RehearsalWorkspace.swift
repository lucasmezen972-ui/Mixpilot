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
                let sender = MappedSeratoController(controller: controller, profile: mappingProfile)
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
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Répétition des transitions").font(.largeTitle.bold())
                    Text("Charge et positionne les deux titres dans Serato ; MixPilot exécute puis mesure la variante choisie.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Actualiser") { rehearsal.synchronize(project: model.preparedProject) }
                Button("Arrêter", role: .destructive) { rehearsal.cancel() }
                    .disabled(!rehearsal.isRunning)
            }
            .padding(26)

            Divider()

            if let project = model.preparedProject, !project.transitions.isEmpty {
                HSplitView {
                    List(selection: Binding(
                        get: { rehearsal.transitionIndex },
                        set: { index in
                            if let index { rehearsal.selectTransition(index, project: project) }
                        }
                    )) {
                        ForEach(project.transitions.indices, id: \.self) { index in
                            let outgoing = project.tracks[index].track
                            let incoming = project.tracks[index + 1].track
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(index + 1). \(outgoing.title)")
                                    .font(.headline)
                                Text("→ \(incoming.title)")
                                    .foregroundStyle(.secondary)
                                Text("\(project.transitions[index].kind.rawValue) • \(project.transitions[index].confidence) %")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(index)
                        }
                    }
                    .frame(minWidth: 300, idealWidth: 340)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Picker("Deck sortant", selection: $rehearsal.outgoingDeck) {
                                    Text("Deck A").tag(DeckID.a)
                                    Text("Deck B").tag(DeckID.b)
                                }
                                .frame(width: 210)
                                Spacer()
                                Text(rehearsal.status).foregroundStyle(.secondary)
                            }

                            ForEach(rehearsal.variants) { variant in
                                Button {
                                    rehearsal.selectVariant(variant.id)
                                } label: {
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: rehearsal.selectedVariantID == variant.id
                                              ? "largecircle.fill.circle" : "circle")
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(variant.label).font(.headline)
                                                Spacer()
                                                if let score = variant.score {
                                                    Text("\(score.total)/100").font(.title3.bold())
                                                } else {
                                                    Text("Non mesurée").foregroundStyle(.secondary)
                                                }
                                            }
                                            Text("\(variant.plan.kind.rawValue) • \(variant.plan.bars) mesures • \(String(format: "%.1f", variant.plan.targetBPM)) BPM")
                                                .foregroundStyle(.secondary)
                                            if let score = variant.score {
                                                Text(score.reasons.joined(separator: " • "))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(14)
                                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }

                            HStack {
                                Button(rehearsal.isRunning ? "Répétition en cours…" : "Exécuter et mesurer") {
                                    rehearsal.run(project: project, mappingProfile: model.mappingProfile)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(rehearsal.isRunning || rehearsal.selectedVariant == nil)

                                Text("L’audio brut reste uniquement en mémoire et est supprimé après l’analyse.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let record = rehearsal.lastRecord, let score = record.variant.score {
                                GroupBox("Dernière mesure locale") {
                                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 9) {
                                        GridRow { Text("Score total"); Text("\(score.total)/100") }
                                        GridRow { Text("Tempo détecté"); Text(record.analysis.beatGrid.map { String(format: "%.1f BPM", $0.bpm) } ?? "Non détecté") }
                                        GridRow { Text("Silence maximal"); Text(String(format: "%.2f s", record.observation.silenceDuration)) }
                                        GridRow { Text("Écart temporel"); Text(String(format: "%.0f ms", record.observation.beatOffsetMilliseconds)) }
                                        GridRow { Text("Écart de niveau"); Text(String(format: "%.1f dB", record.observation.levelDifferenceDB)) }
                                        GridRow { Text("Saturation"); Text(record.observation.clippingFrameCount == 0 ? "Non" : "Détectée") }
                                        GridRow { Text("Validation"); Text(record.validationKind) }
                                    }
                                    .padding(8)
                                }
                            }
                        }
                        .padding(24)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Aucun set à répéter",
                    systemImage: "waveform.badge.magnifyingglass",
                    description: Text("Prépare d’abord une playlist dans le Studio.")
                )
            }
        }
        .frame(minWidth: 1_050, minHeight: 720)
        .onAppear { rehearsal.synchronize(project: model.preparedProject) }
    }
}
#endif
