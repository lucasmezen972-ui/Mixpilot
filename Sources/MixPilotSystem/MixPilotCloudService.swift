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

public struct MixPilotCloudCapabilitySnapshot: Codable, Hashable, Sendable {
    public var availability: String
    public var confidence: String
    public var validation: String
    public var method: String?

    public init(status: DJCapabilityStatus) {
        availability = status.availability.rawValue
        confidence = status.confidence.rawValue
        validation = status.validation.rawValue
        method = status.method?.rawValue
    }
}

public struct MixPilotCloudBackendContext: Codable, Hashable, Sendable {
    public var identifier: DJBackendIdentifier
    public var softwareVersion: String?
    public var controllerName: String?
    public var mappingVersion: String?
    public var mappingSHA256: String?
    public var capabilities: [String: MixPilotCloudCapabilitySnapshot]
    public var validationStatus: String?

    public init(
        identifier: DJBackendIdentifier,
        softwareVersion: String? = nil,
        controllerName: String? = nil,
        mappingVersion: String? = nil,
        mappingSHA256: String? = nil,
        capabilities: DJBackendCapabilities = DJBackendCapabilities(),
        validationStatus: String? = nil
    ) {
        self.identifier = identifier
        self.softwareVersion = softwareVersion
        self.controllerName = controllerName
        self.mappingVersion = mappingVersion
        self.mappingSHA256 = mappingSHA256
        self.capabilities = Dictionary(uniqueKeysWithValues: capabilities.values.map {
            ($0.key.rawValue, MixPilotCloudCapabilitySnapshot(status: $0.value))
        })
        self.validationStatus = validationStatus
    }
}

public struct MixPilotOnlineDiagnosticsPreferences: Sendable {
    public static let defaultsKey = "MixPilotOnlineDiagnosticsEnabledV1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get { defaults.bool(forKey: Self.defaultsKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.defaultsKey) }
    }
}

public enum MixPilotCloudError: Error, LocalizedError {
    case invalidResponse
    case emptyResponse
    case rejected(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse, .emptyResponse:
            "Les services en ligne n’ont pas répondu correctement. Le Live local reste disponible."
        case .rejected:
            "Les services en ligne ont refusé la demande. Réessaie plus tard ; le Live local n’est pas affecté."
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
    private var telemetryEnabled = false
    private var backendContext: MixPilotCloudBackendContext?

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
            if let date = fractional.date(from: value) { return date }
            let regular = ISO8601DateFormatter()
            regular.formatOptions = [.withInternetDateTime]
            if let date = regular.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Date ISO 8601 invalide"
            )
        }
        self.decoder = decoder
    }

    public func connect(
        appVersion: String,
        appBuild: Int,
        backend: MixPilotCloudBackendContext?,
        liveMode: Bool,
        telemetryEnabled: Bool
    ) async throws -> MixPilotCloudContext {
        self.backendContext = backend
        self.telemetryEnabled = telemetryEnabled
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
                    backend: backend,
                    updateChannel: "stable",
                    telemetryEnabled: telemetryEnabled,
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
                    backend: backend,
                    liveMode: liveMode,
                    telemetryEnabled: telemetryEnabled
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

        if telemetryEnabled {
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
                        "platform": "macos",
                        "dj_backend": backend?.identifier.rawValue ?? "not_selected"
                    ]
                )
            )
            _ = try await client.flush(
                deviceID: device.id,
                sessionID: cloudSession.id,
                accessToken: authSession.accessToken
            )
        } else {
            telemetry = nil
        }
        return newContext
    }

    public func heartbeat(
        appVersion: String,
        appBuild: Int,
        backend: MixPilotCloudBackendContext?,
        liveMode: Bool,
        telemetryEnabled: Bool
    ) async throws {
        guard let context else { throw MixPilotCloudError.emptyResponse }
        self.backendContext = backend
        self.telemetryEnabled = telemetryEnabled
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
                backend: backend,
                telemetryEnabled: telemetryEnabled,
                lastSeenAt: Date()
            )
        )

        let _: EmptyResponse = try await performRequest(
            path: "rest/v1/mixpilot_sessions",
            method: "PATCH",
            accessToken: authSession.accessToken,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(context.sessionID.uuidString)")],
            prefer: "return=minimal",
            body: SessionHeartbeatRow(
                backend: backend,
                liveMode: liveMode,
                telemetryEnabled: telemetryEnabled
            )
        )

        if telemetryEnabled, let telemetry {
            _ = try await telemetry.flush(
                deviceID: context.deviceID,
                sessionID: context.sessionID,
                accessToken: authSession.accessToken
            )
        }
    }

    public func record(_ event: MixPilotTelemetryEvent) async throws {
        guard telemetryEnabled, let telemetry else { return }
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
        return release.isAvailable(currentBuild: currentBuild, installationID: installationID) ? release : nil
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
            // Session closure is opportunistic and never blocks local use.
        }
    }

    private func authenticatedSession() async throws -> Session {
        do { return try await supabase.auth.session }
        catch { return try await supabase.auth.signInAnonymously() }
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
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        request.httpBody = bodyData

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MixPilotCloudError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            throw MixPilotCloudError.rejected(statusCode: http.statusCode)
        }
        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
    }

    private static func loadInstallationID() -> UUID {
        let key = "mixpilot.cloud.installation-id"
        if let value = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: value) {
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
            .appendingPathComponent("Online Diagnostics", isDirectory: true)
            .appendingPathComponent("telemetry-queue.json")
    }
}

