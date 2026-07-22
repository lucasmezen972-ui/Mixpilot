#if os(macOS)
import Foundation
import MixPilotCore
import Supabase

public enum MixPilotCloudError: Error, LocalizedError {
    case notConnected
    case authenticationUnavailable
    case invalidResponse
    case emptyResponse
    case rejected(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            "Les services en ligne MixPilot ne sont pas connectés."
        case .authenticationUnavailable:
            "L’authentification en ligne est désactivée côté service. Les fonctions locales restent disponibles."
        case .invalidResponse:
            "Le service MixPilot a renvoyé une réponse invalide."
        case .emptyResponse:
            "Le service MixPilot a renvoyé une réponse vide inattendue."
        case .rejected(let statusCode):
            "Le service MixPilot a refusé la demande (HTTP \(statusCode))."
        }
    }
}

public struct MixPilotCloudCapabilitySnapshot: Codable, Hashable, Sendable {
    public var availability: String
    public var confidence: String
    public var validation: String

    public init(status: DJCapabilityStatus) {
        availability = status.availability.rawValue
        confidence = status.confidence.rawValue
        validation = status.validation.rawValue
    }
}

public struct MixPilotCloudBackendContext: Codable, Hashable, Sendable {
    public var identifier: DJBackendIdentifier
    public var softwareVersion: String?
    public var controllerName: String?
    public var mappingVersion: String?
    public var mappingSHA256: String?
    public var capabilities: [String: MixPilotCloudCapabilitySnapshot]
    public var validationStatus: String

    public init(
        identifier: DJBackendIdentifier,
        softwareVersion: String?,
        controllerName: String?,
        mappingVersion: String?,
        mappingSHA256: String?,
        capabilities: DJBackendCapabilities,
        validationStatus: String
    ) {
        self.identifier = identifier
        self.softwareVersion = softwareVersion
        self.controllerName = controllerName
        self.mappingVersion = mappingVersion
        self.mappingSHA256 = mappingSHA256
        var snapshots: [String: MixPilotCloudCapabilitySnapshot] = [:]
        for (capability, status) in capabilities.values {
            snapshots[capability.rawValue] = MixPilotCloudCapabilitySnapshot(status: status)
        }
        self.capabilities = snapshots
        self.validationStatus = validationStatus
    }

    enum CodingKeys: String, CodingKey {
        case identifier
        case softwareVersion = "software_version"
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case mappingSHA256 = "mapping_sha256"
        case capabilities
        case validationStatus = "validation_status"
    }
}

// SAFETY: The preferences object only stores an immutable UserDefaults reference.
// UserDefaults serializes concurrent reads and writes internally; no mutable Swift
// state is shared by this value.
public struct MixPilotOnlineDiagnosticsPreferences: @unchecked Sendable {
    public static let defaultsKey = "mixpilot.online-diagnostics-enabled"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get { defaults.bool(forKey: Self.defaultsKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.defaultsKey) }
    }
}

