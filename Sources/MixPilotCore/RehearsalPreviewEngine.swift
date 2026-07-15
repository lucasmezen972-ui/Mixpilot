import Foundation

public struct RehearsalPreview: Codable, Hashable, Sendable {
    public var outgoingTrackID: UUID
    public var incomingTrackID: UUID
    public var result: RehearsalResult
    public var modeledOnly: Bool
    public var explanation: String

    public init(
        outgoingTrackID: UUID,
        incomingTrackID: UUID,
        result: RehearsalResult,
        modeledOnly: Bool = true,
        explanation: String
    ) {
        self.outgoingTrackID = outgoingTrackID
        self.incomingTrackID = incomingTrackID
        self.result = result
        self.modeledOnly = modeledOnly
        self.explanation = explanation
    }
}

public struct RehearsalPreviewEngine: Sendable {
    private let rehearsalEngine: RehearsalEngine

    public init(rehearsalEngine: RehearsalEngine = RehearsalEngine()) {
        self.rehearsalEngine = rehearsalEngine
    }

    public func preview(
        plan: TransitionPlan,
        outgoing: Track,
        incoming: Track
    ) -> RehearsalPreview {
        let variants = rehearsalEngine.variants(for: plan).map { variant in
            rehearsalEngine.evaluate(
                variant: variant,
                observation: modeledObservation(
                    plan: variant.plan,
                    outgoing: outgoing,
                    incoming: incoming
                )
            )
        }
        let result = rehearsalEngine.selectBest(variants)
        let selected = result.selectedVariant
        let explanation: String
        if let selected, let score = selected.score {
            explanation = "\(selected.label) obtient \(score.total)/100 selon le BPM, l’énergie, les voix et la durée de superposition. Une répétition réelle reste nécessaire pour valider Serato et l’audio."
        } else {
            explanation = "Aucune variante n’a pu être estimée. Une vérification manuelle est nécessaire."
        }
        return RehearsalPreview(
            outgoingTrackID: outgoing.id,
            incomingTrackID: incoming.id,
            result: result,
            explanation: explanation
        )
    }

    private func modeledObservation(
        plan: TransitionPlan,
        outgoing: Track,
        incoming: Track
    ) -> RehearsalObservation {
        let bpmDelta = abs(outgoing.bpm - incoming.bpm)
        let pitchDeltaRatio = bpmDelta / max(1, outgoing.bpm)
        let overlapFactor: Double
        switch plan.kind {
        case .smoothBlend: overlapFactor = min(1, Double(plan.bars) / 24)
        case .bassSwap: overlapFactor = min(0.85, Double(plan.bars) / 20)
        case .rapSwitch: overlapFactor = 0.28
        case .shattaDrop, .hardCut: overlapFactor = 0.12
        case .echoExit: overlapFactor = 0.08
        case .safeFade: overlapFactor = 0.18
        }

        let vocalOverlap = outgoing.vocalDensity * incoming.vocalDensity * overlapFactor
        let energyDelta = abs(outgoing.energy - incoming.energy)
        let levelDifference = energyDelta * 7.5
        let baseOffset = pitchDeltaRatio * 620
        let techniqueMultiplier: Double
        switch plan.kind {
        case .smoothBlend, .bassSwap: techniqueMultiplier = 1
        case .rapSwitch: techniqueMultiplier = 0.6
        case .shattaDrop, .hardCut: techniqueMultiplier = 0.3
        case .echoExit, .safeFade: techniqueMultiplier = 0.18
        }
        let offset = baseOffset * techniqueMultiplier
        let silence: TimeInterval
        switch plan.kind {
        case .hardCut: silence = bpmDelta > 18 ? 0.12 : 0.03
        case .shattaDrop: silence = 0.04
        case .echoExit, .safeFade, .smoothBlend, .bassSwap, .rapSwitch: silence = 0
        }
        let clipping = outgoing.energy + incoming.energy > 1.65 && overlapFactor > 0.5 ? 2 : 0

        return RehearsalObservation(
            silenceDuration: silence,
            clippingFrameCount: clipping,
            beatOffsetMilliseconds: offset,
            vocalOverlapRatio: vocalOverlap,
            levelDifferenceDB: levelDifference,
            executionCompleted: true
        )
    }
}
