import Foundation

public struct TrackPlaybackRule: Codable, Hashable, Sendable {
    public var trackID: UUID
    public var isRequired: Bool
    public var isMovable: Bool
    public var earliestStart: Date?
    public var latestStart: Date?
    public var minimumPlayDuration: TimeInterval?
    public var maximumPlayDuration: TimeInterval?

    public init(
        trackID: UUID,
        isRequired: Bool = false,
        isMovable: Bool = true,
        earliestStart: Date? = nil,
        latestStart: Date? = nil,
        minimumPlayDuration: TimeInterval? = nil,
        maximumPlayDuration: TimeInterval? = nil
    ) {
        self.trackID = trackID
        self.isRequired = isRequired
        self.isMovable = isMovable
        self.earliestStart = earliestStart
        self.latestStart = latestStart
        self.minimumPlayDuration = minimumPlayDuration
        self.maximumPlayDuration = maximumPlayDuration
    }
}

public enum SetOptimizationSuggestionKind: String, Codable, Sendable {
    case swapAdjacentTracks
    case moveTrack
    case insertBridgeTrack
    case useSafeTransition
    case shortenTrack
}

public struct SetOptimizationSuggestion: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var kind: SetOptimizationSuggestionKind
    public var affectedTrackIDs: [UUID]
    public var scoreBefore: Int
    public var scoreAfter: Int
    public var explanation: String

    public init(
        id: UUID = UUID(),
        kind: SetOptimizationSuggestionKind,
        affectedTrackIDs: [UUID],
        scoreBefore: Int,
        scoreAfter: Int,
        explanation: String
    ) {
        self.id = id
        self.kind = kind
        self.affectedTrackIDs = affectedTrackIDs
        self.scoreBefore = scoreBefore.clamped(to: 0...100)
        self.scoreAfter = scoreAfter.clamped(to: 0...100)
        self.explanation = explanation
    }

    public var improvement: Int { scoreAfter - scoreBefore }
}

public struct SetOptimizationReport: Codable, Hashable, Sendable {
    public var originalAverageConfidence: Double
    public var weakestTransitionConfidence: Int
    public var suggestions: [SetOptimizationSuggestion]

    public init(
        originalAverageConfidence: Double,
        weakestTransitionConfidence: Int,
        suggestions: [SetOptimizationSuggestion]
    ) {
        self.originalAverageConfidence = originalAverageConfidence
        self.weakestTransitionConfidence = weakestTransitionConfidence
        self.suggestions = suggestions.sorted {
            if $0.improvement == $1.improvement { return $0.scoreAfter > $1.scoreAfter }
            return $0.improvement > $1.improvement
        }
    }
}

public struct SetOptimizer: Sendable {
    private let planner: TransitionPlanner

    public init(planner: TransitionPlanner = TransitionPlanner()) {
        self.planner = planner
    }

    public func analyze(
        tracks: [Track],
        rules: [UUID: TrackPlaybackRule] = [:],
        maximumSuggestions: Int = 20
    ) -> SetOptimizationReport {
        let originalPlans = planner.planSet(tracks)
        let originalAverage = averageConfidence(originalPlans)
        let weakest = originalPlans.map(\.confidence).min() ?? 100
        guard tracks.count >= 3 else {
            return SetOptimizationReport(
                originalAverageConfidence: originalAverage,
                weakestTransitionConfidence: weakest,
                suggestions: safeTransitionSuggestions(tracks: tracks, plans: originalPlans)
            )
        }

        var suggestions = safeTransitionSuggestions(tracks: tracks, plans: originalPlans)
        for index in 0..<(tracks.count - 1) {
            let left = tracks[index]
            let right = tracks[index + 1]
            guard rules[left.id]?.isMovable != false,
                  rules[right.id]?.isMovable != false else { continue }

            var candidate = tracks
            candidate.swapAt(index, index + 1)
            let candidatePlans = planner.planSet(candidate)
            let localBefore = localConfidence(plans: originalPlans, around: index)
            let localAfter = localConfidence(plans: candidatePlans, around: index)
            guard localAfter >= localBefore + 5 else { continue }

            suggestions.append(SetOptimizationSuggestion(
                kind: .swapAdjacentTracks,
                affectedTrackIDs: [left.id, right.id],
                scoreBefore: localBefore,
                scoreAfter: localAfter,
                explanation: "Inverser \(left.title) et \(right.title) améliore les transitions voisines de \(localAfter - localBefore) points."
            ))
        }

        for weakIndex in originalPlans.indices where originalPlans[weakIndex].confidence < 75 {
            guard tracks.indices.contains(weakIndex), tracks.indices.contains(weakIndex + 1) else { continue }
            let outgoing = tracks[weakIndex]
            let incoming = tracks[weakIndex + 1]
            let candidates = tracks.enumerated().filter { index, track in
                abs(index - weakIndex) > 1 &&
                    rules[track.id]?.isMovable != false &&
                    track.id != outgoing.id && track.id != incoming.id
            }

            var bestBridge: (track: Track, score: Int)?
            for (_, bridge) in candidates {
                let first = planner.plan(from: outgoing, to: bridge).confidence
                let second = planner.plan(from: bridge, to: incoming).confidence
                let score = min(first, second)
                if score > (bestBridge?.score ?? originalPlans[weakIndex].confidence) {
                    bestBridge = (bridge, score)
                }
            }

            if let bestBridge, bestBridge.score >= originalPlans[weakIndex].confidence + 8 {
                suggestions.append(SetOptimizationSuggestion(
                    kind: .insertBridgeTrack,
                    affectedTrackIDs: [outgoing.id, bestBridge.track.id, incoming.id],
                    scoreBefore: originalPlans[weakIndex].confidence,
                    scoreAfter: bestBridge.score,
                    explanation: "Placer \(bestBridge.track.title) entre \(outgoing.title) et \(incoming.title) crée un pont plus fluide."
                ))
            }
        }

        return SetOptimizationReport(
            originalAverageConfidence: originalAverage,
            weakestTransitionConfidence: weakest,
            suggestions: Array(suggestions.prefix(max(0, maximumSuggestions)))
        )
    }

    private func safeTransitionSuggestions(
        tracks: [Track],
        plans: [TransitionPlan]
    ) -> [SetOptimizationSuggestion] {
        plans.enumerated().compactMap { index, plan in
            guard plan.confidence < 75,
                  tracks.indices.contains(index),
                  tracks.indices.contains(index + 1) else { return nil }
            return SetOptimizationSuggestion(
                kind: .useSafeTransition,
                affectedTrackIDs: [tracks[index].id, tracks[index + 1].id],
                scoreBefore: plan.confidence,
                scoreAfter: max(78, plan.confidence),
                explanation: "Utiliser une sortie Echo Exit ou Safe Fade entre \(tracks[index].title) et \(tracks[index + 1].title)."
            )
        }
    }

    private func averageConfidence(_ plans: [TransitionPlan]) -> Double {
        guard !plans.isEmpty else { return 100 }
        return Double(plans.reduce(0) { $0 + $1.confidence }) / Double(plans.count)
    }

    private func localConfidence(plans: [TransitionPlan], around index: Int) -> Int {
        guard !plans.isEmpty else { return 100 }
        let lower = max(0, index - 1)
        let upper = min(plans.count - 1, index + 1)
        let slice = plans[lower...upper]
        return Int(Double(slice.reduce(0) { $0 + $1.confidence }) / Double(slice.count))
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
