import Foundation

public struct TransitionPlanner: Sendable {
    public init() {}

    public func plan(from outgoing: Track, to incoming: Track) -> TransitionPlan {
        let normalizedIncomingBPM = normalizeBPM(incoming.bpm, around: outgoing.bpm)
        let bpmDelta = abs(outgoing.bpm - normalizedIncomingBPM)
        let energyDelta = incoming.energy - outgoing.energy
        let vocalOverlapRisk = max(outgoing.vocalDensity, incoming.vocalDensity)

        let kind = chooseKind(
            outgoing: outgoing,
            incoming: incoming,
            bpmDelta: bpmDelta,
            vocalOverlapRisk: vocalOverlapRisk
        )
        let bars = bars(for: kind)
        let confidence = confidenceScore(
            bpmDelta: bpmDelta,
            energyDelta: energyDelta,
            vocalOverlapRisk: vocalOverlapRisk,
            kind: kind
        )
        let reasons = reasons(
            outgoing: outgoing,
            incoming: incoming,
            bpmDelta: bpmDelta,
            energyDelta: energyDelta,
            kind: kind
        )

        return TransitionPlan(
            outgoingTrackID: outgoing.id,
            incomingTrackID: incoming.id,
            kind: kind,
            bars: bars,
            targetBPM: round(((outgoing.bpm + normalizedIncomingBPM) / 2) * 10) / 10,
            confidence: confidence,
            reasons: reasons,
            lanes: automationLanes(kind: kind, bars: bars)
        )
    }

    public func planSet(_ tracks: [Track]) -> [TransitionPlan] {
        zip(tracks, tracks.dropFirst()).map(plan)
    }

    private func chooseKind(
        outgoing: Track,
        incoming: Track,
        bpmDelta: Double,
        vocalOverlapRisk: Double
    ) -> TransitionKind {
        if bpmDelta > 12 { return .echoExit }
        if bpmDelta > 7 { return .safeFade }

        if outgoing.profile == .shatta || incoming.profile == .shatta ||
            outgoing.profile == .bouyon || incoming.profile == .bouyon {
            return .shattaDrop
        }

        if outgoing.profile == .rap || incoming.profile == .rap || vocalOverlapRisk > 0.78 {
            return .rapSwitch
        }

        if [.afro, .amapiano, .dancehall].contains(outgoing.profile) ||
            [.afro, .amapiano, .dancehall].contains(incoming.profile) {
            return .bassSwap
        }

        if bpmDelta < 3.5 { return .smoothBlend }
        return .safeFade
    }

    private func bars(for kind: TransitionKind) -> Int {
        switch kind {
        case .smoothBlend: 16
        case .bassSwap: 8
        case .rapSwitch: 8
        case .shattaDrop: 4
        case .echoExit: 4
        case .safeFade: 8
        case .hardCut: 1
        }
    }

    private func confidenceScore(
        bpmDelta: Double,
        energyDelta: Double,
        vocalOverlapRisk: Double,
        kind: TransitionKind
    ) -> Int {
        var score = 100.0
        score -= min(35, bpmDelta * 3.1)
        score -= min(15, abs(energyDelta) * 18)
        score -= min(18, vocalOverlapRisk * 12)

        if kind == .safeFade { score = max(score, 78) }
        if kind == .echoExit { score = max(score, 76) }
        if kind == .shattaDrop { score += 3 }
        return Int(score.rounded()).clamped(to: 0...100)
    }

    private func reasons(
        outgoing: Track,
        incoming: Track,
        bpmDelta: Double,
        energyDelta: Double,
        kind: TransitionKind
    ) -> [String] {
        var output: [String] = []
        output.append(String(format: "Écart BPM normalisé : %.1f", bpmDelta))
        output.append(energyDelta >= 0 ? "Énergie en progression" : "Énergie en diminution")
        output.append("Profil retenu : \(kind.rawValue)")
        output.append("Faders de volume utilisés comme protection indépendante du crossfader")
        if outgoing.vocalDensity > 0.75 || incoming.vocalDensity > 0.75 {
            output.append("Protection contre le chevauchement vocal")
        }
        if kind == .safeFade || kind == .echoExit {
            output.append("Priorité à une transition robuste sans blanc")
        }
        return output
    }

