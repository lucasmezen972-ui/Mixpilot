import Foundation
import Testing
@testable import MixPilotCore

@Test("Matching observed track still requires confirmation before resuming")
func matchingCheckpointRequiresConfirmation() {
    var project = SetPreparationEngine().prepare(name: "Resume", tracks: SetSimulator().makeTracks(count: 5))
    project.lock()
    let track = project.tracks[2].track
    let checkpoint = LiveCheckpoint(
        projectID: project.id,
        projectName: project.name,
        currentTrackIndex: 2,
        activeDeck: .a,
        completedTransitionCount: 2,
        nextTransitionIndex: 2,
        state: .playing,
        lastConfirmedTrackID: track.id,
        lastCommand: "playA",
        emergencyPlaybackActive: false
    )

    let result = CheckpointReconciler().reconcile(
        checkpoint: checkpoint,
        project: project,
        observedTrackTitle: track.title,
        seratoRunning: true,
        audioActive: true
    )
    #expect(result.decision == .requireManualConfirmation)
    #expect(result.proposedTrackIndex == 2)
}

@Test("Missing backend still requires confirmation before emergency playback")
func missingSeratoRequiresConfirmation() {
    var project = SetPreparationEngine().prepare(name: "Emergency", tracks: SetSimulator().makeTracks(count: 3))
    project.lock()
    let checkpoint = LiveCheckpoint(
        projectID: project.id,
        projectName: project.name,
        currentTrackIndex: 1,
        activeDeck: .b,
        completedTransitionCount: 1,
        nextTransitionIndex: 1,
        state: .recovering,
        lastConfirmedTrackID: project.tracks[1].id,
        lastCommand: nil,
        emergencyPlaybackActive: false
    )

    let result = CheckpointReconciler().reconcile(
        checkpoint: checkpoint,
        project: project,
        observedTrackTitle: nil,
        seratoRunning: false,
        audioActive: false
    )
    #expect(result.decision == .requireManualConfirmation)
}

@Test("Checkpoint store round-trips and clears")
func checkpointStoreRoundTrip() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("checkpoint.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let projectID = UUID()
    let checkpoint = LiveCheckpoint(
        projectID: projectID,
        projectName: "Persisted",
        currentTrackIndex: 4,
        activeDeck: .b,
        completedTransitionCount: 4,
        nextTransitionIndex: 4,
        state: .playing,
        lastConfirmedTrackID: UUID(),
        lastCommand: "playB",
        emergencyPlaybackActive: false
    )
    let store = LiveCheckpointStore(fileURL: file)
    try await store.save(checkpoint)
    let restored = try await store.load()
    #expect(restored?.projectID == projectID)
    #expect(restored?.currentTrackIndex == 4)
    try await store.clear()
    #expect(try await store.load() == nil)
}
