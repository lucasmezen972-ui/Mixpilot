#if os(macOS)
import MixPilotCore
import SwiftUI

struct TransitionInspectorView: View {
    @ObservedObject var model: AppModel
    @State private var selectedID: UUID?

    var body: some View {
        NavigationSplitView {
            if let project = model.preparedProject, !project.transitions.isEmpty {
                List(selection: $selectedID) {
                    ForEach(Array(project.transitions.enumerated()), id: \.element.id) { index, transition in
                        let outgoing = project.tracks.first { $0.id == transition.outgoingTrackID }?.track
                        let incoming = project.tracks.first { $0.id == transition.incomingTrackID }?.track
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(index + 1). \(outgoing?.title ?? "Sortant")")
                                .font(.headline)
                                .lineLimit(1)
                            Text("→ \(incoming?.title ?? "Entrant")")
                                .lineLimit(1)
                            HStack {
                                Text(transition.kind.rawValue)
                                Spacer()
                                Text("\(transition.confidence) %").monospacedDigit()
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
            if let selection {
                TransitionInspectorDetail(
                    transition: selection.transition,
                    outgoing: selection.outgoing,
                    incoming: selection.incoming
                )
            } else {
                ContentUnavailableView(
                    "Sélectionne une transition",
                    systemImage: "waveform.path",
                    description: Text("Les automations et variantes apparaîtront ici.")
                )
            }
        }
        .frame(minWidth: 1_050, minHeight: 680)
        .onAppear {
            selectedID = selectedID ?? model.preparedProject?.transitions.first?.id
        }
    }

    private var selection: (transition: TransitionPlan, outgoing: Track, incoming: Track)? {
        guard let project = model.preparedProject,
              let selectedID,
              let transition = project.transitions.first(where: { $0.id == selectedID }),
              let outgoing = project.tracks.first(where: { $0.id == transition.outgoingTrackID })?.track,
              let incoming = project.tracks.first(where: { $0.id == transition.incomingTrackID })?.track else {
            return nil
        }
        return (transition, outgoing, incoming)
    }
}

private struct TransitionInspectorDetail: View {
    let transition: TransitionPlan
    let outgoing: Track
    let incoming: Track

    private var preview: RehearsalPreview {
        RehearsalPreviewEngine().preview(
            plan: transition,
            outgoing: outgoing,
            incoming: incoming
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(outgoing.title) → \(incoming.title)")
                        .font(.largeTitle.bold())
                    Text("\(outgoing.artist) → \(incoming.artist)")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    InspectorMetric(title: "Technique", value: transition.kind.rawValue)
                    InspectorMetric(title: "Durée", value: "\(transition.bars) mesures")
                    InspectorMetric(title: "Tempo", value: String(format: "%.1f BPM", transition.targetBPM))
                    InspectorMetric(title: "Confiance", value: "\(transition.confidence) %")
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
                            InspectorAutomationLane(
                                lane: lane,
                                totalBeats: Double(max(1, transition.bars * 4))
                            )
                        }
                    }
                    .padding(8)
                }

                GroupBox("Comparaison des variantes") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(preview.explanation)
                            .foregroundStyle(.secondary)
                        ForEach(preview.result.variants) { variant in
                            InspectorVariantRow(
                                variant: variant,
                                selected: preview.result.selectedVariantID == variant.id
                            )
                        }
                        Label(
                            "Estimation locale uniquement : la répétition réelle validera ensuite Serato, la latence et le niveau audio.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }
            }
            .padding(28)
        }
    }
}

private struct InspectorAutomationLane: View {
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
                for value in lane.points.dropFirst() {
                    path.addLine(to: point(value, size: size))
                }
                context.stroke(path, with: .foreground, lineWidth: 2)
            }
            .frame(height: 58)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func point(_ value: AutomationPoint, size: CGSize) -> CGPoint {
        let x = totalBeats <= 0 ? 0 : value.beat / totalBeats * size.width
        let y = (1 - value.value) * size.height
        return CGPoint(
            x: min(max(0, x), size.width),
            y: min(max(0, y), size.height)
        )
    }
}

private struct InspectorVariantRow: View {
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
        .background(
            selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }
}

private struct InspectorMetric: View {
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
