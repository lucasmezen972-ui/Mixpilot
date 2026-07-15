import Testing
@testable import MixPilotCore

@Test("Pause is accepted only at safe phases")
func pausePolicy() {
    let policy = LiveRuntimeControlPolicy()
    #expect(policy.pauseDecision(phase: .playing).accepted)
    #expect(policy.pauseDecision(phase: .waitingForTransition).accepted)
    #expect(policy.pauseDecision(phase: .paused).accepted)
    #expect(!policy.pauseDecision(phase: .transitioning).accepted)
    #expect(!policy.pauseDecision(phase: .loading).accepted)
}

@Test("Resume requires matching Serato checkpoint MIDI and audio")
func resumePolicy() {
    let policy = LiveRuntimeControlPolicy()
    #expect(policy.resumeDecision(
        pausedFrom: .playing,
        seratoMatchesCheckpoint: true,
        deckMatchesCheckpoint: true,
        midiReady: true,
        audioWatchdogReady: true
    ).accepted)

    #expect(!policy.resumeDecision(
        pausedFrom: .playing,
        seratoMatchesCheckpoint: false,
        deckMatchesCheckpoint: true,
        midiReady: true,
        audioWatchdogReady: true
    ).accepted)

    #expect(!policy.resumeDecision(
        pausedFrom: .transitioning,
        seratoMatchesCheckpoint: true,
        deckMatchesCheckpoint: true,
        midiReady: true,
        audioWatchdogReady: true
    ).accepted)
}

@Test("Skip never changes the track identities")
func skipUsesSafeReplacementWithoutChangingTracks() {
    let tracks = SetSimulator().makeTracks(count: 2)
    let original = TransitionPlanner().plan(from: tracks[0], to: tracks[1])
    let policy = LiveRuntimeControlPolicy()

    #expect(policy.skipDecision(phase: .waitingForTransition, incomingTrackVerified: true).accepted)
    #expect(!policy.skipDecision(phase: .playing, incomingTrackVerified: true).accepted)
    #expect(!policy.skipDecision(phase: .waitingForTransition, incomingTrackVerified: false).accepted)

    let replacement = policy.safeReplacement(for: original)
    #expect(replacement.kind == .safeFade)
    #expect(replacement.outgoingTrackID == original.outgoingTrackID)
    #expect(replacement.incomingTrackID == original.incomingTrackID)
}
