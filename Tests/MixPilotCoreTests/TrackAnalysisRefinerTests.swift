import Testing
@testable import MixPilotCore

@Test("Local beat grid refines BPM and marker origins")
func localAnalysisRefinesTrack() {
    let track = Track(
        title: "Unknown BPM",
        artist: "A",
        bpm: 100,
        duration: 210,
        energy: 0.6,
        vocalDensity: 0.5,
        profile: .afro
    )
    let existing = SetPreparationEngine().analyzeMetadata(for: track)
    let local = LocalAudioAnalysis(
        duration: 60,
        integratedRMS: 0.2,
        peak: 0.8,
        onsets: [],
        beatGrid: BeatGridEstimate(
            bpm: 104,
            beatPeriod: 60 / 104,
            phase: 0.1,
            confidence: 0.82,
            beatTimes: stride(from: 0.1, through: 60, by: 60 / 104).map { $0 }
        ),
        energySections: [
            EnergySection(start: 0, end: 8, normalizedEnergy: 0.1, kind: .quiet),
            EnergySection(start: 8, end: 40, normalizedEnergy: 0.72, kind: .high),
            EnergySection(start: 40, end: 60, normalizedEnergy: 0.12, kind: .quiet),
        ]
    )

    let result = TrackAnalysisRefiner().refine(
        track: track,
        existing: existing,
        local: local,
        capturedStartTime: 120
    )

    #expect(abs(result.track.bpm - 104) < 0.01)
    #expect(result.analysis.bpmConfidence >= 0.82)
    #expect(result.analysis.markers.contains { $0.type == .drop && $0.origin == .automaticAudio })
    #expect(result.analysis.markers.contains { $0.type == .mixOut && $0.origin == .automaticAudio })
    #expect(!result.changes.isEmpty)
}

@Test("Low-confidence local BPM does not overwrite trusted metadata")
func weakBPMDoesNotOverwrite() {
    let track = Track(title: "Trusted", artist: "B", bpm: 122, duration: 190, energy: 0.7, vocalDensity: 0.4, profile: .dancehall)
    let existing = SetPreparationEngine().analyzeMetadata(for: track)
    let local = LocalAudioAnalysis(
        duration: 20,
        integratedRMS: 0.1,
        peak: 0.3,
        onsets: [],
        beatGrid: BeatGridEstimate(bpm: 80, beatPeriod: 0.75, phase: 0, confidence: 0.2, beatTimes: []),
        energySections: []
    )

    let result = TrackAnalysisRefiner().refine(track: track, existing: existing, local: local)
    #expect(result.track.bpm == 122)
}
