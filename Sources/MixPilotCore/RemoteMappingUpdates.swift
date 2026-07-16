import CryptoKit
import Foundation

public enum MixPilotRemoteMappingApplyMode: String, Codable, CaseIterable, Sendable {
    case notify
    case nextLaunch = "next_launch"
    case required

    public var displayName: String {
        switch self {
        case .notify: "Validation manuelle"
        case .nextLaunch: "Installation au prochain lancement"
        case .required: "Correctif requis"
        }
    }
}

public struct MixPilotRemoteMappingRelease: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let channel: String
    public let software: String
    public let controllerName: String
    public let mappingVersion: Int
    public let minimumAppBuild: Int
    public let minimumRekordboxVersion: String?
    public let maximumRekordboxVersion: String?
    public let profile: MIDIMappingProfile
    public let profileSHA256: String
    public let generatedPresetSHA256: String?
    public let publisherSignature: String?
    public let applyMode: MixPilotRemoteMappingApplyMode
    public let mandatory: Bool
    public let rolloutPercentage: Int
    public let releaseNotes: String
    public let validationSummary: [String: String]
    public let publishedAt: Date

    public func isCompatible(
        currentAppBuild: Int,
        rekordboxVersion: String?,
        controllerName: String,
        installationID: UUID
    ) -> Bool {
        guard software.caseInsensitiveCompare("rekordbox") == .orderedSame else { return false }
        guard currentAppBuild >= minimumAppBuild else { return false }
        guard self.controllerName == "*" || self.controllerName.caseInsensitiveCompare(controllerName) == .orderedSame else {
            return false
        }
        guard rolloutPercentage > 0 else { return false }
        if rolloutPercentage < 100,
           Self.rolloutBucket(installationID: installationID, releaseID: id) >= rolloutPercentage {
            return false
        }
        if let minimumRekordboxVersion {
            guard let rekordboxVersion,
                  Self.compareVersions(rekordboxVersion, minimumRekordboxVersion) != .orderedAscending else {
                return false
            }
        }
        if let maximumRekordboxVersion,
           let rekordboxVersion,
           Self.compareVersions(rekordboxVersion, maximumRekordboxVersion) == .orderedDescending {
            return false
        }
        return true
    }

    enum CodingKeys: String, CodingKey {
        case id
        case channel
        case software
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case minimumAppBuild = "minimum_app_build"
        case minimumRekordboxVersion = "minimum_rekordbox_version"
        case maximumRekordboxVersion = "maximum_rekordbox_version"
        case profile
        case profileSHA256 = "profile_sha256"
        case generatedPresetSHA256 = "generated_preset_sha256"
        case publisherSignature = "publisher_signature"
        case applyMode = "apply_mode"
        case mandatory
        case rolloutPercentage = "rollout_percentage"
        case releaseNotes = "release_notes"
        case validationSummary = "validation_summary"
        case publishedAt = "published_at"
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func rolloutBucket(installationID: UUID, releaseID: UUID) -> Int {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in "\(installationID.uuidString.lowercased()):\(releaseID.uuidString.lowercased())".utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % 100)
    }
}

public struct MixPilotCompatibilityOverride: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let channel: String
    public let software: String
    public let controllerName: String
    public let minimumAppBuild: Int
    public let minimumRekordboxVersion: String?
    public let maximumRekordboxVersion: String?
    public let disabledActions: [String]
    public let requiredValidations: [String]
    public let warnings: [String]
    public let blockLive: Bool
    public let rolloutPercentage: Int
    public let publishedAt: Date

    public func applies(
        currentAppBuild: Int,
        rekordboxVersion: String?,
        controllerName: String,
        installationID: UUID
    ) -> Bool {
        guard software.caseInsensitiveCompare("rekordbox") == .orderedSame else { return false }
        guard currentAppBuild >= minimumAppBuild else { return false }
        guard self.controllerName == "*" || self.controllerName.caseInsensitiveCompare(controllerName) == .orderedSame else {
            return false
        }
        guard rolloutPercentage > 0 else { return false }
        if rolloutPercentage < 100 {
            var hash: UInt64 = 1_469_598_103_934_665_603
            for byte in "\(installationID.uuidString.lowercased()):\(id.uuidString.lowercased())".utf8 {
                hash ^= UInt64(byte)
                hash &*= 1_099_511_628_211
            }
            guard Int(hash % 100) < rolloutPercentage else { return false }
        }
        if let minimumRekordboxVersion {
            guard let rekordboxVersion,
                  Self.versionComponents(rekordboxVersion).lexicographicallyPrecedes(Self.versionComponents(minimumRekordboxVersion)) == false else {
                return false
            }
        }
        if let maximumRekordboxVersion,
           let rekordboxVersion,
           Self.versionComponents(maximumRekordboxVersion).lexicographicallyPrecedes(Self.versionComponents(rekordboxVersion)) {
            return false
        }
        return true
    }

    enum CodingKeys: String, CodingKey {
        case id
        case channel
        case software
        case controllerName = "controller_name"
        case minimumAppBuild = "minimum_app_build"
        case minimumRekordboxVersion = "minimum_rekordbox_version"
        case maximumRekordboxVersion = "maximum_rekordbox_version"
        case disabledActions = "disabled_actions"
        case requiredValidations = "required_validations"
        case warnings
        case blockLive = "block_live"
        case rolloutPercentage = "rollout_percentage"
        case publishedAt = "published_at"
    }

    private static func versionComponents(_ version: String) -> [Int] {
        var values = version.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        while values.count < 4 { values.append(0) }
        return values
    }
}

