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
        String(value.unicodeScalars.filter {
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
                .contains($0)
        }).prefix(80))
    }

    private static func sanitizePayload(_ payload: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: payload.compactMap { key, value in
            let normalizedKey = key.lowercased().replacingOccurrences(of: "-", with: "_")
            guard !forbiddenKeys.contains(normalizedKey) else { return nil }
            let safeKey = sanitizeToken(normalizedKey)
            guard !safeKey.isEmpty else { return nil }
            let safeValue = String(value.prefix(240))
            return (safeKey, safeValue)
        })
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
    private var events: [MixPilotTelemetryEvent]
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        events = (try? decoder.decode([MixPilotTelemetryEvent].self, from: Data(contentsOf: fileURL))) ?? []
    }

    public func enqueue(_ event: MixPilotTelemetryEvent) throws {
        if !events.contains(where: { $0.clientEventID == event.clientEventID }) {
            events.append(event)
        }
        if events.count > 5_000 {
            events.removeFirst(events.count - 5_000)
        }
        try persist()
    }

    public func peek(limit: Int = 100) -> [MixPilotTelemetryEvent] {
        Array(events.prefix(max(1, limit)))
    }

    public func remove(clientEventIDs: Set<UUID>) throws {
        events.removeAll { clientEventIDs.contains($0.clientEventID) }
        try persist()
    }

    public var count: Int { events.count }

    private func persist() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(events)
        try data.write(to: fileURL, options: .atomic)
    }
}
