import Foundation

public struct LiveCheckpoint: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var projectName: String
    public var currentTrackIndex: Int
    public var activeDeck: DeckID
    public var completedTransitionCount: Int
    public var nextTransitionIndex: Int?
    public var state: AutopilotState
    public var lastConfirmedTrackID: UUID?
    public var lastCommand: String?
    public var emergencyPlaybackActive: Bool
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        projectName: String,
        currentTrackIndex: Int,
        activeDeck: DeckID,
        completedTransitionCount: Int,
        nextTransitionIndex: Int?,
        state: AutopilotState,
        lastConfirmedTrackID: UUID?,
        lastCommand: String?,
        emergencyPlaybackActive: Bool,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = projectName
        self.currentTrackIndex = max(0, currentTrackIndex)
        self.activeDeck = activeDeck
        self.completedTransitionCount = max(0, completedTransitionCount)
        self.nextTransitionIndex = nextTransitionIndex.map { max(0, $0) }
        self.state = state
        self.lastConfirmedTrackID = lastConfirmedTrackID
        self.lastCommand = lastCommand
        self.emergencyPlaybackActive = emergencyPlaybackActive
        self.updatedAt = updatedAt
    }
}

public enum CheckpointReconciliationDecision: String, Codable, Sendable {
    case resumeAutomatically
    case requireObservation
    case requireManualConfirmation
    case switchToEmergency
    case discardCompletedSession
}

public struct CheckpointReconciliationResult: Codable, Hashable, Sendable {
    public var decision: CheckpointReconciliationDecision
    public var proposedTrackIndex: Int
    public var proposedDeck: DeckID
    public var explanation: String

    public init(
        decision: CheckpointReconciliationDecision,
        proposedTrackIndex: Int,
        proposedDeck: DeckID,
        explanation: String
    ) {
        self.decision = decision
        self.proposedTrackIndex = max(0, proposedTrackIndex)
        self.proposedDeck = proposedDeck
        self.explanation = explanation
    }
}

public struct CheckpointReconciler: Sendable {
    public init() {}

    public func reconcile(
        checkpoint: LiveCheckpoint,
        project: SetProject,
        observedTrackTitle: String?,
        seratoRunning: Bool,
        audioActive: Bool
    ) -> CheckpointReconciliationResult {
        guard checkpoint.projectID == project.id else {
            return CheckpointReconciliationResult(
                decision: .requireManualConfirmation,
                proposedTrackIndex: 0,
                proposedDeck: .a,
                explanation: "Le checkpoint appartient à un autre projet."
            )
        }

        if checkpoint.state == .completed {
            return CheckpointReconciliationResult(
                decision: .discardCompletedSession,
                proposedTrackIndex: min(checkpoint.currentTrackIndex, max(0, project.tracks.count - 1)),
                proposedDeck: checkpoint.activeDeck,
                explanation: "La session précédente était terminée."
            )
        }

        guard seratoRunning else {
            return CheckpointReconciliationResult(
                decision: .switchToEmergency,
                proposedTrackIndex: checkpoint.currentTrackIndex,
                proposedDeck: checkpoint.activeDeck,
                explanation: "Serato n'est plus disponible ; le secours local est prioritaire."
            )
        }

        let safeIndex = min(checkpoint.currentTrackIndex, max(0, project.tracks.count - 1))
        let expectedTrack = project.tracks.indices.contains(safeIndex)
            ? project.tracks[safeIndex].track
            : nil
        let observedMatches = expectedTrack.map { expected in
            guard let observedTrackTitle else { return false }
            return normalized(observedTrackTitle).contains(normalized(expected.title)) ||
                normalized(expected.title).contains(normalized(observedTrackTitle))
        } ?? false

        if observedMatches && audioActive {
            return CheckpointReconciliationResult(
                decision: .resumeAutomatically,
                proposedTrackIndex: safeIndex,
                proposedDeck: checkpoint.activeDeck,
                explanation: "Le titre et l'audio correspondent au dernier état confirmé."
            )
        }
        if observedMatches {
            return CheckpointReconciliationResult(
                decision: .requireObservation,
                proposedTrackIndex: safeIndex,
                proposedDeck: checkpoint.activeDeck,
                explanation: "Le bon titre est visible mais l'audio doit être confirmé."
            )
        }
        return CheckpointReconciliationResult(
            decision: .requireManualConfirmation,
            proposedTrackIndex: safeIndex,
            proposedDeck: checkpoint.activeDeck,
            explanation: "L'état réel de Serato ne correspond pas suffisamment au checkpoint."
        )
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public actor LiveCheckpointStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func save(_ checkpoint: LiveCheckpoint) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(checkpoint).write(to: fileURL, options: .atomic)
    }

    public func load() throws -> LiveCheckpoint? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try decoder.decode(LiveCheckpoint.self, from: Data(contentsOf: fileURL))
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
