#if os(macOS)
import Foundation
import MixPilotCore

struct MixPilotCloudDeviceUpsertRow: Encodable {
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

struct MixPilotCloudDeviceResponse: Decodable { let id: UUID }

struct MixPilotCloudHeartbeatRow: Encodable {
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
#endif