public actor MixPilotCloudService {
    public static let projectURL: URL = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "cqppkklfugbixpxwitab.supabase.co"
        return components.url ?? URL(fileURLWithPath: "/invalid-mixpilot-cloud-project")
    }()
    public static let publishableKey = "sb_publishable_X1HNpgU3xYsz3F33m-JoUw_B2QjnlB3"
    public static let updateChannel = "stable"
    public static let authenticationStorageKey = "mixpilot.cloud.auth.v1"

    private let supabase: SupabaseClient
    private let urlSession: URLSession
    private let installationID: UUID
    private let telemetryQueue: MixPilotTelemetryQueue
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let commandAgentInstanceID: String?

    private var ownerID: UUID?
    private var deviceID: UUID?
    private var sessionID: UUID?

    public init(
        supabase: SupabaseClient? = nil,
        urlSession: URLSession? = nil,
        telemetryQueueURL: URL? = nil
    ) {
        let resolvedSession = urlSession ?? URLSession(configuration: .ephemeral)
        self.urlSession = resolvedSession
        self.supabase = supabase ?? SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: MixPilotCloudIdentityPolicy.callbackURL,
                    storageKey: Self.authenticationStorageKey,
                    flowType: .pkce,
                    emitLocalSessionAsInitialSession: true
                ),
                global: .init(session: resolvedSession)
            )
        )
        installationID = Self.loadInstallationID()
        telemetryQueue = MixPilotTelemetryQueue(
            fileURL: telemetryQueueURL ?? Self.telemetryQueueURL()
        )
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        commandAgentInstanceID = try? MixPilotCloudAgentIdentityStore().loadOrCreate()
    }

    public func accountIfAvailable() async throws -> MixPilotCloudAccount? {
        guard supabase.auth.currentSession != nil else { return nil }
        let session = try await authenticatedSession()
        return MixPilotCloudAccount(userID: session.user.id, email: session.user.email)
    }

    public func requestMagicLink(email rawEmail: String) async throws -> String {
        let email = try MixPilotCloudIdentityPolicy.normalizedEmail(rawEmail)
        try await supabase.auth.signInWithOTP(
            email: email,
            redirectTo: MixPilotCloudIdentityPolicy.callbackURL,
            shouldCreateUser: true
        )
        return email
    }

    @discardableResult
    public func handleAuthenticationCallback(_ url: URL) async throws -> MixPilotCloudAccount {
        guard MixPilotCloudIdentityPolicy.acceptsCallback(url) else {
            throw MixPilotCloudIdentityError.invalidCallback
        }
        do {
            let session = try await supabase.auth.session(from: url)
            resetCloudContext()
            return MixPilotCloudAccount(userID: session.user.id, email: session.user.email)
        } catch {
            throw MixPilotCloudIdentityError.callbackRejected(String(describing: type(of: error)))
        }
    }

    public func signOut() async throws {
        await closeSession()
        try await supabase.auth.signOut()
        resetCloudContext()
    }

    @discardableResult
    public func connect(
        appVersion: String,
        appBuild: Int,
        backend: MixPilotCloudBackendContext?,
        liveMode: Bool,
        telemetryEnabled: Bool
    ) async throws -> UUID {
        let session = try await authenticatedSession()
        let userID = session.user.id
        ownerID = userID

        let deviceRows: [DeviceResponse] = try await performRequest(
            path: "rest/v1/devices",
            method: "POST",
            accessToken: session.accessToken,
            queryItems: [URLQueryItem(name: "on_conflict", value: "owner_id,installation_id")],
            prefer: "resolution=merge-duplicates,return=representation",
            body: DeviceUpsertRow(
                ownerID: userID,
                installationID: installationID,
                deviceName: Host.current().localizedName,
                appVersion: appVersion,
                appBuild: appBuild,
                backend: backend,
                updateChannel: Self.updateChannel,
                telemetryEnabled: telemetryEnabled,
                lastSeenAt: Date()
            )
        )
        guard let device = deviceRows.first else { throw MixPilotCloudError.invalidResponse }
        deviceID = device.id

        let sessionRows: [SessionResponse] = try await performRequest(
            path: "rest/v1/sessions",
            method: "POST",
            accessToken: session.accessToken,
            prefer: "return=representation",
            body: SessionInsertRow(
                ownerID: userID,
                deviceID: device.id,
                startedAt: Date(),
                appVersion: appVersion,
                appBuild: appBuild,
                backend: backend,
                liveMode: liveMode,
                telemetryEnabled: telemetryEnabled
            )
        )
        guard let cloudSession = sessionRows.first else { throw MixPilotCloudError.invalidResponse }
        sessionID = cloudSession.id
        return cloudSession.id
    }

    public func heartbeat(
        appVersion: String,
        appBuild: Int,
        backend: MixPilotCloudBackendContext?,
        liveMode: Bool,
        telemetryEnabled: Bool
    ) async throws {
        guard let ownerID, let deviceID, let sessionID else {
            throw MixPilotCloudError.notConnected
        }
        let session = try await authenticatedSession()
        let now = Date()
        let _: EmptyResponse = try await performRequest(
            path: "rest/v1/devices",
            method: "PATCH",
            accessToken: session.accessToken,
            queryItems: [
                URLQueryItem(name: "owner_id", value: "eq.\(ownerID.uuidString)"),
                URLQueryItem(name: "id", value: "eq.\(deviceID.uuidString)"),
            ],
            prefer: "return=minimal",
            body: HeartbeatRow(
                appVersion: appVersion,
                appBuild: appBuild,
                backend: backend,
                liveMode: liveMode,
                telemetryEnabled: telemetryEnabled,
                lastSeenAt: now
            )
        )
        let _: EmptyResponse = try await performRequest(
            path: "rest/v1/sessions",
            method: "PATCH",
            accessToken: session.accessToken,
            queryItems: [
                URLQueryItem(name: "owner_id", value: "eq.\(ownerID.uuidString)"),
                URLQueryItem(name: "id", value: "eq.\(sessionID.uuidString)"),
            ],
            prefer: "return=minimal",
            body: SessionHeartbeatRow(lastSeenAt: now, liveMode: liveMode)
        )

        guard telemetryEnabled else { return }
        let events = await telemetryQueue.peek(limit: 100)
        guard !events.isEmpty else { return }
        let envelopes = events.map {
            MixPilotTelemetryEnvelope(
                ownerID: ownerID,
                deviceID: deviceID,
                sessionID: sessionID,
                event: $0
            )
        }
        let _: EmptyResponse = try await performRequest(
            path: "rest/v1/telemetry_events",
            method: "POST",
            accessToken: session.accessToken,
            prefer: "return=minimal",
            body: envelopes
        )
        try await telemetryQueue.remove(
            clientEventIDs: Set(events.map(\.clientEventID))
        )
    }

    public func record(_ event: MixPilotTelemetryEvent) async throws {
        try await telemetryQueue.enqueue(event)
    }

    public func checkForUpdate(currentBuild: Int) async throws -> MixPilotCloudRelease? {
        let session = try await authenticatedSession()
        let releases: [MixPilotCloudRelease] = try await performRequest(
            path: "rest/v1/releases",
            method: "GET",
            accessToken: session.accessToken,
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "channel", value: "eq.\(Self.updateChannel)"),
                URLQueryItem(name: "enabled", value: "eq.true"),
                URLQueryItem(name: "order", value: "build.desc,published_at.desc"),
                URLQueryItem(name: "limit", value: "10"),
            ]
        )
        return releases.first {
            $0.isAvailable(currentBuild: currentBuild, installationID: installationID)
        }
    }

    public func pendingCommands() async throws -> [MixPilotCloudCommand] {
        guard let deviceID else { throw MixPilotCloudError.notConnected }
        guard let commandAgentInstanceID else { return [] }
        let session = try await authenticatedSession()
        let commands: [MixPilotCloudCommand] = try await performRequest(
            path: "rest/v1/rpc/claim_mixpilot_commands",
            method: "POST",
            accessToken: session.accessToken,
            body: ClaimCommandsRequest(
                deviceID: deviceID,
                instanceID: commandAgentInstanceID,
                limit: 20
            )
        )
        return commands
    }

    public func completeCommand(
        _ command: MixPilotCloudCommand,
        succeeded: Bool,
        result: [String: String]
    ) async throws {
        guard command.payload["device_id"] == nil ||
                command.payload["device_id"] == deviceID?.uuidString else {
            throw MixPilotCloudError.invalidResponse
        }
        guard let commandAgentInstanceID else {
            throw MixPilotCloudError.notConnected
        }
        let session = try await authenticatedSession()
        let _: EmptyResponse = try await performRequest(
            path: "rest/v1/rpc/complete_mixpilot_command",
            method: "POST",
            accessToken: session.accessToken,
            body: CompleteCommandRequest(
                commandID: command.id,
                instanceID: commandAgentInstanceID,
                succeeded: succeeded,
                result: result,
                failureCode: succeeded ? nil : result["error"]
            )
        )
    }

    public func closeSession() async {
        guard let ownerID, let sessionID else { return }
        do {
            let session = try await authenticatedSession()
            let _: EmptyResponse = try await performRequest(
                path: "rest/v1/sessions",
                method: "PATCH",
                accessToken: session.accessToken,
                queryItems: [
                    URLQueryItem(name: "owner_id", value: "eq.\(ownerID.uuidString)"),
                    URLQueryItem(name: "id", value: "eq.\(sessionID.uuidString)"),
                ],
                prefer: "return=minimal",
                body: SessionEndRow(endedAt: Date())
            )
        } catch {
            // Closing a remote session is best-effort and must never block local shutdown.
        }
        resetCloudContext()
    }

    private func authenticatedSession() async throws -> Session {
        guard supabase.auth.currentSession != nil else {
            throw MixPilotCloudIdentityError.signedOut
        }
        let session = try await supabase.auth.session
        if session.isExpired {
            return try await supabase.auth.refreshSession()
        }
        return session
    }

    private func resetCloudContext() {
        ownerID = nil
        deviceID = nil
        sessionID = nil
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
        guard let http = response as? HTTPURLResponse else {
            throw MixPilotCloudError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw MixPilotCloudError.rejected(statusCode: http.statusCode)
        }
        if data.isEmpty {
            guard Response.self == EmptyResponse.self else {
                throw MixPilotCloudError.emptyResponse
            }
            return try decoder.decode(Response.self, from: Data("{}".utf8))
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
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case mappingSHA256 = "mapping_sha256"
        case capabilities
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
        try container.encodeIfPresent(backend?.controllerName, forKey: .controllerName)
        try container.encodeIfPresent(backend?.mappingVersion, forKey: .mappingVersion)
        try container.encodeIfPresent(backend?.mappingSHA256, forKey: .mappingSHA256)
        try container.encodeIfPresent(backend?.capabilities, forKey: .capabilities)
        try container.encodeIfPresent(backend?.validationStatus, forKey: .validationStatus)
        try container.encode(updateChannel, forKey: .updateChannel)
        try container.encode(telemetryEnabled, forKey: .telemetryEnabled)
        try container.encode(lastSeenAt, forKey: .lastSeenAt)
    }
}

