import Foundation

public enum MixPilotTelemetrySeverity: String, Codable, CaseIterable, Sendable {
    case debug
    case info
    case warning
    case error
    case critical
}

public struct MixPilotCloudConfiguration: Codable, Hashable, Sendable {
    public var projectURL: URL
    public var publishableKey: String
    public var accessToken: String
    public var userID: UUID

    public init(projectURL: URL, publishableKey: String, accessToken: String, userID: UUID) {
        self.projectURL = projectURL
        self.publishableKey = publishableKey
        self.accessToken = accessToken
        self.userID = userID
    }
}

public struct MixPilotTelemetryEvent: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID { clientEventID }
    public var clientEventID: UUID
    public var occurredAt: Date
    public var category: String
    public var name: String
    public var severity: MixPilotTelemetrySeverity
    public var payload: [String: String]

    public init(
        clientEventID: UUID = UUID(),
        occurredAt: Date = Date(),
        category: String,
        name: String,
        severity: MixPilotTelemetrySeverity = .info,
        payload: [String: String] = [:]
    ) {
        self.clientEventID = clientEventID
        self.occurredAt = occurredAt
        self.category = Self.sanitizeToken(category)
        self.name = Self.sanitizeToken(name)
        self.severity = severity
        self.payload = Self.sanitizePayload(payload)
    }

    private static let forbiddenKeys: Set<String> = [
        "title", "track", "track_title", "artist", "album", "playlist", "playlist_name",
        "path", "file", "file_path", "location", "audio", "spotify_uri", "stream_url",
        "accessibility_text", "password", "token", "secret", "authorization"
    ]

    private static func sanitizeToken(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let filtered = value.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filtered).prefix(80))
    }

    private static func sanitizePayload(_ payload: [String: String]) -> [String: String] {
        var sanitized: [String: String] = [:]

        // Sorting makes collisions deterministic. When two source keys normalize to
        // the same safe key, the lexicographically first source key wins.
        for (key, value) in payload.sorted(by: { $0.key < $1.key }) {
            let normalizedKey = key.lowercased().replacingOccurrences(of: "-", with: "_")
            guard !forbiddenKeys.contains(normalizedKey) else { continue }
            let safeKey = sanitizeToken(normalizedKey)
            guard !safeKey.isEmpty, sanitized[safeKey] == nil else { continue }
            sanitized[safeKey] = String(value.prefix(240))
        }

        return sanitized
    }
}

public struct MixPilotTelemetryEnvelope: Codable, Hashable, Sendable {
    public var ownerID: UUID
    public var deviceID: UUID
    public var sessionID: UUID?
    public var event: MixPilotTelemetryEvent

    public init(ownerID: UUID, deviceID: UUID, sessionID: UUID?, event: MixPilotTelemetryEvent) {
        self.ownerID = ownerID
        self.deviceID = deviceID
        self.sessionID = sessionID
        self.event = event
    }
}

public actor MixPilotTelemetryQueue {
    private var events: [MixPilotTelemetryEvent] = []
    private var hasLoadedPersistedEvents = false
    private let fileURL: URL
    private let encoder: JSONEncoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
    }

    public func enqueue(_ event: MixPilotTelemetryEvent) async throws {
        await loadPersistedEventsIfNeeded()
        if !events.contains(where: { $0.clientEventID == event.clientEventID }) {
            events.append(event)
        }
        if events.count > 5_000 {
            events.removeFirst(events.count - 5_000)
        }
        try await persist()
    }

    public func peek(limit: Int = 100) async -> [MixPilotTelemetryEvent] {
        await loadPersistedEventsIfNeeded()
        return Array(events.prefix(max(1, limit)))
    }

    public func remove(clientEventIDs: Set<UUID>) async throws {
        await loadPersistedEventsIfNeeded()
        events.removeAll { clientEventIDs.contains($0.clientEventID) }
        try await persist()
    }

    public var count: Int {
        get async {
            await loadPersistedEventsIfNeeded()
            return events.count
        }
    }

    private func loadPersistedEventsIfNeeded() async {
        guard !hasLoadedPersistedEvents else { return }
        hasLoadedPersistedEvents = true
        let sourceURL = fileURL

        events = await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { return [] }

            do {
                let data = try Data(contentsOf: sourceURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode([MixPilotTelemetryEvent].self, from: data)
            } catch {
                let quarantineURL = sourceURL
                    .deletingPathExtension()
                    .appendingPathExtension("corrupt-\(UUID().uuidString).json")
                do {
                    try FileManager.default.moveItem(at: sourceURL, to: quarantineURL)
                } catch {
                    // The queue remains usable in memory even if quarantine fails.
                }
                return []
            }
        }.value
    }

    private func persist() async throws {
        let data = try encoder.encode(events)
        let destinationURL = fileURL

        try await Task.detached(priority: .utility) {
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: destinationURL, options: .atomic)
        }.value
    }
}