public enum MixPilotRemoteMappingValidationError: Error, LocalizedError, Equatable {
    case incompatible
    case profileHashMismatch(expected: String, actual: String)
    case generatedPresetHashMismatch(expected: String, actual: String)
    case emptyMapping

    public var errorDescription: String? {
        switch self {
        case .incompatible:
            "Ce mapping ne correspond pas à cette version de MixPilot, de rekordbox ou à ce contrôleur."
        case .profileHashMismatch:
            "Le mapping reçu ne correspond pas à son empreinte de sécurité."
        case .generatedPresetHashMismatch:
            "Le preset rekordbox recompilé localement ne correspond pas à la version publiée."
        case .emptyMapping:
            "Le mapping distant ne contient aucune commande exploitable."
        }
    }
}

public struct MixPilotValidatedRemoteMapping: Sendable {
    public let release: MixPilotRemoteMappingRelease
    public let profileSHA256: String
    public let presetSHA256: String
    public let presetCSV: String

    public init(
        release: MixPilotRemoteMappingRelease,
        profileSHA256: String,
        presetSHA256: String,
        presetCSV: String
    ) {
        self.release = release
        self.profileSHA256 = profileSHA256
        self.presetSHA256 = presetSHA256
        self.presetCSV = presetCSV
    }
}

public struct MixPilotRemoteMappingValidator: Sendable {
    public init() {}

    public func validate(
        release: MixPilotRemoteMappingRelease,
        currentAppBuild: Int,
        rekordboxVersion: String?,
        controllerName: String,
        installationID: UUID
    ) throws -> MixPilotValidatedRemoteMapping {
        guard release.isCompatible(
            currentAppBuild: currentAppBuild,
            rekordboxVersion: rekordboxVersion,
            controllerName: controllerName,
            installationID: installationID
        ) else {
            throw MixPilotRemoteMappingValidationError.incompatible
        }

        let profileHash = try Self.profileSHA256(release.profile)
        guard profileHash.caseInsensitiveCompare(release.profileSHA256) == .orderedSame else {
            throw MixPilotRemoteMappingValidationError.profileHashMismatch(
                expected: release.profileSHA256,
                actual: profileHash
            )
        }

        let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
            profile: release.profile,
            controllerName: controllerName
        )
        guard !preset.base.supportedActions.isEmpty else {
            throw MixPilotRemoteMappingValidationError.emptyMapping
        }
        let presetHash = Self.sha256(Data(preset.csv.utf8))
        if let expected = release.generatedPresetSHA256,
           expected.caseInsensitiveCompare(presetHash) != .orderedSame {
            throw MixPilotRemoteMappingValidationError.generatedPresetHashMismatch(
                expected: expected,
                actual: presetHash
            )
        }

        return MixPilotValidatedRemoteMapping(
            release: release,
            profileSHA256: profileHash,
            presetSHA256: presetHash,
            presetCSV: preset.csv
        )
    }

    public static func profileSHA256(_ profile: MIDIMappingProfile) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var canonical = Data("mixpilot-midi-profile-v1\n".utf8)

        for action in SeratoAction.allCases.sorted(by: { $0.rawValue < $1.rawValue }) {
            canonical.append(Data(action.rawValue.utf8))
            canonical.append(0)
            if let mapping = profile[action] {
                canonical.append(try encoder.encode(mapping))
            } else {
                canonical.append(Data("null".utf8))
            }
            canonical.append(10)
        }

        return sha256(canonical)
    }

    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
