#if os(macOS)
import Foundation
import MixPilotCore

public enum SupabaseTelemetryError: Error, LocalizedError {
    case invalidResponse
    case rejected(statusCode: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Réponse Supabase invalide."
        case .rejected(let statusCode, let body):
            "Supabase a refusé la télémétrie (HTTP \(statusCode)) : \(body.prefix(180))"
        }
    }
}

public actor SupabaseTelemetryClient {
    private let configuration: MixPilotCloudConfiguration
    private let queue: MixPilotTelemetryQueue
    private let session: URLSession

    public init(
        configuration: MixPilotCloudConfiguration,
        queueFileURL: URL,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.queue = MixPilotTelemetryQueue(fileURL: queueFileURL)
        self.session = session
    }

    public func record(_ event: MixPilotTelemetryEvent) async throws {
        try await queue.enqueue(event)
    }

    public func flush(deviceID: UUID, sessionID: UUID?, limit: Int = 100) async throws -> Int {
        let events = await queue.peek(limit: limit)
        guard !events.isEmpty else { return 0 }

        let rows = events.map { event in
            EventRow(
                ownerID: configuration.userID,
                deviceID: deviceID,
                sessionID: sessionID,
                occurredAt: event.occurredAt,
                category: event.category,
                name: event.name,
                severity: event.severity.rawValue,
                payload: event.payload,
                clientEventID: event.clientEventID
            )
        }

        var request = URLRequest(
            url: configuration.projectURL
                .appendingPathComponent("rest/v1/mixpilot_events")
        )
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.supabaseEncoder.encode(rows)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseTelemetryError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw SupabaseTelemetryError.rejected(
                statusCode: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        let ids = Set(events.map(\.clientEventID))
        try await queue.remove(clientEventIDs: ids)
        return events.count
    }

    public var pendingCount: Int {
        get async { await queue.count }
    }
}

private struct EventRow: Encodable {
    let ownerID: UUID
    let deviceID: UUID
    let sessionID: UUID?
    let occurredAt: Date
    let category: String
    let name: String
    let severity: String
    let payload: [String: String]
    let clientEventID: UUID

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case deviceID = "device_id"
        case sessionID = "session_id"
        case occurredAt = "occurred_at"
        case category
        case name
        case severity
        case payload
        case clientEventID = "client_event_id"
    }
}

private extension JSONEncoder {
    static var supabaseEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
#endif