private struct DeviceUpsertRow: Encodable {
    let ownerID: UUID
    let installationID: UUID
    let deviceName: String?
    let appVersion: String
    let appBuild: Int
    let backend: MixPilotCloudBackendContext?
    let updateChannel: String
    let telemetryEnabled: Bool
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case installationID = "installation_id"
        case deviceName = "device_name"
        case appVersion = "app_version"
        case appBuild = "app_build"
        case djBackend = "dj_backend"
        case djSoftwareVersion = "dj_software_version"
        case rekordboxVersion = "rekordbox_version"
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case mappingSHA256 = "mapping_sha256"
        case capabilitiesSnapshot = "capabilities_snapshot"
        case validationStatus = "validation_status"
        case updateChannel = "update_channel"
        case telemetryEnabled = "telemetry_enabled"
        case lastSeenAt = "last_seen_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(installationID, forKey: .installationID)
        try container.encodeIfPresent(deviceName, forKey: .deviceName)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(appBuild, forKey: .appBuild)
        try container.encodeIfPresent(backend?.identifier.rawValue, forKey: .djBackend)
        try container.encodeIfPresent(backend?.softwareVersion, forKey: .djSoftwareVersion)
        if backend?.identifier == .rekordbox {
            try container.encodeIfPresent(backend?.softwareVersion, forKey: .rekordboxVersion)
        }
        try container.encodeIfPresent(backend?.controllerName, forKey: .controllerName)
        try container.encodeIfPresent(backend?.mappingVersion, forKey: .mappingVersion)
        try container.encodeIfPresent(backend?.mappingSHA256, forKey: .mappingSHA256)
        try container.encode(backend?.capabilities ?? [:], forKey: .capabilitiesSnapshot)
        try container.encodeIfPresent(backend?.validationStatus, forKey: .validationStatus)
        try container.encode(updateChannel, forKey: .updateChannel)
        try container.encode(telemetryEnabled, forKey: .telemetryEnabled)
        try container.encode(lastSeenAt, forKey: .lastSeenAt)
    }
}

private struct DeviceResponse: Decodable { let id: UUID }

private struct SessionInsertRow: Encodable {
    let ownerID: UUID
    let deviceID: UUID
    let appVersion: String
    let appBuild: Int
    let backend: MixPilotCloudBackendContext?
    let liveMode: Bool
    let telemetryEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case deviceID = "device_id"
        case appVersion = "app_version"
        case appBuild = "app_build"
        case djBackend = "dj_backend"
        case djSoftwareVersion = "dj_software_version"
        case rekordboxVersion = "rekordbox_version"
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case mappingSHA256 = "mapping_sha256"
        case capabilitiesSnapshot = "capabilities_snapshot"
        case validationStatus = "validation_status"
        case liveMode = "live_mode"
        case telemetryEnabled = "telemetry_enabled"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(appBuild, forKey: .appBuild)
        try container.encodeIfPresent(backend?.identifier.rawValue, forKey: .djBackend)
        try container.encodeIfPresent(backend?.softwareVersion, forKey: .djSoftwareVersion)
        if backend?.identifier == .rekordbox {
            try container.encodeIfPresent(backend?.softwareVersion, forKey: .rekordboxVersion)
        }
        try container.encodeIfPresent(backend?.controllerName, forKey: .controllerName)
        try container.encodeIfPresent(backend?.mappingVersion, forKey: .mappingVersion)
        try container.encodeIfPresent(backend?.mappingSHA256, forKey: .mappingSHA256)
        try container.encode(backend?.capabilities ?? [:], forKey: .capabilitiesSnapshot)
        try container.encodeIfPresent(backend?.validationStatus, forKey: .validationStatus)
        try container.encode(liveMode, forKey: .liveMode)
        try container.encode(telemetryEnabled, forKey: .telemetryEnabled)
    }
}

