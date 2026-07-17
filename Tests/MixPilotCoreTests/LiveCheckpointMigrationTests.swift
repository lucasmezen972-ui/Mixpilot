import Foundation
import Testing
@testable import MixPilotCore

@Test("Legacy checkpoints decode without inventing a DJ backend")
func legacyCheckpointKeepsBackendUnknown() throws {
    let checkpoint = makeCheckpoint(backend: .serato)
    let encoded = try JSONEncoder().encode(checkpoint)
    var object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    object.removeValue(forKey: "formatVersion")
    object.removeValue(forKey: "backend")

    let legacyData = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(LiveCheckpoint.self, from: legacyData)

    #expect(decoded.formatVersion == LiveCheckpoint.currentFormatVersion)
    #expect(decoded.backend == nil)
    #expect(decoded.requiresBackendConfirmation)
}

@Test("A legacy checkpoint always requires manual backend confirmation")
func legacyCheckpointCannotResumeAutomatically() {
    let project = makeProject(backend: .djay)
    let checkpoint = makeCheckpoint(project: project, backend: nil)

    let result = reconcile(checkpoint, project: project, backend: .djay)

    #expect(result.decision == .requireManualConfirmation)
    #expect(result.explanation.contains("ne précise pas"))
}

@Test("Checkpoint, project and active backend must all match")
func checkpointBackendMismatchRequiresManualControl() {
    let project = makeProject(backend: .rekordbox)
    let checkpoint = makeCheckpoint(project: project, backend: .rekordbox)

    let result = reconcile(checkpoint, project: project, backend: .serato)

    #expect(result.decision == .requireManualConfirmation)
    #expect(result.explanation.contains("ne correspond pas"))
}

@Test("Matching checkpoint still requires human confirmation")
func matchingCheckpointRequiresHumanConfirmation() {
    let project = makeProject(backend: .djay)
    let checkpoint = makeCheckpoint(project: project, backend: .djay)

    let result = reconcile(checkpoint, project: project, backend: .djay)

    #expect(result.decision == .requireManualConfirmation)
    #expect(result.proposedTrackIndex == 0)
    #expect(result.proposedDeck == .a)
    #expect(result.explanation.contains("Confirme manuellement"))
}

@Test("A visible title without active audio requires more observation")
func matchingTitleWithoutAudioRequiresObservation() {
    let project = makeProject(backend: .serato)
    let checkpoint = makeCheckpoint(project: project, backend: .serato)

    let result = CheckpointReconciler().reconcile(
        checkpoint: checkpoint,
        project: project,
        activeBackend: .serato,
        backendRunning: true,
        observedTrackTitle: project.tracks[0].track.title,
        audioActive: false
    )

    #expect(result.decision == .requireObservation)
}

@Test("A transitional checkpoint cannot be resumed")
func transitionCheckpointRequiresManualControl() {
    let project = makeProject(backend: .rekordbox)
    var checkpoint = makeCheckpoint(project: project, backend: .rekordbox)
    checkpoint.state = .transitioning

    let result = reconcile(checkpoint, project: project, backend: .rekordbox)

    #expect(result.decision == .requireManualConfirmation)
    #expect(result.explanation.contains("vérification complète"))
}

@Test("A missing confirmed track identity blocks recovery")
func missingConfirmedTrackIdentityBlocksRecovery() {
    let project = makeProject(backend: .djay)
    var checkpoint = makeCheckpoint(project: project, backend: .djay)
    checkpoint.lastConfirmedTrackID = nil

    let result = reconcile(checkpoint, project: project, backend: .djay)

    #expect(result.decision == .requireManualConfirmation)
    #expect(result.explanation.contains("identité"))
}

@Test("A future checkpoint format is never trusted")
func futureCheckpointFormatRequiresManualControl() {
    let project = makeProject(backend: .serato)
    var checkpoint = makeCheckpoint(project: project, backend: .serato)
    checkpoint.formatVersion = LiveCheckpoint.currentFormatVersion + 1

    let result = reconcile(checkpoint, project: project, backend: .serato)

    #expect(result.decision == .requireManualConfirmation)
    #expect(result.explanation.contains("version plus récente"))
}

@Test("A completed checkpoint is discarded")
func completedCheckpointIsDiscarded() {
    let project = makeProject(backend: .serato)
    var checkpoint = makeCheckpoint(project: project, backend: .serato)
    checkpoint.state = .completed

    let result = reconcile(checkpoint, project: project, backend: .serato)

    #expect(result.decision == .discardCompletedSession)
}

@Test("An unavailable recorded backend prioritizes local emergency audio")
func unavailableBackendUsesEmergencyDecision() {
    let project = makeProject(backend: .serato)
    let checkpoint = makeCheckpoint(project: project, backend: .serato)

    let result = CheckpointReconciler().reconcile(
        checkpoint: checkpoint,
        project: project,
        activeBackend: .serato,
        backendRunning: false,
        observedTrackTitle: nil,
        audioActive: false
    )

    #expect(result.decision == .switchToEmergency)
    #expect(result.explanation.contains("Serato DJ Pro"))
}

private func reconcile(
    _ checkpoint: LiveCheckpoint,
    project: SetProject,
    backend: DJBackendIdentifier
) -> CheckpointReconciliationResult {
    CheckpointReconciler().reconcile(
        checkpoint: checkpoint,
        project: project,
        activeBackend: backend,
        backendRunning: true,
        observedTrackTitle: project.tracks[0].track.title,
        audioActive: true
    )
}

private func makeProject(backend: DJBackendIdentifier) -> SetProject {
    SetPreparationEngine().prepare(
        name: "Recovery Test",
        tracks: [
            Track(
                title: "Expected Track",
                artist: "Artist",
                bpm: 118,
                duration: 180,
                energy: 0.5,
                vocalDensity: 0.2,
                profile: .afro
            ),
            Track(
                title: "Next Track",
                artist: "Artist",
                bpm: 119,
                duration: 180,
                energy: 0.6,
                vocalDensity: 0.2,
                profile: .afro
            )
        ],
        backend: backend
    )
}

private func makeCheckpoint(
    project: SetProject? = nil,
    backend: DJBackendIdentifier?
) -> LiveCheckpoint {
    LiveCheckpoint(
        projectID: project?.id ?? UUID(),
        projectName: project?.name ?? "Legacy Project",
        backend: backend,
        currentTrackIndex: 0,
        activeDeck: .a,
        completedTransitionCount: 0,
        nextTransitionIndex: 0,
        state: .playing,
        lastConfirmedTrackID: project?.tracks.first?.id,
        lastCommand: "playA",
        emergencyPlaybackActive: false
    )
}
