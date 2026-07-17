import Testing
@testable import MixPilotCore

@Test("Silence uses emergency playback once then hands control back")
func silenceHandsControlBack() async throws {
    let engine = try await preparedEngine()

    await engine.inject(.audioSilence)
    let emergency = await engine.advance()
    let manual = await engine.advance()

    #expect(emergency.state == .emergencyPlayback)
    #expect(manual.state == .manualControl)
    #expect(manual.incidents.last?.recovered == true)
}

@Test("A closed backend uses emergency playback once then hands control back")
func backendLossHandsControlBack() async throws {
    let engine = try await preparedEngine()

    await engine.inject(.backendUnavailable)
    let emergency = await engine.advance()
    let manual = await engine.advance()

    #expect(emergency.state == .emergencyPlayback)
    #expect(manual.state == .manualControl)
}

@Test("MIDI and audio-source loss immediately require manual control")
func infrastructureLossRequiresManualControl() async throws {
    for incident in [IncidentKind.midiUnavailable, .audioSourceLost] {
        let engine = try await preparedEngine()
        await engine.inject(incident)
        let snapshot = await engine.advance()
        #expect(snapshot.state == .manualControl)
    }
}

@Test("Internet loss remains recoverable because Live is local first")
func internetLossRemainsRecoverable() async throws {
    let engine = try await preparedEngine()

    await engine.inject(.internetLoss)
    let recovering = await engine.advance()
    let resumed = await engine.advance()

    #expect(recovering.state == .recovering)
    #expect(resumed.state == .playing)
    #expect(resumed.incidents.last?.recovered == true)
}

private func preparedEngine() async throws -> AutopilotEngine {
    let tracks = SetSimulator().makeTracks(count: 3)
    let plans = TransitionPlanner().planSet(tracks)
    let engine = AutopilotEngine()
    try await engine.load(tracks: tracks, plans: plans)
    try await engine.start()
    return engine
}