private struct SessionResponse: Decodable { let id: UUID }

private struct HeartbeatRow: Encodable {
    let appVersion: String
    let appBuild: Int
    let backend: MixPilotCloudBackendContext?
    let telemetryEnabled: Bool
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case appVersion = "app_version"
        case appBuild = "app_build"
        case djBackend = "dj_backend"
        case djSoftwareVersion = "dj_software_version"
        case rekordboxVersion = "rekordbox_version"
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case mappingSHA256 = "mapping_sha256"
        case capabilitiesSnapshot = "capabilities_snapshot"
        case validationStatus = "validation_status"
        case telemetryEnabled = "telemetry_enabled"
        case lastSeenAt = "last_seen_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(appBuild, forKey: .appBuild)
        try container.encodeIfPresent(backend?.identifier.rawValue, forKey: .djBackend)
        try container.encodeIfPresent(backend?.softwareVersion, forKey: .djSoftwareVersion)
        if backend?.identifier == .rekordbox {
            try container.encodeIfPresent(backend?.softwareVersion, forKey: .rekordboxVersion)
        }
        try container.encodeIfPresent(backend?.controllerName, forKey: .controllerName)
        try container.encodeIfPresent(backend?.mappingVersion, forKey: .mappingVersion)
        try container.encodeIfPresent(backend?.mappingSHA256, forKey: .mappingSHA256)
        try container.encode(backend?.capabilities ?? [:], forKey: .capabilitiesSnapshot)
        try container.encodeIfPresent(backend?.validationStatus, forKey: .validationStatus)
        try container.encode(telemetryEnabled, forKey: .telemetryEnabled)
        try container.encode(lastSeenAt, forKey: .lastSeenAt)
    }
}

private struct SessionHeartbeatRow: Encodable {
    let backend: MixPilotCloudBackendContext?
    let liveMode: Bool
    let telemetryEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case djBackend = "dj_backend"
        case djSoftwareVersion = "dj_software_version"
        case rekordboxVersion = "rekordbox_version"
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case mappingSHA256 = "mapping_sha256"
        case capabilitiesSnapshot = "capabilities_snapshot"
        case validationStatus = "validation_status"
        case liveMode = "live_mode"
        case telemetryEnabled = "telemetry_enabled"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(backend?.identifier.rawValue, forKey: .djBackend)
        try container.encodeIfPresent(backend?.softwareVersion, forKey: .djSoftwareVersion)
        if backend?.identifier == .rekordbox {
            try container.encodeIfPresent(backend?.softwareVersion, forKey: .rekordboxVersion)
        }
        try container.encodeIfPresent(backend?.controllerName, forKey: .controllerName)
        try container.encodeIfPresent(backend?.mappingVersion, forKey: .mappingVersion)
        try container.encodeIfPresent(backend?.mappingSHA256, forKey: .mappingSHA256)
        try container.encode(backend?.capabilities ?? [:], forKey: .capabilitiesSnapshot)
        try container.encodeIfPresent(backend?.validationStatus, forKey: .validationStatus)
        try container.encode(liveMode, forKey: .liveMode)
        try container.encode(telemetryEnabled, forKey: .telemetryEnabled)
    }
}

private struct SessionEndRow: Encodable {
    let endedAt: Date
    enum CodingKeys: String, CodingKey { case endedAt = "ended_at" }
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

private struct EmptyResponse: Codable { init() {} }
#endif
