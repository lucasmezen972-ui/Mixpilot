#if os(macOS)
import Foundation
import MixPilotCore
import Supabase

public enum MixPilotRemoteMappingInstallationStatus: String, Codable, Sendable {
    case discovered
    case staged
    case validated
    case applied
    case failed
    case rolledBack = "rolled_back"
    case dismissed
}

public actor MixPilotRemoteMappingService {
    private let supabase: SupabaseClient
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let installationID: UUID
    private let provenanceVerifier = MixPilotMappingProvenanceVerifier()

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.supabase = SupabaseClient(
            supabaseURL: MixPilotCloudService.projectURL,
            supabaseKey: MixPilotCloudService.publishableKey
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
                debugDescription: "Date ISO 8601 invalide : \(value)"
            )
        }
        self.decoder = decoder
    }

    public func installationIdentifier() -> UUID { installationID }

    public func checkForMappingUpdate(
        currentAppBuild: Int,
        backend: DJBackendIdentifier,
        softwareVersion: String?,
        controllerName: String
    ) async throws -> MixPilotRemoteMappingRelease? {
        let authSession = try await authenticatedSession()
        let releases: [MixPilotRemoteMappingRelease] = try await performRequest(
            path: "rest/v1/mixpilot_latest_mapping_releases",
            method: "GET",
            accessToken: authSession.accessToken,
            queryItems: [
                URLQueryItem(name: "channel", value: "eq.stable"),
                URLQueryItem(name: "software", value: "eq.\(backend.rawValue)"),
                URLQueryItem(name: "order", value: "mapping_version.desc"),
                URLQueryItem(name: "limit", value: "25")
            ]
        )

        for release in releases where release.isCompatible(
            currentAppBuild: currentAppBuild,
            backend: backend,
            softwareVersion: softwareVersion,
            controllerName: controllerName,
            installationID: installationID
        ) {
            try await verifyImmutableProvenance(
                for: release,
                accessToken: authSession.accessToken
            )
            return release
        }
        return nil
    }

    @available(*, deprecated, message: "Pass the active backend and software version explicitly")
    public func checkForMappingUpdate(
        currentAppBuild: Int,
        rekordboxVersion: String?,
        controllerName: String
    ) async throws -> MixPilotRemoteMappingRelease? {
        try await checkForMappingUpdate(
            currentAppBuild: currentAppBuild,
            backend: .rekordbox,
            softwareVersion: rekordboxVersion,
            controllerName: controllerName
        )
    }

    public func activeCompatibilityOverride(
        currentAppBuild: Int,
        backend: DJBackendIdentifier,
        softwareVersion: String?,
        controllerName: String
    ) async throws -> MixPilotCompatibilityOverride? {
        let authSession = try await authenticatedSession()
        let overrides: [MixPilotCompatibilityOverride] = try await performRequest(
            path: "rest/v1/mixpilot_active_compatibility_overrides",
            method: "GET",
            accessToken: authSession.accessToken,
            queryItems: [
                URLQueryItem(name: "channel", value: "eq.stable"),
                URLQueryItem(name: "software", value: "eq.\(backend.rawValue)"),
                URLQueryItem(name: "order", value: "published_at.desc"),
                URLQueryItem(name: "limit", value: "25")
            ]
        )
        return overrides.first {
            $0.applies(
                currentAppBuild: currentAppBuild,
                backend: backend,
                softwareVersion: softwareVersion,
                controllerName: controllerName,
                installationID: installationID
            )
        }
    }

    @available(*, deprecated, message: "Pass the active backend and software version explicitly")
    public func activeCompatibilityOverride(
        currentAppBuild: Int,
        rekordboxVersion: String?,
        controllerName: String
    ) async throws -> MixPilotCompatibilityOverride? {
        try await activeCompatibilityOverride(
            currentAppBuild: currentAppBuild,
            backend: .rekordbox,
            softwareVersion: rekordboxVersion,
            controllerName: controllerName
        )
    }

    public func recordInstallation(
        release: MixPilotRemoteMappingRelease,
        status: MixPilotRemoteMappingInstallationStatus,
        previousProfileSHA256: String? = nil,
        appliedProfileSHA256: String? = nil,
        errorCode: String? = nil,
        details: [String: String] = [:]
    ) async throws {
        let authSession = try await authenticatedSession()
        let devices: [DeviceLookupRow] = try await performRequest(
            path: "rest/v1/mixpilot_devices",
            method: "GET",
            accessToken: authSession.accessToken,
            queryItems: [
                URLQueryItem(name: "owner_id", value: "eq.\(authSession.user.id.uuidString)"),
                URLQueryItem(name: "installation_id", value: "eq.\(installationID.uuidString)"),
                URLQueryItem(name: "select", value: "id"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let device = devices.first else { return }

        let _: EmptyRemoteMappingResponse = try await performRequest(
            path: "rest/v1/mixpilot_mapping_installations",
            method: "POST",
            accessToken: authSession.accessToken,
            queryItems: [URLQueryItem(name: "on_conflict", value: "owner_id,device_id,release_id")],
            prefer: "resolution=merge-duplicates,return=minimal",
            body: [
                MappingInstallationUpsertRow(
                    ownerID: authSession.user.id,
                    deviceID: device.id,
                    releaseID: release.id,
                    status: status.rawValue,
                    previousProfileSHA256: previousProfileSHA256,
                    appliedProfileSHA256: appliedProfileSHA256,
                    errorCode: errorCode,
                    details: details,
                    appliedAt: status == .applied ? Date() : nil,
                    updatedAt: Date()
                )
            ]
        )
    }

    private func verifyImmutableProvenance(
        for release: MixPilotRemoteMappingRelease,
        accessToken: String
    ) async throws {
        let rows: [MixPilotMappingProvenance] = try await performRequest(
            path: "rest/v1/mixpilot_mapping_provenance",
            method: "GET",
            accessToken: accessToken,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(release.id.uuidString)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let provenance = rows.first else {
            throw MixPilotMappingProvenanceError.releaseMismatch
        }

        let manifestURL = try MixPilotMappingProvenanceVerifier.rawManifestURL(for: provenance)
        var request = URLRequest(url: manifestURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (manifestData, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            throw MixPilotMappingProvenanceError.malformedManifest
        }
        _ = try provenanceVerifier.validate(
            release: release,
            provenance: provenance,
            manifestData: manifestData
        )
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
            url: MixPilotCloudService.projectURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw MixPilotCloudError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(MixPilotCloudService.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
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
        if Response.self == EmptyRemoteMappingResponse.self, data.isEmpty {
            return EmptyRemoteMappingResponse() as! Response
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
}

private struct DeviceLookupRow: Decodable {
    let id: UUID
}

private struct MappingInstallationUpsertRow: Encodable {
    let ownerID: UUID
    let deviceID: UUID
    let releaseID: UUID
    let status: String
    let previousProfileSHA256: String?
    let appliedProfileSHA256: String?
    let errorCode: String?
    let details: [String: String]
    let appliedAt: Date?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case deviceID = "device_id"
        case releaseID = "release_id"
        case status
        case previousProfileSHA256 = "previous_profile_sha256"
        case appliedProfileSHA256 = "applied_profile_sha256"
        case errorCode = "error_code"
        case details
        case appliedAt = "applied_at"
        case updatedAt = "updated_at"
    }
}

private struct EmptyRemoteMappingResponse: Codable {}
#endif
