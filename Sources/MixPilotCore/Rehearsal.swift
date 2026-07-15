import Foundation

public struct RehearsalObservation: Codable, Hashable, Sendable {
    public var silenceDuration: TimeInterval
    public var clippingFrameCount: Int
    public var beatOffsetMilliseconds: Double
    public var vocalOverlapRatio: Double
    public var levelDifferenceDB: Double
    public var executionCompleted: Bool

    public init(
        silenceDuration: TimeInterval,
        clippingFrameCount: Int,
        beatOffsetMilliseconds: Double,
        vocalOverlapRatio: Double,
        levelDifferenceDB: Double,
        executionCompleted: Bool
    ) {
        self.silenceDuration = max(0, silenceDuration)
        self.clippingFrameCount = max(0, clippingFrameCount)
        self.beatOffsetMilliseconds = abs(beatOffsetMilliseconds)
        self.vocalOverlapRatio = vocalOverlapRatio.clamped(to: 0...1)
        self.levelDifferenceDB = abs(levelDifferenceDB)
        self.executionCompleted = executionCompleted
    }
}

public struct RehearsalScore: Codable, Hashable, Sendable {
    public var total: Int
    public var timing: Int
    public var continuity: Int
    public var level: Int
    public var vocalProtection: Int
    public var reliability: Int
    public var reasons: [String]

    public init(
        total: Int,
        timing: Int,
        continuity: Int,
        level: Int,
        vocalProtection: Int,
        reliability: Int,
        reasons: [String]
    ) {
        self.total = total.clamped(to: 0...100)
        self.timing = timing.clamped(to: 0...100)
        self.continuity = continuity.clamped(to: 0...100)
        self.level = level.clamped(to: 0...100)
        self.vocalProtection = vocalProtection.clamped(to: 0...100)
        self.reliability = reliability.clamped(to: 0...100)
        self.reasons = reasons
    }
}

public struct RehearsalVariant: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var plan: TransitionPlan
    public var label: String
    public var score: RehearsalScore?

    public init(id: UUID = UUID(), plan: TransitionPlan, label: String, score: RehearsalScore? = nil) {
        self.id = id
        self.plan = plan
        self.label = label
        self.score = score
    }
}

public struct RehearsalResult: Codable, Hashable, Sendable {
    public var variants: [RehearsalVariant]
    public var selectedVariantID: UUID?

    public init(variants: [RehearsalVariant], selectedVariantID: UUID?) {
        self.variants = variants
        self.selectedVariantID = selectedVariantID
    }

    public var selectedVariant: RehearsalVariant? {
        variants.first { $0.id == selectedVariantID }
    }
}

public struct RehearsalEngine: Sendable {
    public init() {}

    public func variants(for plan: TransitionPlan) -> [RehearsalVariant] {
        var output = [RehearsalVariant(plan: plan, label: "Proposition principale")]

        if plan.kind != .safeFade {
            output.append(RehearsalVariant(
                plan: replacement(plan, kind: .safeFade, bars: max(4, min(8, plan.bars))),
                label: "Variante sécurisée"
            ))
        }
        if plan.kind != .echoExit {
            output.append(RehearsalVariant(
                plan: replacement(plan, kind: .echoExit, bars: 4),
                label: "Variante Echo Exit"
            ))
        }
        if plan.bars > 4 {
            var shortened = plan
            shortened.id = UUID()
            shortened.bars = max(4, plan.bars / 2)
            shortened.reasons.append("Durée raccourcie pour limiter la superposition")
            output.append(RehearsalVariant(plan: shortened, label: "Variante courte"))
        }
        return output
    }

    public func evaluate(
        variant: RehearsalVariant,
        observation: RehearsalObservation
    ) -> RehearsalVariant {
        var evaluated = variant
        evaluated.score = score(plan: variant.plan, observation: observation)
        return evaluated
    }

