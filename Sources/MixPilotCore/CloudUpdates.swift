import Foundation

public struct MixPilotCloudRelease: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let channel: String
    public let version: String
    public let build: Int
    public let minimumMacOS: String
    public let downloadURL: URL
    public let releasePageURL: URL?
    public let sha256: String
    public let signature: String?
    public let releaseNotes: String
    public let mandatory: Bool
    public let rolloutPercentage: Int
    public let publishedAt: Date

    public init(
        id: UUID,
        channel: String,
        version: String,
        build: Int,
        minimumMacOS: String,
        downloadURL: URL,
        releasePageURL: URL?,
        sha256: String,
        signature: String?,
        releaseNotes: String,
        mandatory: Bool,
        rolloutPercentage: Int,
        publishedAt: Date
    ) {
        self.id = id
        self.channel = channel
        self.version = version
        self.build = build
        self.minimumMacOS = minimumMacOS
        self.downloadURL = downloadURL
        self.releasePageURL = releasePageURL
        self.sha256 = sha256
        self.signature = signature
        self.releaseNotes = releaseNotes
        self.mandatory = mandatory
        self.rolloutPercentage = rolloutPercentage
        self.publishedAt = publishedAt
    }

    public func isAvailable(currentBuild: Int, installationID: UUID) -> Bool {
        guard build > currentBuild else { return false }
        guard rolloutPercentage > 0 else { return false }
        guard hasRequiredPublisherMetadata else { return false }
        guard Self.isAllowedDistributionURL(downloadURL) else { return false }
        if let releasePageURL, !Self.isAllowedDistributionURL(releasePageURL) {
            return false
        }
        guard rolloutPercentage < 100 else { return true }
        return Self.rolloutBucket(for: installationID) < rolloutPercentage
    }

    /// MixPilot currently opens a release page instead of silently installing
    /// an update. An untrusted URL therefore falls back to the official project
    /// releases page rather than being opened from cloud-controlled metadata.
    public var preferredOpenURL: URL {
        if let releasePageURL, Self.isAllowedDistributionURL(releasePageURL) {
            return releasePageURL
        }
        if Self.isAllowedDistributionURL(downloadURL) {
            return downloadURL
        }
        return Self.officialReleasesURL
    }

    public var hasRequiredPublisherMetadata: Bool {
        guard sha256.count == 64,
              sha256.allSatisfy({ $0.isHexDigit }),
              let signature,
              signature.count >= 32 else {
            return false
        }
        return true
    }

    public static func isAllowedDistributionURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              let host = url.host?.lowercased() else {
            return false
        }

        let path = url.path
        switch host {
        case "github.com":
            return path == "/lucasmezen972-ui/Mixpilot/releases" ||
                path.hasPrefix("/lucasmezen972-ui/Mixpilot/releases/")
        case "objects.githubusercontent.com":
            return true
        case "cqppkklfugbixpxwitab.supabase.co":
            return path.hasPrefix("/storage/v1/object/public/mixpilot-releases/") ||
                path.hasPrefix("/storage/v1/object/public/mixpilot-mappings/")
        default:
            return false
        }
    }

    private static let officialReleasesURL = URL(
        string: "https://github.com/lucasmezen972-ui/Mixpilot/releases"
    )!

    private static func rolloutBucket(for installationID: UUID) -> Int {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in installationID.uuidString.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % 100)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case channel
        case version
        case build
        case minimumMacOS = "minimum_macos"
        case downloadURL = "download_url"
        case releasePageURL = "release_page_url"
        case sha256
        case signature
        case releaseNotes = "release_notes"
        case mandatory
        case rolloutPercentage = "rollout_percentage"
        case publishedAt = "published_at"
    }
}

public struct MixPilotCloudCommand: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let command: String
    public let payload: [String: String]
    public let status: String
    public let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case command
        case payload
        case status
        case expiresAt = "expires_at"
    }
}

public enum MixPilotCloudConnectionState: Equatable, Sendable {
    case idle
    case connecting
    case connected
    case offline(String)

    public var label: String {
        switch self {
        case .idle: "Cloud en attente"
        case .connecting: "Connexion au cloud…"
        case .connected: "Cloud connecté"
        case .offline: "Cloud hors ligne"
        }
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
