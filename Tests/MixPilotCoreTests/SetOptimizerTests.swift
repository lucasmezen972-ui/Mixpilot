import Testing
@testable import MixPilotCore

@Test("Optimizer preserves input and returns safe suggestions for weak transitions")
func optimizerReturnsSuggestionsWithoutMutation() {
    let tracks = [
        Track(title: "Slow", artist: "A", bpm: 70, duration: 200, energy: 0.3, vocalDensity: 0.8, profile: .family),
        Track(title: "Fast", artist: "B", bpm: 150, duration: 200, energy: 0.9, vocalDensity: 0.8, profile: .shatta),
        Track(title: "Bridge", artist: "C", bpm: 105, duration: 200, energy: 0.6, vocalDensity: 0.4, profile: .afro),
    ]
    let originalIDs = tracks.map(\.id)
    let report = SetOptimizer().analyze(tracks: tracks)

    #expect(tracks.map(\.id) == originalIDs)
    #expect(report.weakestTransitionConfidence < 100)
    #expect(!report.suggestions.isEmpty)
}

@Test("Locked tracks are not proposed for adjacent swaps")
func immovableTrackIsNotSwapped() {
    let tracks = SetSimulator().makeTracks(count: 8)
    let locked = tracks[3]
    let report = SetOptimizer().analyze(
        tracks: tracks,
        rules: [locked.id: TrackPlaybackRule(trackID: locked.id, isMovable: false)]
    )

    let swapSuggestions = report.suggestions.filter { $0.kind == .swapAdjacentTracks }
    #expect(swapSuggestions.allSatisfy { !$0.affectedTrackIDs.contains(locked.id) })
}