private struct DeviceResponse: Decodable {
    let id: UUID
}

private struct SessionInsertRow: Encodable {
    let ownerID: UUID
    let deviceID: UUID
    let startedAt: Date
    let appVersion: String
    let appBuild: Int
    let backend: MixPilotCloudBackendContext?
    let liveMode: Bool
    let telemetryEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case deviceID = "device_id"
        case startedAt = "started_at"
        case appVersion = "app_version"
        case appBuild = "app_build"
        case djBackend = "dj_backend"
        case djSoftwareVersion = "dj_software_version"
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case mappingSHA256 = "mapping_sha256"
        case capabilities
        case validationStatus = "validation_status"
        case liveMode = "live_mode"
        case telemetryEnabled = "telemetry_enabled"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(appBuild, forKey: .appBuild)
        try container.encodeIfPresent(backend?.identifier.rawValue, forKey: .djBackend)
        try container.encodeIfPresent(backend?.softwareVersion, forKey: .djSoftwareVersion)
        try container.encodeIfPresent(backend?.controllerName, forKey: .controllerName)
        try container.encodeIfPresent(backend?.mappingVersion, forKey: .mappingVersion)
        try container.encodeIfPresent(backend?.mappingSHA256, forKey: .mappingSHA256)
        try container.encodeIfPresent(backend?.capabilities, forKey: .capabilities)
        try container.encodeIfPresent(backend?.validationStatus, forKey: .validationStatus)
        try container.encode(liveMode, forKey: .liveMode)
        try container.encode(telemetryEnabled, forKey: .telemetryEnabled)
    }
}

