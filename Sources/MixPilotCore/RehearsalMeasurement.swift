import Foundation

public struct RehearsalMeasurementBuilder: Sendable {
    public init() {}

    public func makeObservation(
        analysis: LocalAudioAnalysis,
        plan: TransitionPlan,
        outgoing: Track,
        incoming: Track
    ) -> RehearsalObservation {
        let targetBeatPeriod = 60.0 / max(1, plan.targetBPM)
        let observedBeatPeriod = analysis.beatGrid?.beatPeriod ?? 0
        let beatOffsetMilliseconds = observedBeatPeriod > 0
            ? abs(observedBeatPeriod - targetBeatPeriod) * 1_000
            : 500

        let quietSections = analysis.energySections.filter {
            $0.kind == .quiet && $0.normalizedEnergy < 0.08
        }
        let longestQuietSection = quietSections.map { $0.end - $0.start }.max() ?? 0
        let clippingFrameCount = analysis.peak >= 0.995 ? 1 : 0
        let rmsDB = analysis.integratedRMS > 0
            ? 20 * log10(analysis.integratedRMS)
            : -160
        let levelDifferenceDB = abs(rmsDB - (-12))
        let vocalOverlapRatio = min(1, outgoing.vocalDensity * incoming.vocalDensity)
        let expectedDuration = Double(max(1, plan.bars) * 4) * targetBeatPeriod
        let executionCompleted = analysis.duration >= max(3, expectedDuration * 0.7) && analysis.beatGrid != nil

        return RehearsalObservation(
            silenceDuration: longestQuietSection,
            clippingFrameCount: clippingFrameCount,
            beatOffsetMilliseconds: beatOffsetMilliseconds,
            vocalOverlapRatio: vocalOverlapRatio,
            levelDifferenceDB: levelDifferenceDB,
            executionCompleted: executionCompleted
        )
    }
}

public struct RehearsalRunRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var transitionIndex: Int
    public var variant: RehearsalVariant
    public var observation: RehearsalObservation
    public var analysis: LocalAudioAnalysis
    public var capturedAt: Date
    public var validationKind: String

    public init(
        id: UUID = UUID(),
        transitionIndex: Int,
        variant: RehearsalVariant,
        observation: RehearsalObservation,
        analysis: LocalAudioAnalysis,
        capturedAt: Date = Date(),
        validationKind: String = "LOCAL_AUDIO_MEASUREMENT"
    ) {
        self.id = id
        self.transitionIndex = max(0, transitionIndex)
        self.variant = variant
        self.observation = observation
        self.analysis = analysis
        self.capturedAt = capturedAt
        self.validationKind = validationKind
    }
}
