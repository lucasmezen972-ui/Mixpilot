#if os(macOS)
import Foundation
import MixPilotCore
import Supabase

public struct MixPilotCloudContext: Sendable {
    public let userID: UUID
    public let installationID: UUID
    public let deviceID: UUID
    public let sessionID: UUID

    public init(userID: UUID, installationID: UUID, deviceID: UUID, sessionID: UUID) {
        self.userID = userID
        self.installationID = installationID
        self.deviceID = deviceID
        self.sessionID = sessionID
    }
}

public enum MixPilotCloudError: Error, LocalizedError {
    case invalidResponse
    case emptyResponse
    case rejected(statusCode: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Réponse cloud invalide."
        case .emptyResponse:
            "Le cloud n’a renvoyé aucun enregistrement."
        case .rejected(let statusCode, let body):
            "Cloud MixPilot refusé (HTTP \(statusCode)) : \(body.prefix(180))"
        }
    }
}

public actor MixPilotCloudService {
    public static let projectURL = URL(string: "https://cqppkklfugbixpxwitab.supabase.co")!
    public static let publishableKey = "sb_publishable_yzMOwGa4gFubk9QIFEkaEA_E2RM9CIb"

    private let supabase: SupabaseClient
    private let urlSession: URLSession
    private let installationID: UUID
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var context: MixPilotCloudContext?
    private var telemetry: SupabaseTelemetryClient?

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.supabase = SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.publishableKey
        )
        self.installationID = Self.loadInstallationID()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }
            let regular = ISO8601DateFormatter()
            regular.formatOptions = [.withInternetDateTime]
            if let date = regular.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Date ISO 8601 invalide : \(value)"
            )
        }
        self.decoder = decoder
    }

    public func connect(
        appVersion: String,
        appBuild: Int,
        rekordboxVersion: String?,
        liveMode: Bool
    ) async throws -> MixPilotCloudContext {
        let authSession = try await authenticatedSession()
        let userID = authSession.user.id

        let deviceRows: [DeviceResponse] = try await performRequest(
            path: "rest/v1/mixpilot_devices",
            method: "POST",
            accessToken: authSession.accessToken,
            queryItems: [URLQueryItem(name: "on_conflict", value: "owner_id,installation_id")],
            prefer: "resolution=merge-duplicates,return=representation",
            body: [
                DeviceUpsertRow(
                    ownerID: userID,
                    installationID: installationID,
                    deviceName: Host.current().localizedName,
                    appVersion: appVersion,
                    appBuild: appBuild,
                    rekordboxVersion: rekordboxVersion,
                    updateChannel: "stable",
                    lastSeenAt: Date()
                )
            ]
        )
        guard let device = deviceRows.first else { throw MixPilotCloudError.emptyResponse }

        let sessionRows: [SessionResponse] = try await performRequest(
            path: "rest/v1/mixpilot_sessions",
            method: "POST",
            accessToken: authSession.accessToken,
            prefer: "return=representation",
            body: [
                SessionInsertRow(
                    ownerID: userID,
                    deviceID: device.id,
                    appVersion: appVersion,
                    appBuild: appBuild,
                    djBackend: "rekordbox",
                    rekordboxVersion: rekordboxVersion,
                    liveMode: liveMode
                )
            ]
        )
        guard let cloudSession = sessionRows.first else { throw MixPilotCloudError.emptyResponse }

        let newContext = MixPilotCloudContext(
            userID: userID,
            installationID: installationID,
            deviceID: device.id,
            sessionID: cloudSession.id
        )
        context = newContext

        let configuration = MixPilotCloudConfiguration(
            projectURL: Self.projectURL,
            publishableKey: Self.publishableKey,
            accessToken: authSession.accessToken,
            userID: userID
        )
        let client = SupabaseTelemetryClient(
            configuration: configuration,
            queueFileURL: Self.telemetryQueueURL()
        )
        telemetry = client
        try await client.record(
            MixPilotTelemetryEvent(
                category: "application",
                name: "launched",
                payload: [
                    "app_version": appVersion,
                    "app_build": String(appBuild),
                    "platform": "macos"
                ]
            )
        )
        _ = try await client.flush(
            deviceID: device.id,
            sessionID: cloudSession.id,
            accessToken: authSession.accessToken
        )

        return newContext
    }

    public func heartbeat(
        appVersion: String,
        appBuild: Int,
        rekordboxVersion: String?,
        liveMode: Bool
    ) async throws {
        guard let context else { throw MixPilotCloudError.emptyResponse }
        let authSession = try await authenticatedSession()

        let _: EmptyResponse = try await performRequest(
            path: "rest/v1/mixpilot_devices",
            method: "PATCH",
            accessToken: authSession.accessToken,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(context.deviceID.uuidString)")],
            prefer: "return=minimal",
            body: HeartbeatRow(
                appVersion: appVersion,
                appBuild: appBuild,
                rekordboxVersion: rekordboxVersion,
                lastSeenAt: Date()
            )
        )

        let _: EmptyResponse = try await performRequest(
            path: "rest/v1/mixpilot_sessions",
            method: "PATCH",
            accessToken: authSession.accessToken,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(context.sessionID.uuidString)")],
            prefer: "return=minimal",
            body: SessionHeartbeatRow(liveMode: liveMode)
        )

        if let telemetry {
            _ = try await telemetry.flush(
                deviceID: context.deviceID,
                sessionID: context.sessionID,
                accessToken: authSession.accessToken
            )
        }
    }

    public func record(_ event: MixPilotTelemetryEvent) async throws {
        guard let telemetry else { throw MixPilotCloudError.emptyResponse }
        try await telemetry.record(event)
    }

    public func checkForUpdate(currentBuild: Int) async throws -> MixPilotCloudRelease? {
        let authSession = try await authenticatedSession()
        let releases: [MixPilotCloudRelease] = try await performRequest(
            path: "rest/v1/mixpilot_latest_releases",
            method: "GET",
            accessToken: authSession.accessToken,
            queryItems: [
                URLQueryItem(name: "channel", value: "eq.stable"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let release = releases.first else { return nil }
        return release.isAvailable(currentBuild: currentBuild, installationID: installationID)
            ? release
            : nil
    }

    public func pendingCommands() async throws -> [MixPilotCloudCommand] {
        guard let context else { return [] }
        let authSession = try await authenticatedSession()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return try await performRequest(
            path: "rest/v1/mixpilot_commands",
            method: "GET",
            accessToken: authSession.accessToken,
            queryItems: [
                URLQueryItem(name: "device_id", value: "eq.\(context.deviceID.uuidString)"),
                URLQueryItem(name: "status", value: "eq.pending"),
                URLQueryItem(name: "expires_at", value: "gt.\(formatter.string(from: Date()))"),
                URLQueryItem(name: "order", value: "created_at.asc"),
                URLQueryItem(name: "limit", value: "10")
            ]
        )
    }

    public func completeCommand(
        _ command: MixPilotCloudCommand,
        succeeded: Bool,
        result: [String: String]
    ) async throws {
        let authSession = try await authenticatedSession()
        let _: EmptyResponse = try await performRequest(
            path: "rest/v1/mixpilot_commands",
            method: "PATCH",
            accessToken: authSession.accessToken,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(command.id.uuidString)")],
            prefer: "return=minimal",
            body: CommandCompletionRow(
                status: succeeded ? "completed" : "failed",
                completedAt: Date(),
                result: result
            )
        )
    }

    public func closeSession() async {
        guard let context else { return }
        do {
            let authSession = try await authenticatedSession()
            let _: EmptyResponse = try await performRequest(
                path: "rest/v1/mixpilot_sessions",
                method: "PATCH",
                accessToken: authSession.accessToken,
                queryItems: [URLQueryItem(name: "id", value: "eq.\(context.sessionID.uuidString)")],
                prefer: "return=minimal",
                body: SessionEndRow(endedAt: Date())
            )
        } catch {
            // La fermeture distante est opportuniste ; une coupure réseau ne bloque jamais l’app.
        }
    }

    private func authenticatedSession() async throws -> Session {
        do {
            return try await supabase.auth.session
        } catch {
            return try await supabase.auth.signInAnonymously()
        }
    }

    private func performRequest<Response: Decodable>(
        path: String,
        method: String,
        accessToken: String,
        queryItems: [URLQueryItem] = [],
        prefer: String? = nil
    ) async throws -> Response {
        try await performRequest(
            path: path,
            method: method,
            accessToken: accessToken,
            queryItems: queryItems,
            prefer: prefer,
            bodyData: nil
        )
    }

    private func performRequest<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        accessToken: String,
        queryItems: [URLQueryItem] = [],
        prefer: String? = nil,
        body: Body
    ) async throws -> Response {
        try await performRequest(
            path: path,
            method: method,
            accessToken: accessToken,
            queryItems: queryItems,
            prefer: prefer,
            bodyData: try encoder.encode(body)
        )
    }

    private func performRequest<Response: Decodable>(
        path: String,
        method: String,
        accessToken: String,
        queryItems: [URLQueryItem],
        prefer: String?,
        bodyData: Data?
    ) async throws -> Response {
        var components = URLComponents(
            url: Self.projectURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw MixPilotCloudError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(Self.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        request.httpBody = bodyData

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MixPilotCloudError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw MixPilotCloudError.rejected(
                statusCode: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
    }

    private static func loadInstallationID() -> UUID {
        let key = "mixpilot.cloud.installation-id"
        if let value = UserDefaults.standard.string(forKey: key),
           let id = UUID(uuidString: value) {
            return id
        }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }

    private static func telemetryQueueURL() -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return root
            .appendingPathComponent("MixPilot", isDirectory: true)
            .appendingPathComponent("Cloud", isDirectory: true)
            .appendingPathComponent("telemetry-queue.json")
    }
}

private struct DeviceUpsertRow: Encodable {
    let ownerID: UUID
    let installationID: UUID
    let deviceName: String?
    let appVersion: String
    let appBuild: Int
    let rekordboxVersion: String?
    let updateChannel: String
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case installationID = "installation_id"
        case deviceName = "device_name"
        case appVersion = "app_version"
        case appBuild = "app_build"
        case rekordboxVersion = "rekordbox_version"
        case updateChannel = "update_channel"
        case lastSeenAt = "last_seen_at"
    }
}

private struct DeviceResponse: Decodable {
    let id: UUID
}

private struct SessionInsertRow: Encodable {
    let ownerID: UUID
    let deviceID: UUID
    let appVersion: String
    let appBuild: Int
    let djBackend: String
    let rekordboxVersion: String?
    let liveMode: Bool

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case deviceID = "device_id"
        case appVersion = "app_version"
        case appBuild = "app_build"
        case djBackend = "dj_backend"
        case rekordboxVersion = "rekordbox_version"
        case liveMode = "live_mode"
    }
}

private struct SessionResponse: Decodable {
    let id: UUID
}

private struct HeartbeatRow: Encodable {
    let appVersion: String
    let appBuild: Int
    let rekordboxVersion: String?
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case appVersion = "app_version"
        case appBuild = "app_build"
        case rekordboxVersion = "rekordbox_version"
        case lastSeenAt = "last_seen_at"
    }
}

private struct SessionHeartbeatRow: Encodable {
    let liveMode: Bool

    enum CodingKeys: String, CodingKey {
        case liveMode = "live_mode"
    }
}

private struct SessionEndRow: Encodable {
    let endedAt: Date

    enum CodingKeys: String, CodingKey {
        case endedAt = "ended_at"
    }
}

private struct CommandCompletionRow: Encodable {
    let status: String
    let completedAt: Date
    let result: [String: String]

    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
        case result
    }
}

private struct EmptyResponse: Codable {
    init() {}
}
#endif