private struct SessionResponse: Decodable {
    let id: UUID
}

private struct HeartbeatRow: Encodable {
    let appVersion: String
    let appBuild: Int
    let backend: MixPilotCloudBackendContext?
    let liveMode: Bool
    let telemetryEnabled: Bool
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case appVersion = "app_version"
        case appBuild = "app_build"
        case djBackend = "dj_backend"
        case djSoftwareVersion = "dj_software_version"
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case mappingSHA256 = "mapping_sha256"
        case capabilities
        case validationStatus = "validation_status"
        case liveMode = "live_mode"
        case telemetryEnabled = "telemetry_enabled"
        case lastSeenAt = "last_seen_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(appBuild, forKey: .appBuild)
        try container.encodeIfPresent(backend?.identifier.rawValue, forKey: .djBackend)
        try container.encodeIfPresent(backend?.softwareVersion, forKey: .djSoftwareVersion)
        try container.encodeIfPresent(backend?.controllerName, forKey: .controllerName)
        try container.encodeIfPresent(backend?.mappingVersion, forKey: .mappingVersion)
        try container.encodeIfPresent(backend?.mappingSHA256, forKey: .mappingSHA256)
        try container.encodeIfPresent(backend?.capabilities, forKey: .capabilities)
        try container.encodeIfPresent(backend?.validationStatus, forKey: .validationStatus)
        try container.encode(liveMode, forKey: .liveMode)
        try container.encode(telemetryEnabled, forKey: .telemetryEnabled)
        try container.encode(lastSeenAt, forKey: .lastSeenAt)
    }
}

private struct SessionHeartbeatRow: Encodable {
    let lastSeenAt: Date
    let liveMode: Bool

    enum CodingKeys: String, CodingKey {
        case lastSeenAt = "last_seen_at"
        case liveMode = "live_mode"
    }
}

private struct SessionEndRow: Encodable {
    let endedAt: Date

    enum CodingKeys: String, CodingKey {
        case endedAt = "ended_at"
    }
}

private struct ClaimCommandsRequest: Encodable {
    let deviceID: UUID
    let instanceID: String
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case deviceID = "p_device_id"
        case instanceID = "p_instance_id"
        case limit = "p_limit"
    }
}

private struct CompleteCommandRequest: Encodable {
    let commandID: UUID
    let instanceID: String
    let succeeded: Bool
    let result: [String: String]
    let failureCode: String?

    enum CodingKeys: String, CodingKey {
        case commandID = "p_command_id"
        case instanceID = "p_instance_id"
        case succeeded = "p_succeeded"
        case result = "p_result"
        case failureCode = "p_failure_code"
    }
}

private struct EmptyResponse: Codable {}
#endif
