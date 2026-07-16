#if os(macOS)
import MixPilotCore
import SwiftUI

struct TransitionInspectorView: View {
    @ObservedObject var model: AppModel
    @State private var selectedID: UUID?

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
        .frame(minWidth: 1_080, minHeight: 720)
        .onAppear {
            selectedID = selectedID ?? model.preparedProject?.transitions.first?.id
        }
    }

    private var transitionSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("TRANSITION LAB")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.purple)
                Text("Inspecteur")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text("Analyse détaillée du plan")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }

            if let project = model.preparedProject, !project.transitions.isEmpty {
                MixPilotStatusBadge(
                    title: "\(project.transitions.count) transitions",
                    symbol: "arrow.left.arrow.right",
                    accent: .purple
                )

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(project.transitions.enumerated()), id: \.element.id) { index, transition in
                            let outgoing = project.tracks.first { $0.id == transition.outgoingTrackID }?.track
                            let incoming = project.tracks.first { $0.id == transition.incomingTrackID }?.track
                            Button {
                                selectedID = transition.id
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("#\(index + 1)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.purple)
                                        Spacer()
                                        Text("\(transition.confidence) %")
                                            .font(.caption2.bold().monospacedDigit())
                                            .foregroundStyle(transition.confidence >= 75 ? .green : .orange)
                                    }
                                    Text(outgoing?.title ?? "Sortant")
                                        .font(.caption.bold())
                                        .lineLimit(1)
                                    Text("→ \(incoming?.title ?? "Entrant")")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.48))
                                        .lineLimit(1)
                                    Text(transition.kind.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.36))
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    selectedID == transition.id ? .white.opacity(0.095) : .clear,
                                    in: RoundedRectangle(cornerRadius: 11)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 11)
                                        .stroke(selectedID == transition.id ? .purple.opacity(0.3) : .clear, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                MixPilotGlassCard(cornerRadius: 14, padding: 13, accent: .orange) {
                    Text("Prépare d’abord un set dans le Studio.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 310)
        .background(.black.opacity(0.15))
    }

    @ViewBuilder
    private var detail: some View {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                MixPilotSectionHero(
                    eyebrow: "Analyse de transition",
                    title: "\(outgoing.title) → \(incoming.title)",
                    subtitle: "\(outgoing.artist) → \(incoming.artist)",
                    symbol: "arrow.left.arrow.right.circle.fill",
                    accent: .purple
                ) {
                    MixPilotStatusBadge(
                        title: "Confiance \(transition.confidence) %",
                        symbol: "checkmark.shield.fill",
                        accent: transition.confidence >= 75 ? .green : .orange
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: 12)], spacing: 12) {
                    InspectorMetric(title: "Technique", value: transition.kind.rawValue, symbol: "wand.and.stars", accent: .purple)
                    InspectorMetric(title: "Durée", value: "\(transition.bars) mesures", symbol: "metronome", accent: .cyan)
                    InspectorMetric(title: "Tempo", value: String(format: "%.1f BPM", transition.targetBPM), symbol: "speedometer", accent: .blue)
                    InspectorMetric(title: "Confiance", value: "\(transition.confidence) %", symbol: "checkmark.shield.fill", accent: transition.confidence >= 75 ? .green : .orange)
                }

                HStack(alignment: .top, spacing: 16) {
                    MixPilotGlassCard(accent: .purple) {
                        VStack(alignment: .leading, spacing: 13) {
                            MixPilotPanelTitle(title: "Pourquoi cette transition", symbol: "lightbulb.fill", subtitle: "Raisons enregistrées par le moteur.", accent: .purple)
                            if transition.reasons.isEmpty {
                                Text("Aucune justification enregistrée.")
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.45))
                            } else {
                                ForEach(transition.reasons, id: \.self) { reason in
                                    Label(reason, systemImage: "checkmark.circle.fill")
                                        .font(.callout)
                                        .foregroundStyle(.white.opacity(0.62))
                                }
                            }
                        }
                    }

                    MixPilotGlassCard(accent: .cyan) {
                        VStack(alignment: .leading, spacing: 13) {
                            MixPilotPanelTitle(title: "Résumé musical", symbol: "music.quarternote.3", subtitle: "Écart entre les deux titres.", accent: .cyan)
                            comparisonRow("BPM", String(format: "%.1f", outgoing.bpm), String(format: "%.1f", incoming.bpm))
                            comparisonRow("Profil", outgoing.profile.rawValue, incoming.profile.rawValue)
                            comparisonRow("Énergie", String(format: "%.0f %%", outgoing.energy * 100), String(format: "%.0f %%", incoming.energy * 100))
                            comparisonRow("Voix", String(format: "%.0f %%", outgoing.vocalDensity * 100), String(format: "%.0f %%", incoming.vocalDensity * 100))
                        }
                    }
                }

                MixPilotGlassCard(accent: .blue) {
                    VStack(alignment: .leading, spacing: 14) {
                        MixPilotPanelTitle(title: "Courbes d’automation", symbol: "chart.xyaxis.line", subtitle: "\(transition.lanes.count) lane(s) sur \(transition.bars * 4) temps.", accent: .blue)
                        ForEach(Array(transition.lanes.enumerated()), id: \.offset) { _, lane in
                            InspectorAutomationLane(
                                lane: lane,
                                totalBeats: Double(max(1, transition.bars * 4))
                            )
                        }
                    }
                }

                MixPilotGlassCard(accent: .green) {
                    VStack(alignment: .leading, spacing: 14) {
                        MixPilotPanelTitle(title: "Comparaison des variantes", symbol: "square.stack.3d.up.fill", subtitle: preview.explanation, accent: .green)
                        ForEach(preview.result.variants) { variant in
                            InspectorVariantRow(
                                variant: variant,
                                selected: preview.result.selectedVariantID == variant.id
                            )
                        }
                        Label(
                            "Estimation locale uniquement : la répétition réelle validera ensuite le logiciel DJ, la latence et le niveau audio.",
                            systemImage: "info.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1_040, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private func comparisonRow(_ title: String, _ left: String, _ right: String) -> some View {
        HStack {
            Text(left).font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.34))
            Text(right).font(.caption.bold()).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(9)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct InspectorAutomationLane: View {
    let lane: AutomationLane
    let totalBeats: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(lane.target.rawValue).font(.headline)
                Spacer()
                Text("\(lane.points.count) points")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }
            Canvas { context, size in
                guard let first = lane.points.first else { return }
                var path = Path()
                path.move(to: point(first, size: size))
                for value in lane.points.dropFirst() {
                    path.addLine(to: point(value, size: size))
                }
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [.purple, .cyan]),
                        startPoint: CGPoint(x: 0, y: size.height / 2),
                        endPoint: CGPoint(x: size.width, y: size.height / 2)
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(height: 62)
            .padding(7)
            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.08), lineWidth: 1) }
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
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                Circle().fill((selected ? Color.green : Color.white).opacity(selected ? 0.14 : 0.05))
                Image(systemName: selected ? "checkmark.seal.fill" : "circle")
                    .foregroundStyle(selected ? .green : .white.opacity(0.28))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(variant.label).font(.headline)
                    Text(variant.plan.kind.rawValue)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.44))
                }
                if let score = variant.score {
                    Text("Rythme \(score.timing) • continuité \(score.continuity) • niveau \(score.level) • voix \(score.vocalProtection)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(score.reasons.joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.38))
                } else {
                    Text("Variante non mesurée")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer()
            Text("\(variant.score?.total ?? 0)")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(selected ? .green : .white.opacity(0.55))
        }
        .padding(13)
        .background(selected ? .green.opacity(0.075) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).stroke(selected ? .green.opacity(0.2) : .white.opacity(0.08), lineWidth: 1) }
    }
}

private struct InspectorMetric: View {
    let title: String
    let value: String
    let symbol: String
    let accent: Color

    var body: some View {
        MixPilotMetricTile(title: title, value: value, symbol: symbol, accent: accent)
    }
}
#endif
