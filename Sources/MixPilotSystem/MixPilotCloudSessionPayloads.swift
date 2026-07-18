#if os(macOS)
import Foundation
import MixPilotCore

struct MixPilotCloudSessionInsertRow: Encodable {
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

struct MixPilotCloudSessionResponse: Decodable { let id: UUID }

struct MixPilotCloudSessionHeartbeatRow: Encodable {
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

struct MixPilotCloudSessionEndRow: Encodable {
    let endedAt: Date
    enum CodingKeys: String, CodingKey { case endedAt = "ended_at" }
}

struct MixPilotCloudCommandClaimRequest: Encodable {
    let deviceID: UUID
    let instanceID: String
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case deviceID = "p_device_id"
        case instanceID = "p_instance_id"
        case limit = "p_limit"
    }
}

struct MixPilotCloudCommandCompletionRequest: Encodable {
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

struct MixPilotCloudEmptyResponse: Codable { init() {} }
#endif
