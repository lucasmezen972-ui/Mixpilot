import Foundation

public struct LiveCheckpoint: Identifiable, Codable, Hashable, Sendable {
    public static let currentFormatVersion = 2

    public let id: UUID
    public var formatVersion: Int
    public var projectID: UUID
    public var projectName: String
    public var backend: DJBackendIdentifier?
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
        formatVersion: Int = Self.currentFormatVersion,
        projectID: UUID,
        projectName: String,
        backend: DJBackendIdentifier? = nil,
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
        self.formatVersion = max(1, formatVersion)
        self.projectID = projectID
        self.projectName = projectName
        self.backend = backend
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

    public var requiresBackendConfirmation: Bool {
        backend == nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case formatVersion
        case projectID
        case projectName
        case backend
        case currentTrackIndex
        case activeDeck
        case completedTransitionCount
        case nextTransitionIndex
        case state
        case lastConfirmedTrackID
        case lastCommand
        case emergencyPlaybackActive
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        projectID = try container.decode(UUID.self, forKey: .projectID)
        projectName = try container.decode(String.self, forKey: .projectName)
        backend = try container.decodeIfPresent(DJBackendIdentifier.self, forKey: .backend)
        currentTrackIndex = max(0, try container.decode(Int.self, forKey: .currentTrackIndex))
        activeDeck = try container.decode(DeckID.self, forKey: .activeDeck)
        completedTransitionCount = max(
            0,
            try container.decode(Int.self, forKey: .completedTransitionCount)
        )
        nextTransitionIndex = try container.decodeIfPresent(Int.self, forKey: .nextTransitionIndex)
            .map { max(0, $0) }
        state = try container.decode(AutopilotState.self, forKey: .state)
        lastConfirmedTrackID = try container.decodeIfPresent(UUID.self, forKey: .lastConfirmedTrackID)
        lastCommand = try container.decodeIfPresent(String.self, forKey: .lastCommand)
        emergencyPlaybackActive = try container.decodeIfPresent(
            Bool.self,
            forKey: .emergencyPlaybackActive
        ) ?? false
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        if formatVersion < Self.currentFormatVersion {
            formatVersion = Self.currentFormatVersion
        }
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
        activeBackend: DJBackendIdentifier?,
        backendRunning: Bool,
        observedTrackTitle: String?,
        audioActive: Bool
    ) -> CheckpointReconciliationResult {
        guard checkpoint.formatVersion <= LiveCheckpoint.currentFormatVersion else {
            return manual(
                checkpoint,
                project: project,
                explanation: "Le checkpoint provient d’une version plus récente de MixPilot. Aucune reprise n’est autorisée."
            )
        }

        guard checkpoint.projectID == project.id else {
            return manual(
                checkpoint,
                explanation: "Le checkpoint appartient à un autre projet."
            )
        }

        if checkpoint.state == .completed {
            return CheckpointReconciliationResult(
                decision: .discardCompletedSession,
                proposedTrackIndex: safeIndex(checkpoint, project: project),
                proposedDeck: checkpoint.activeDeck,
                explanation: "La session précédente était terminée."
            )
        }

        guard let checkpointBackend = checkpoint.backend,
              let projectBackend = project.backend,
              let activeBackend else {
            return manual(
                checkpoint,
                explanation: "L’ancien état ne précise pas assez clairement le logiciel DJ utilisé. Choisis le backend et vérifie les decks manuellement."
            )
        }

        guard checkpointBackend == projectBackend,
              projectBackend == activeBackend else {
            return manual(
                checkpoint,
                explanation: "Le logiciel DJ actif ne correspond pas au projet et au checkpoint sauvegardés. Aucune reprise automatique n’est autorisée."
            )
        }

        guard backendRunning else {
            return CheckpointReconciliationResult(
                decision: .switchToEmergency,
                proposedTrackIndex: safeIndex(checkpoint, project: project),
                proposedDeck: checkpoint.activeDeck,
                explanation: "\(activeBackend.displayName) n’est plus disponible ; le secours local est prioritaire."
            )
        }

        let index = safeIndex(checkpoint, project: project)
        guard project.tracks.indices.contains(index) else {
            return manual(
                checkpoint,
                project: project,
                explanation: "Le morceau sauvegardé n’existe plus dans le projet."
            )
        }
        let expectedTrack = project.tracks[index].track

        guard checkpoint.lastConfirmedTrackID == expectedTrack.id else {
            return manual(
                checkpoint,
                project: project,
                explanation: "L’identité du dernier morceau confirmé ne correspond plus au projet."
            )
        }

        guard isRecoverableState(checkpoint.state) else {
            return manual(
                checkpoint,
                project: project,
                explanation: "La session s’est arrêtée pendant un état qui exige une vérification complète des decks."
            )
        }

        let observedMatches: Bool = {
            guard let observedTrackTitle else { return false }
            return normalized(observedTrackTitle).contains(normalized(expectedTrack.title)) ||
                normalized(expectedTrack.title).contains(normalized(observedTrackTitle))
        }()

        if observedMatches && audioActive {
            return manual(
                checkpoint,
                project: project,
                explanation: "Le backend, le titre et l’audio semblent correspondre. Confirme manuellement les decks sur le Mac avant toute reprise."
            )
        }
        if observedMatches {
            return CheckpointReconciliationResult(
                decision: .requireObservation,
                proposedTrackIndex: index,
                proposedDeck: checkpoint.activeDeck,
                explanation: "Le bon titre semble visible, mais l’audio et les decks doivent encore être confirmés sur le Mac."
            )
        }
        return manual(
            checkpoint,
            project: project,
            explanation: "L’état réel de \(activeBackend.displayName) ne correspond pas suffisamment au checkpoint."
        )
    }

    @available(*, deprecated, message: "Pass the active DJ backend explicitly")
    public func reconcile(
        checkpoint: LiveCheckpoint,
        project: SetProject,
        observedTrackTitle: String?,
        seratoRunning: Bool,
        audioActive: Bool
    ) -> CheckpointReconciliationResult {
        reconcile(
            checkpoint: checkpoint,
            project: project,
            activeBackend: .serato,
            backendRunning: seratoRunning,
            observedTrackTitle: observedTrackTitle,
            audioActive: audioActive
        )
    }

    private func isRecoverableState(_ state: AutopilotState) -> Bool {
        switch state {
        case .playing, .paused, .waitingForTransition:
            true
        default:
            false
        }
    }

    private func manual(
        _ checkpoint: LiveCheckpoint,
        project: SetProject? = nil,
        explanation: String
    ) -> CheckpointReconciliationResult {
        CheckpointReconciliationResult(
            decision: .requireManualConfirmation,
            proposedTrackIndex: project.map { safeIndex(checkpoint, project: $0) }
                ?? checkpoint.currentTrackIndex,
            proposedDeck: checkpoint.activeDeck,
            explanation: explanation
        )
    }

    private func safeIndex(_ checkpoint: LiveCheckpoint, project: SetProject) -> Int {
        min(checkpoint.currentTrackIndex, max(0, project.tracks.count - 1))
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
