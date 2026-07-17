import Foundation

public enum CueMarkerType: String, Codable, CaseIterable, Sendable {
    case start
    case mixIn
    case vocalIn
    case drop
    case breakSection
    case mixOut
    case endSafe
    case emergencyLoopStart
    case emergencyLoopEnd
}

public enum CueOrigin: String, Codable, Sendable {
    case automaticMetadata
    case automaticAudio
    case backend
    case manual

    /// Historical origin preserved for older project files.
    @available(*, deprecated, renamed: "backend")
    case serato
}

public struct CueMarker: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var type: CueMarkerType
    public var time: TimeInterval
    public var beatIndex: Int?
    public var barIndex: Int?
    public var phraseIndex: Int?
    public var confidence: Double
    public var origin: CueOrigin

    public init(
        id: UUID = UUID(),
        type: CueMarkerType,
        time: TimeInterval,
        beatIndex: Int? = nil,
        barIndex: Int? = nil,
        phraseIndex: Int? = nil,
        confidence: Double,
        origin: CueOrigin
    ) {
        self.id = id
        self.type = type
        self.time = max(0, time)
        self.beatIndex = beatIndex
        self.barIndex = barIndex
        self.phraseIndex = phraseIndex
        self.confidence = confidence.clamped(to: 0...1)
        self.origin = origin
    }
}

public struct TrackAnalysis: Codable, Hashable, Sendable {
    public var bpmConfidence: Double
    public var downbeatConfidence: Double
    public var phraseConfidence: Double
    public var structureConfidence: Double
    public var suggestedPlayDuration: TimeInterval
    public var markers: [CueMarker]
    public var warnings: [String]

    public init(
        bpmConfidence: Double,
        downbeatConfidence: Double,
        phraseConfidence: Double,
        structureConfidence: Double,
        suggestedPlayDuration: TimeInterval,
        markers: [CueMarker],
        warnings: [String] = []
    ) {
        self.bpmConfidence = bpmConfidence.clamped(to: 0...1)
        self.downbeatConfidence = downbeatConfidence.clamped(to: 0...1)
        self.phraseConfidence = phraseConfidence.clamped(to: 0...1)
        self.structureConfidence = structureConfidence.clamped(to: 0...1)
        self.suggestedPlayDuration = max(0, suggestedPlayDuration)
        self.markers = markers.sorted { $0.time < $1.time }
        self.warnings = warnings
    }

    public var overallConfidence: Double {
        (bpmConfidence * 0.25) +
            (downbeatConfidence * 0.3) +
            (phraseConfidence * 0.25) +
            (structureConfidence * 0.2)
    }
}

public struct PreparedTrack: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID { track.id }
    public var track: Track
    public var analysis: TrackAnalysis

    public init(track: Track, analysis: TrackAnalysis) {
        self.track = track
        self.analysis = analysis
    }
}

public struct SetProject: Identifiable, Codable, Hashable, Sendable {
    public static let currentFormatVersion = 2

    public let id: UUID
    public var formatVersion: Int
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date
    public var tracks: [PreparedTrack]
    public var transitions: [TransitionPlan]
    public var locked: Bool
    public var backend: DJBackendIdentifier?

    public init(
        id: UUID = UUID(),
        formatVersion: Int = Self.currentFormatVersion,
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tracks: [PreparedTrack],
        transitions: [TransitionPlan],
        locked: Bool = false,
        backend: DJBackendIdentifier? = nil
    ) {
        self.id = id
        self.formatVersion = max(1, formatVersion)
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tracks = tracks
        self.transitions = transitions
        self.locked = locked
        self.backend = backend
    }

    public var duration: TimeInterval {
        tracks.reduce(0) { $0 + $1.analysis.suggestedPlayDuration }
    }

    public var reviewTransitionCount: Int {
        transitions.filter { $0.confidence < 75 }.count
    }

    public var requiresBackendSelection: Bool {
        backend == nil
    }

    public mutating func selectBackend(_ identifier: DJBackendIdentifier) {
        if backend != identifier {
            locked = false
        }
        backend = identifier
        formatVersion = Self.currentFormatVersion
        updatedAt = Date()
    }

    public mutating func lock() {
        locked = true
        formatVersion = Self.currentFormatVersion
        updatedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, formatVersion, name, createdAt, updatedAt, tracks, transitions, locked, backend
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        tracks = try container.decode([PreparedTrack].self, forKey: .tracks)
        transitions = try container.decode([TransitionPlan].self, forKey: .transitions)
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        backend = try container.decodeIfPresent(DJBackendIdentifier.self, forKey: .backend)

        // Missing backend is intentionally preserved. A legacy project does not
        // prove which application should control its Live.
        if formatVersion < Self.currentFormatVersion {
            formatVersion = Self.currentFormatVersion
        }
    }
}