    private func normalizeBPM(_ bpm: Double, around reference: Double) -> Double {
        let candidates = [bpm / 2, bpm, bpm * 2]
        return candidates.min(by: { abs($0 - reference) < abs($1 - reference) }) ?? bpm
    }

    private func automationLanes(kind: TransitionKind, bars: Int) -> [AutomationLane] {
        let totalBeats = Double(bars * 4)
        let crossfader = AutomationLane(
            target: .crossfader,
            points: [
                AutomationPoint(beat: 0, value: 0),
                AutomationPoint(beat: totalBeats, value: 1),
            ]
        )
        let smoothVolumeFallback = volumeFallback(totalBeats: totalBeats, cutAtEnd: false)
        let cutVolumeFallback = volumeFallback(totalBeats: totalBeats, cutAtEnd: true)

        switch kind {
        case .smoothBlend:
            return [
                crossfader,
                AutomationLane(target: .incomingLowEQ, points: [
                    AutomationPoint(beat: 0, value: 0),
                    AutomationPoint(beat: totalBeats * 0.55, value: 0),
                    AutomationPoint(beat: totalBeats * 0.7, value: 1),
                ]),
                AutomationLane(target: .outgoingLowEQ, points: [
                    AutomationPoint(beat: 0, value: 1),
                    AutomationPoint(beat: totalBeats * 0.7, value: 0),
                ]),
            ] + smoothVolumeFallback
        case .bassSwap:
            return [
                crossfader,
                AutomationLane(target: .incomingLowEQ, points: [
                    AutomationPoint(beat: 0, value: 0),
                    AutomationPoint(beat: totalBeats * 0.5 - 0.1, value: 0),
                    AutomationPoint(beat: totalBeats * 0.5, value: 1),
                ]),
                AutomationLane(target: .outgoingLowEQ, points: [
                    AutomationPoint(beat: 0, value: 1),
                    AutomationPoint(beat: totalBeats * 0.5, value: 0),
                ]),
            ] + smoothVolumeFallback
        case .rapSwitch, .shattaDrop, .hardCut:
            return [
                AutomationLane(target: .crossfader, points: [
                    AutomationPoint(beat: 0, value: 0),
                    AutomationPoint(beat: max(1, totalBeats - 1), value: 0),
                    AutomationPoint(beat: totalBeats, value: 1),
                ])
            ] + cutVolumeFallback
        case .echoExit:
            return [
                AutomationLane(target: .echoAmount, points: [
                    AutomationPoint(beat: 0, value: 0),
                    AutomationPoint(beat: totalBeats * 0.6, value: 0.2),
                    AutomationPoint(beat: totalBeats, value: 1),
                ]),
                crossfader,
            ] + smoothVolumeFallback
        case .safeFade:
            return [crossfader] + smoothVolumeFallback
        }
    }

    private func volumeFallback(totalBeats: Double, cutAtEnd: Bool) -> [AutomationLane] {
        if cutAtEnd {
            return [
                AutomationLane(target: .incomingVolume, points: [
                    AutomationPoint(beat: 0, value: 0),
                    AutomationPoint(beat: max(1, totalBeats - 1), value: 0),
                    AutomationPoint(beat: totalBeats, value: 1),
                ]),
                AutomationLane(target: .outgoingVolume, points: [
                    AutomationPoint(beat: 0, value: 1),
                    AutomationPoint(beat: max(1, totalBeats - 1), value: 1),
                    AutomationPoint(beat: totalBeats, value: 0),
                ]),
            ]
        }

        return [
            AutomationLane(target: .incomingVolume, points: [
                AutomationPoint(beat: 0, value: 0),
                AutomationPoint(beat: totalBeats, value: 1),
            ]),
            AutomationLane(target: .outgoingVolume, points: [
                AutomationPoint(beat: 0, value: 1),
                AutomationPoint(beat: totalBeats, value: 0),
            ]),
        ]
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