    public func selectBest(_ variants: [RehearsalVariant]) -> RehearsalResult {
        let selected = variants
            .filter { $0.score != nil }
            .max { left, right in
                let leftScore = left.score?.total ?? 0
                let rightScore = right.score?.total ?? 0
                if leftScore == rightScore {
                    return left.plan.confidence < right.plan.confidence
                }
                return leftScore < rightScore
            }
        return RehearsalResult(variants: variants, selectedVariantID: selected?.id)
    }

    public func score(
        plan: TransitionPlan,
        observation: RehearsalObservation
    ) -> RehearsalScore {
        let timing = Int(max(0, 100 - (observation.beatOffsetMilliseconds / 4.5)).rounded())
        let continuity = Int(max(0, 100 - (observation.silenceDuration * 80)).rounded())
        let level = Int(max(0, 100 - (observation.levelDifferenceDB * 10)).rounded())
        let vocalPenaltyMultiplier = plan.kind == .rapSwitch || plan.kind == .hardCut ? 55.0 : 80.0
        let vocal = Int(max(0, 100 - (observation.vocalOverlapRatio * vocalPenaltyMultiplier)).rounded())
        let reliability = observation.executionCompleted
            ? max(0, 100 - (observation.clippingFrameCount * 8))
            : 0

        let total = Int((
            Double(timing) * 0.25 +
            Double(continuity) * 0.3 +
            Double(level) * 0.15 +
            Double(vocal) * 0.15 +
            Double(reliability) * 0.15
        ).rounded())

        var reasons: [String] = []
        if observation.silenceDuration > 0.25 { reasons.append("Silence trop long pendant la transition") }
        if observation.beatOffsetMilliseconds > 80 { reasons.append("Décalage rythmique perceptible") }
        if observation.levelDifferenceDB > 3 { reasons.append("Variation de niveau sonore excessive") }
        if observation.vocalOverlapRatio > 0.5 { reasons.append("Chevauchement vocal important") }
        if observation.clippingFrameCount > 0 { reasons.append("Saturation détectée") }
        if !observation.executionCompleted { reasons.append("Exécution incomplète") }
        if reasons.isEmpty { reasons.append("Transition techniquement stable") }

        return RehearsalScore(
            total: total,
            timing: timing,
            continuity: continuity,
            level: level,
            vocalProtection: vocal,
            reliability: reliability,
            reasons: reasons
        )
    }

    private func replacement(
        _ plan: TransitionPlan,
        kind: TransitionKind,
        bars: Int
    ) -> TransitionPlan {
        let syntheticOutgoing = Track(
            id: plan.outgoingTrackID,
            title: "Outgoing",
            artist: "",
            bpm: plan.targetBPM,
            duration: 180,
            energy: 0.5,
            vocalDensity: kind == .rapSwitch ? 0.8 : 0.4,
            profile: profile(for: kind)
        )
        let syntheticIncoming = Track(
            id: plan.incomingTrackID,
            title: "Incoming",
            artist: "",
            bpm: plan.targetBPM,
            duration: 180,
            energy: 0.6,
            vocalDensity: kind == .rapSwitch ? 0.8 : 0.4,
            profile: profile(for: kind)
        )
        var replacement = TransitionPlanner().plan(from: syntheticOutgoing, to: syntheticIncoming)
        replacement.id = UUID()
        replacement.kind = kind
        replacement.bars = bars
        replacement.targetBPM = plan.targetBPM
        replacement.confidence = max(plan.confidence, kind == .safeFade || kind == .echoExit ? 78 : plan.confidence)
        replacement.reasons = plan.reasons + ["Variante générée pendant la répétition"]
        return replacement
    }

    private func profile(for kind: TransitionKind) -> MusicalProfile {
        switch kind {
        case .rapSwitch: .rap
        case .shattaDrop: .shatta
        case .bassSwap: .afro
        case .smoothBlend: .zouk
        case .safeFade, .echoExit, .hardCut: .safe
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
