import Foundation
import Testing
@testable import MixPilotCore

@Test("MIDI mappings convert normalized values to their calibrated raw range")
func midiRawRange() {
    let mapping = MIDIMessageMapping(
        kind: .controlChange,
        number: 20,
        minimumRawValue: 0,
        maximumRawValue: 64
    )
    #expect(mapping.rawValue(for: 0) == 0)
    #expect(mapping.rawValue(for: 0.5) == 32)
    #expect(mapping.rawValue(for: 1) == 64)
}

@Test("The default MIDI profile contains the critical actions")
func defaultMappingContainsCriticalActions() {
    let profile = MIDIMappingProfile.developmentDefault
    #expect(profile[.playA] != nil)
    #expect(profile[.playB] != nil)
    #expect(profile[.syncA] != nil)
    #expect(profile[.syncB] != nil)
    #expect(profile[.crossfader] != nil)
    #expect(profile[.lowEQA] != nil)
    #expect(profile[.lowEQB] != nil)
}

@Test("Crossfader automation is reversed when deck B is outgoing")
func crossfaderDirectionFollowsOutgoingDeck() {
    let tracks = SetSimulator().makeTracks(count: 2)
    let plan = TransitionPlanner().plan(from: tracks[0], to: tracks[1])
    let generator = TransitionFrameGenerator()
    let aFrames = generator.frames(for: plan, outgoingDeck: .a, framesPerSecond: 5)
    let bFrames = generator.frames(for: plan, outgoingDeck: .b, framesPerSecond: 5)

    #expect(aFrames.first?.values[.crossfader] == 0)
    #expect(aFrames.last?.values[.crossfader] == 1)
    #expect(bFrames.first?.values[.crossfader] == 1)
    #expect(bFrames.last?.values[.crossfader] == 0)
}

@Test("Automatic preparation creates markers and n minus one transitions")
func preparationCreatesCompleteProject() {
    let tracks = SetSimulator().makeTracks(count: 12)
    let project = SetPreparationEngine().prepare(name: "Test", tracks: tracks)

    #expect(project.tracks.count == 12)
    #expect(project.transitions.count == 11)
    #expect(project.tracks.allSatisfy { prepared in
        prepared.analysis.markers.contains { $0.type == .mixIn } &&
            prepared.analysis.markers.contains { $0.type == .mixOut } &&
            prepared.analysis.markers.contains { $0.type == .emergencyLoopStart }
    })
    #expect(project.duration > 0)
}

@Test("Project persistence round-trips a prepared set")
func projectPersistenceRoundTrip() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let project = SetPreparationEngine().prepare(
        name: "Persistence",
        tracks: SetSimulator().makeTracks(count: 4)
    )
    let store = JSONProjectStore(directory: root)
    _ = try await store.save(project)
    let restored = try await store.load(id: project.id)

    #expect(restored.id == project.id)
    #expect(restored.tracks.count == 4)
    #expect(restored.transitions.count == 3)
}

@Test("Audio watchdog escalates a sustained silence")
func watchdogEscalatesSilence() async {
    let watchdog = AudioWatchdog(configuration: AudioWatchdogConfiguration(
        silenceThresholdDB: -45,
        warningSilenceDuration: 0.5,
        criticalSilenceDuration: 1.5,
        clippingThresholdDB: -0.2,
        clippingSampleCount: 2
    ))

    _ = await watchdog.ingest(AudioLevelSample(timestamp: 0, rmsDB: -60, peakDB: -50))
    let warning = await watchdog.ingest(AudioLevelSample(timestamp: 0.7, rmsDB: -60, peakDB: -50))
    let critical = await watchdog.ingest(AudioLevelSample(timestamp: 1.6, rmsDB: -60, peakDB: -50))

    if case .silenceWarning = warning {} else { Issue.record("Expected silence warning") }
    if case .criticalSilence = critical {} else { Issue.record("Expected critical silence") }
}

@Test("Audio watchdog detects repeated clipping")
func watchdogDetectsClipping() async {
    let watchdog = AudioWatchdog(configuration: AudioWatchdogConfiguration(clippingSampleCount: 2))
    _ = await watchdog.ingest(AudioLevelSample(timestamp: 0, rmsDB: -8, peakDB: -0.1))
    let result = await watchdog.ingest(AudioLevelSample(timestamp: 0.1, rmsDB: -8, peakDB: 0))
    if case .clipping = result {} else { Issue.record("Expected clipping event") }
}
