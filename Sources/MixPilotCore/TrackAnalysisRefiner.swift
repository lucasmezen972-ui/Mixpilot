import Foundation

public struct TrackAnalysisRefinement: Codable, Hashable, Sendable {
    public var track: Track
    public var analysis: TrackAnalysis
    public var changes: [String]

    public init(track: Track, analysis: TrackAnalysis, changes: [String]) {
        self.track = track
        self.analysis = analysis
        self.changes = changes
    }
}

public struct TrackAnalysisRefiner: Sendable {
    public init() {}

    public func refine(
        track: Track,
        existing: TrackAnalysis,
        local: LocalAudioAnalysis,
        capturedStartTime: TimeInterval = 0
    ) -> TrackAnalysisRefinement {
        var refinedTrack = track
        var refinedAnalysis = existing
        var markers = existing.markers
        var changes: [String] = []

        if let beatGrid = local.beatGrid,
           beatGrid.confidence >= 0.35,
           beatGrid.bpm >= 55,
           beatGrid.bpm <= 220 {
            let previous = refinedTrack.bpm
            refinedTrack.bpm = beatGrid.bpm
            refinedAnalysis.bpmConfidence = max(refinedAnalysis.bpmConfidence, beatGrid.confidence)
            refinedAnalysis.downbeatConfidence = max(
                refinedAnalysis.downbeatConfidence,
                min(0.88, beatGrid.confidence * 0.86)
            )
            if abs(previous - beatGrid.bpm) >= 0.2 {
                changes.append(String(format: "BPM %.1f → %.1f", previous, beatGrid.bpm))
            }
        }

        let sections = local.energySections
        if let firstHigh = sections.first(where: { $0.kind == .high }) {
            let dropTime = capturedStartTime + firstHigh.start
            upsertMarker(
                type: .drop,
                time: dropTime,
                confidence: min(0.9, 0.55 + firstHigh.normalizedEnergy * 0.35),
                markers: &markers
            )
            changes.append(String(format: "Drop estimé à %.1f s", dropTime))
        }

        if let firstMediumOrHigh = sections.first(where: { $0.kind != .quiet }) {
            let mixInTime = capturedStartTime + firstMediumOrHigh.start
            upsertMarker(
                type: .mixIn,
                time: mixInTime,
                confidence: 0.78,
                markers: &markers
            )
        }

        if let finalQuiet = sections.last(where: { $0.kind == .quiet }),
           finalQuiet.start > local.duration * 0.5 {
            let mixOutTime = capturedStartTime + finalQuiet.start
            upsertMarker(
                type: .mixOut,
                time: mixOutTime,
                confidence: 0.76,
                markers: &markers
            )
            upsertMarker(
                type: .endSafe,
                time: capturedStartTime + max(finalQuiet.start, finalQuiet.end - 1),
                confidence: 0.82,
                markers: &markers
            )
            changes.append(String(format: "Outro détectée à %.1f s", mixOutTime))
        }

        if let beatGrid = local.beatGrid, beatGrid.beatTimes.count >= 32 {
            let beatPeriod = beatGrid.beatPeriod
            let phraseDuration = beatPeriod * 32
            let safeEnd = min(track.duration, capturedStartTime + local.duration)
            let loopEnd = max(capturedStartTime, safeEnd - max(phraseDuration, 8))
            let loopStart = max(capturedStartTime, loopEnd - phraseDuration)
            upsertMarker(type: .emergencyLoopStart, time: loopStart, confidence: 0.75, markers: &markers)
            upsertMarker(type: .emergencyLoopEnd, time: loopEnd, confidence: 0.75, markers: &markers)
        }

        refinedAnalysis.markers = markers.sorted { $0.time < $1.time }
        refinedAnalysis.structureConfidence = max(
            refinedAnalysis.structureConfidence,
            local.energySections.isEmpty ? 0 : 0.74
        )
        refinedAnalysis.phraseConfidence = max(
            refinedAnalysis.phraseConfidence,
            local.beatGrid.map { min(0.88, $0.confidence * 0.92) } ?? 0
        )
        refinedAnalysis.warnings.removeAll { warning in
            warning.localizedCaseInsensitiveContains("BPM manquant") && local.beatGrid != nil
        }

        if changes.isEmpty {
            changes.append("Analyse locale conservée sans modification majeure")
        }
        return TrackAnalysisRefinement(
            track: refinedTrack,
            analysis: refinedAnalysis,
            changes: changes
        )
    }

    private func upsertMarker(
        type: CueMarkerType,
        time: TimeInterval,
        confidence: Double,
        markers: inout [CueMarker]
    ) {
        if let index = markers.firstIndex(where: { $0.type == type }) {
            if confidence >= markers[index].confidence {
                markers[index].time = max(0, time)
                markers[index].confidence = min(1, max(0, confidence))
                markers[index].origin = .automaticAudio
            }
        } else {
            markers.append(CueMarker(
                type: type,
                time: max(0, time),
                confidence: confidence,
                origin: .automaticAudio
            ))
        }
    }
}