public struct SetPreparationSummary: Hashable, Sendable {
    public var trackCount: Int
    public var transitionCount: Int
    public var lowConfidenceTrackCount: Int
    public var lowConfidenceTransitionCount: Int
    public var estimatedDuration: TimeInterval

    public init(project: SetProject) {
        trackCount = project.tracks.count
        transitionCount = project.transitions.count
        lowConfidenceTrackCount = project.tracks.filter { $0.analysis.overallConfidence < 0.75 }.count
        lowConfidenceTransitionCount = project.transitions.filter { $0.confidence < 75 }.count
        estimatedDuration = project.duration
    }
}

public struct SetPreparationEngine: Sendable {
    private let planner: TransitionPlanner

    public init(planner: TransitionPlanner = TransitionPlanner()) {
        self.planner = planner
    }

    public func prepare(
        name: String,
        tracks: [Track],
        backend: DJBackendIdentifier? = nil
    ) -> SetProject {
        let prepared = tracks.map {
            PreparedTrack(track: $0, analysis: analyzeMetadata(for: $0))
        }
        return SetProject(
            name: name,
            tracks: prepared,
            transitions: planner.planSet(tracks),
            backend: backend
        )
    }

    public func analyzeMetadata(for track: Track) -> TrackAnalysis {
        let safeBPM = max(40, track.bpm)
        let beatDuration = 60.0 / safeBPM
        let phraseDuration = beatDuration * 32
        let introLength = min(max(beatDuration * 16, 6), max(6, track.duration * 0.12))
        let outroLength = min(max(phraseDuration, 12), max(12, track.duration * 0.18))
        let mixOut = max(introLength + phraseDuration, track.duration - outroLength)
        let endSafe = max(mixOut, track.duration - max(3, beatDuration * 8))
        let loopStart = max(introLength, mixOut - phraseDuration)
        let loopEnd = min(endSafe, loopStart + phraseDuration)
        let estimatedVocalIn = track.vocalDensity > 0.65
            ? introLength
            : min(track.duration * 0.2, introLength + phraseDuration)
        let estimatedDrop = min(
            track.duration * 0.35,
            max(estimatedVocalIn, introLength + phraseDuration)
        )

        var warnings: [String] = []
        if track.bpm <= 0 { warnings.append("BPM manquant ou invalide") }
        if track.duration < 60 { warnings.append("Morceau très court : transition à vérifier") }
        if track.vocalDensity > 0.82 { warnings.append("Forte densité vocale : limiter la superposition") }

        let metadataQuality = (track.bpm > 0 && track.duration > 0) ? 0.82 : 0.45
        let phraseConfidence = track.duration >= phraseDuration * 3 ? 0.72 : 0.55
        let structureConfidence = (0.68 + ((1 - track.vocalDensity) * 0.12)).clamped(to: 0...0.82)

        let markers = [
            CueMarker(type: .start, time: 0, beatIndex: 0, barIndex: 0, phraseIndex: 0, confidence: 0.95, origin: .automaticMetadata),
            CueMarker(type: .mixIn, time: introLength, confidence: phraseConfidence, origin: .automaticMetadata),
            CueMarker(type: .vocalIn, time: estimatedVocalIn, confidence: 0.58, origin: .automaticMetadata),
            CueMarker(type: .drop, time: estimatedDrop, confidence: 0.55, origin: .automaticMetadata),
            CueMarker(type: .mixOut, time: mixOut, confidence: phraseConfidence, origin: .automaticMetadata),
            CueMarker(type: .endSafe, time: endSafe, confidence: 0.8, origin: .automaticMetadata),
            CueMarker(type: .emergencyLoopStart, time: loopStart, confidence: 0.64, origin: .automaticMetadata),
            CueMarker(type: .emergencyLoopEnd, time: loopEnd, confidence: 0.64, origin: .automaticMetadata),
        ]

        return TrackAnalysis(
            bpmConfidence: metadataQuality,
            downbeatConfidence: 0.55,
            phraseConfidence: phraseConfidence,
            structureConfidence: structureConfidence,
            suggestedPlayDuration: max(30, mixOut - introLength),
            markers: markers,
            warnings: warnings
        )
    }
}

public actor JSONProjectStore {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL) {
        self.directory = directory
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func save(_ project: SetProject) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(project.id.uuidString).mixpilot.json")
        try encoder.encode(project).write(to: url, options: .atomic)
        return url
    }

    public func load(id: UUID) throws -> SetProject {
        let url = directory.appendingPathComponent("\(id.uuidString).mixpilot.json")
        return try decoder.decode(SetProject.self, from: Data(contentsOf: url))
    }

    public func list() throws -> [SetProject] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
        .compactMap { try? decoder.decode(SetProject.self, from: Data(contentsOf: $0)) }
        .sorted { $0.updatedAt > $1.updatedAt }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
