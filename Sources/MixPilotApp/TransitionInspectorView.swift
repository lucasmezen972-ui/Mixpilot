#if os(macOS)
import MixPilotCore
import SwiftUI

struct TransitionInspectorView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTransitionID: UUID?
    @State private var preview: RehearsalPreview?

    var body: some View {
        NavigationSplitView {
            if let project = model.preparedProject, !project.transitions.isEmpty {
                List(selection: $selectedTransitionID) {
                    ForEach(Array(project.transitions.enumerated()), id: \.element.id) { index, transition in
                        let tracks = tracks(for: transition, project: project)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(index + 1). \(tracks.outgoing?.title ?? "Sortant") → \(tracks.incoming?.title ?? "Entrant")")
                                .font(.headline)
                                .lineLimit(2)
                            HStack {
                                Text(transition.kind.rawValue)
                                Spacer()
                                Text("\(transition.confidence) %")
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .tag(transition.id)
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Transitions")
            } else {
                ContentUnavailableView(
                    "Aucune transition",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("Prépare d’abord un set dans MixPilot Studio.")
                )
            }
        } detail: {
            if let selection = selectedTransition {
                TransitionDetail(
                    transition: selection.transition,
                    outgoing: selection.outgoing,
                    incoming: selection.incoming,
                    preview: preview
                ) {
                    preview = RehearsalPreviewEngine().preview(
                        plan: selection.transition,
                        outgoing: selection.outgoing,
                        incoming: selection.incoming
                    )
                }
            } else {
                ContentUnavailableView(
                    "Sélectionne une transition",
                    systemImage: "waveform.path",
                    description: Text("L’inspecteur affiche les automations et compare les variantes.")
                )
            }
        }
        .frame(minWidth: 1_050, minHeight: 680)
        .onChange(of: selectedTransitionID) { _, _ in
            generatePreviewForSelection()
        }
        .onAppear {
            if selectedTransitionID == nil {
                selectedTransitionID = model.preparedProject?.transitions.first?.id
            }
            generatePreviewForSelection()
        }
    }

    private var selectedTransition: (transition: TransitionPlan, outgoing: Track, incoming: Track)? {
        guard let project = model.preparedProject,
              let selectedTransitionID,
              let transition = project.transitions.first(where: { $0.id == selectedTransitionID }),
              let outgoing = project.tracks.first(where: { $0.id == transition.outgoingTrackID })?.track,
              let incoming = project.tracks.first(where: { $0.id == transition.incomingTrackID })?.track else {
            return nil
        }
        return (transition, outgoing, incoming)
    }

    private func generatePreviewForSelection() {
        guard let selection = selectedTransition else {
            preview = nil
            return
        }
        preview = RehearsalPreviewEngine().preview(
            plan: selection.transition,
            outgoing: selection.outgoing,
            incoming: selection.incoming
        )
    }

    private func tracks(
        for transition: TransitionPlan,
        project: SetProject
    ) -> (outgoing: Track?, incoming: Track?) {
        (
            project.tracks.first(where: { $0.id == transition.outgoingTrackID })?.track,
            project.tracks.first(where: { $0.id == transition.incomingTrackID })?.track
        )
    }
}

private struct TransitionDetail: View {
    let transition: TransitionPlan
    let outgoing: Track
    let incoming: Track
    let preview: RehearsalPreview?
    let regenerate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(outgoing.title) → \(incoming.title)")
                            .font(.largeTitle.bold())
                        Text("\(outgoing.artist) → \(incoming.artist)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Recalculer les variantes", action: regenerate)
                }

                HStack(spacing: 16) {
                    MetricCard(title: "Technique", value: transition.kind.rawValue)
                    MetricCard(title: "Durée", value: "\(transition.bars) mesures")
                    MetricCard(title: "Tempo cible", value: String(format: "%.1f BPM", transition.targetBPM))
                    MetricCard(title: "Confiance", value: "\(transition.confidence) %")
                }

                GroupBox("Pourquoi cette transition") {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(transition.reasons, id: \.self) { reason in
                            Label(reason, systemImage: "checkmark.circle")
                        }
                        if transition.reasons.isEmpty {
                            Text("Aucune justification enregistrée.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Courbes d’automation") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(transition.lanes.enumerated()), id: \.offset) { _, lane in
                            AutomationLaneView(lane: lane, totalBeats: Double(max(1, transition.bars * 4)))
                        }
                    }
                    .padding(8)
                }

                GroupBox("Comparaison des variantes") {
                    if let preview {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(preview.explanation)
                                .foregroundStyle(.secondary)
                            ForEach(preview.result.variants) { variant in
                                VariantScoreRow(
                                    variant: variant,
                                    selected: preview.result.selectedVariantID == variant.id
                                )
                            }
                            Label(
                                "Estimation locale uniquement : la répétition réelle dans Serato validera ensuite la latence, le titre chargé et le niveau audio.",
                                systemImage: "info.circle"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    } else {
                        ProgressView().padding()
                    }
                }
            }
            .padding(28)
        }
    }
}

private struct AutomationLaneView: View {
    let lane: AutomationLane
    let totalBeats: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(lane.target.rawValue).font(.headline)
                Spacer()
                Text("\(lane.points.count) points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Canvas { context, size in
                guard let first = lane.points.first else { return }
                var path = Path()
                path.move(to: point(first, size: size))
                for automationPoint in lane.points.dropFirst() {
                    path.addLine(to: point(automationPoint, size: size))
                }
                context.stroke(path, with: .foreground, lineWidth: 2)
            }
            .frame(height: 58)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func point(_ automationPoint: AutomationPoint, size: CGSize) -> CGPoint {
        let x = totalBeats <= 0 ? 0 : automationPoint.beat / totalBeats * size.width
        let y = (1 - automationPoint.value) * size.height
        return CGPoint(x: min(max(0, x), size.width), y: min(max(0, y), size.height))
    }
}

private struct VariantScoreRow: View {
    let variant: RehearsalVariant
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: selected ? "checkmark.seal.fill" : "circle")
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(variant.label).font(.headline)
                    Text(variant.plan.kind.rawValue).foregroundStyle(.secondary)
                }
                if let score = variant.score {
                    Text("Total \(score.total) • rythme \(score.timing) • continuité \(score.continuity) • niveau \(score.level) • voix \(score.vocalProtection)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(score.reasons.joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(variant.score?.total ?? 0)")
                .font(.title2.bold())
                .monospacedDigit()
        }
        .padding(10)
        .background(selected ? .accent.opacity(0.12) : .quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
