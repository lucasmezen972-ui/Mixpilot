import Foundation

public struct TimelineTrackSegment: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID { preparedTrack.id }
    public var index: Int
    public var preparedTrack: PreparedTrack
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    public var transitionAfter: TransitionPlan?
    public var overlapDuration: TimeInterval

    public init(
        index: Int,
        preparedTrack: PreparedTrack,
        startTime: TimeInterval,
        endTime: TimeInterval,
        transitionAfter: TransitionPlan?,
        overlapDuration: TimeInterval
    ) {
        self.index = index
        self.preparedTrack = preparedTrack
        self.startTime = max(0, startTime)
        self.endTime = max(startTime, endTime)
        self.transitionAfter = transitionAfter
        self.overlapDuration = max(0, overlapDuration)
    }

    public var duration: TimeInterval { endTime - startTime }
}

public struct SetTimeline: Codable, Hashable, Sendable {
    public var segments: [TimelineTrackSegment]
    public var totalDuration: TimeInterval

    public init(project: SetProject, beatsPerBar: Int = 4) {
        var cursor: TimeInterval = 0
        var output: [TimelineTrackSegment] = []

        for (index, prepared) in project.tracks.enumerated() {
            let transition = project.transitions.indices.contains(index) ? project.transitions[index] : nil
            let overlap = transition.map {
                Double(max(1, $0.bars) * max(1, beatsPerBar)) * (60.0 / max(40, $0.targetBPM))
            } ?? 0
            let playDuration = max(15, prepared.analysis.suggestedPlayDuration)
            let start = cursor
            let end = start + playDuration
            output.append(TimelineTrackSegment(
                index: index,
                preparedTrack: prepared,
                startTime: start,
                endTime: end,
                transitionAfter: transition,
                overlapDuration: overlap
            ))
            cursor = max(start, end - overlap)
        }

        segments = output
        totalDuration = output.last?.endTime ?? 0
    }
}

public struct TransitionInspection: Codable, Hashable, Sendable {
    public var index: Int
    public var outgoing: PreparedTrack
    public var incoming: PreparedTrack
    public var plan: TransitionPlan
    public var mixOutMarker: CueMarker?
    public var mixInMarker: CueMarker?
    public var riskLevel: String
    public var recommendations: [String]

    public init?(project: SetProject, transitionIndex: Int) {
        guard project.transitions.indices.contains(transitionIndex),
              project.tracks.indices.contains(transitionIndex),
              project.tracks.indices.contains(transitionIndex + 1) else { return nil }

        index = transitionIndex
        outgoing = project.tracks[transitionIndex]
        incoming = project.tracks[transitionIndex + 1]
        plan = project.transitions[transitionIndex]
        mixOutMarker = outgoing.analysis.markers.first { $0.type == .mixOut }
        mixInMarker = incoming.analysis.markers.first { $0.type == .mixIn }

        switch plan.confidence {
        case 92...100: riskLevel = "Faible"
        case 75..<92: riskLevel = "Modéré"
        default: riskLevel = "Élevé"
        }

        var notes = plan.reasons
        if outgoing.track.vocalDensity > 0.75 && incoming.track.vocalDensity > 0.75 {
            notes.append("Éviter la superposition prolongée des voix")
        }
        if abs(outgoing.track.bpm - incoming.track.bpm) > 10 {
            notes.append("Écart de tempo important : privilégier Echo Exit ou Safe Fade")
        }
        if plan.confidence < 75 {
            notes.append("Répétition recommandée avant verrouillage")
        }
        recommendations = Array(Set(notes))
    }
}
