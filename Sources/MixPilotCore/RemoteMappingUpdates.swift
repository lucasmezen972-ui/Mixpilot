#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#else
#error("MixPilotCore requires CryptoKit or the Swift Crypto package")
#endif
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
    public let minimumSoftwareVersion: String?
    public let maximumSoftwareVersion: String?
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

    public init(
        id: UUID,
        channel: String,
        backend: DJBackendIdentifier,
        controllerName: String,
        mappingVersion: Int,
        minimumAppBuild: Int,
        minimumSoftwareVersion: String?,
        maximumSoftwareVersion: String?,
        profile: MIDIMappingProfile,
        profileSHA256: String,
        generatedPresetSHA256: String?,
        publisherSignature: String?,
        applyMode: MixPilotRemoteMappingApplyMode,
        mandatory: Bool,
        rolloutPercentage: Int,
        releaseNotes: String,
        validationSummary: [String: String],
        publishedAt: Date
    ) {
        self.id = id
        self.channel = channel
        self.software = backend.rawValue
        self.controllerName = controllerName
        self.mappingVersion = mappingVersion
        self.minimumAppBuild = minimumAppBuild
        self.minimumSoftwareVersion = minimumSoftwareVersion
        self.maximumSoftwareVersion = maximumSoftwareVersion
        self.profile = profile
        self.profileSHA256 = profileSHA256
        self.generatedPresetSHA256 = generatedPresetSHA256
        self.publisherSignature = publisherSignature
        self.applyMode = applyMode
        self.mandatory = mandatory
        self.rolloutPercentage = rolloutPercentage
        self.releaseNotes = releaseNotes
        self.validationSummary = validationSummary
        self.publishedAt = publishedAt
    }

    @available(*, deprecated, message: "Use the backend and generic software-version initializer")
    public init(
        id: UUID,
        channel: String,
        software: String,
        controllerName: String,
        mappingVersion: Int,
        minimumAppBuild: Int,
        minimumRekordboxVersion: String?,
        maximumRekordboxVersion: String?,
        profile: MIDIMappingProfile,
        profileSHA256: String,
        generatedPresetSHA256: String?,
        publisherSignature: String?,
        applyMode: MixPilotRemoteMappingApplyMode,
        mandatory: Bool,
        rolloutPercentage: Int,
        releaseNotes: String,
        validationSummary: [String: String],
        publishedAt: Date
    ) {
        self.id = id
        self.channel = channel
        self.software = software
        self.controllerName = controllerName
        self.mappingVersion = mappingVersion
        self.minimumAppBuild = minimumAppBuild
        self.minimumSoftwareVersion = minimumRekordboxVersion
        self.maximumSoftwareVersion = maximumRekordboxVersion
        self.profile = profile
        self.profileSHA256 = profileSHA256
        self.generatedPresetSHA256 = generatedPresetSHA256
        self.publisherSignature = publisherSignature
        self.applyMode = applyMode
        self.mandatory = mandatory
        self.rolloutPercentage = rolloutPercentage
        self.releaseNotes = releaseNotes
        self.validationSummary = validationSummary
        self.publishedAt = publishedAt
    }

    public var backendIdentifier: DJBackendIdentifier? {
        DJBackendIdentifier(rawValue: software.lowercased())
    }

    @available(*, deprecated, renamed: "minimumSoftwareVersion")
    public var minimumRekordboxVersion: String? { minimumSoftwareVersion }

    @available(*, deprecated, renamed: "maximumSoftwareVersion")
    public var maximumRekordboxVersion: String? { maximumSoftwareVersion }

    public func isCompatible(
        currentAppBuild: Int,
        backend: DJBackendIdentifier,
        softwareVersion: String?,
        controllerName: String,
        installationID: UUID
    ) -> Bool {
        guard backendIdentifier == backend else { return false }
        guard currentAppBuild >= minimumAppBuild else { return false }
        guard self.controllerName == "*" ||
                self.controllerName.caseInsensitiveCompare(controllerName) == .orderedSame else {
            return false
        }
        guard rolloutPercentage > 0 else { return false }
        if rolloutPercentage < 100,
           Self.rolloutBucket(installationID: installationID, releaseID: id) >= rolloutPercentage {
            return false
        }
        if let minimumSoftwareVersion {
            guard let softwareVersion,
                  Self.compareVersions(softwareVersion, minimumSoftwareVersion) != .orderedAscending else {
                return false
            }
        }
        if let maximumSoftwareVersion,
           let softwareVersion,
           Self.compareVersions(softwareVersion, maximumSoftwareVersion) == .orderedDescending {
            return false
        }
        return true
    }

    @available(*, deprecated, message: "Pass the active backend and software version explicitly")
    public func isCompatible(
        currentAppBuild: Int,
        rekordboxVersion: String?,
        controllerName: String,
        installationID: UUID
    ) -> Bool {
        isCompatible(
            currentAppBuild: currentAppBuild,
            backend: .rekordbox,
            softwareVersion: rekordboxVersion,
            controllerName: controllerName,
            installationID: installationID
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case channel
        case software
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case minimumAppBuild = "minimum_app_build"
        case minimumSoftwareVersion = "minimum_software_version"
        case maximumSoftwareVersion = "maximum_software_version"
        case legacyMinimumRekordboxVersion = "minimum_rekordbox_version"
        case legacyMaximumRekordboxVersion = "maximum_rekordbox_version"
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        channel = try container.decode(String.self, forKey: .channel)
        software = try container.decode(String.self, forKey: .software)
        controllerName = try container.decode(String.self, forKey: .controllerName)
        mappingVersion = try container.decode(Int.self, forKey: .mappingVersion)
        minimumAppBuild = try container.decode(Int.self, forKey: .minimumAppBuild)
        minimumSoftwareVersion = try container.decodeIfPresent(String.self, forKey: .minimumSoftwareVersion)
            ?? container.decodeIfPresent(String.self, forKey: .legacyMinimumRekordboxVersion)
        maximumSoftwareVersion = try container.decodeIfPresent(String.self, forKey: .maximumSoftwareVersion)
            ?? container.decodeIfPresent(String.self, forKey: .legacyMaximumRekordboxVersion)
        profile = try container.decode(MIDIMappingProfile.self, forKey: .profile)
        profileSHA256 = try container.decode(String.self, forKey: .profileSHA256)
        generatedPresetSHA256 = try container.decodeIfPresent(String.self, forKey: .generatedPresetSHA256)
        publisherSignature = try container.decodeIfPresent(String.self, forKey: .publisherSignature)
        applyMode = try container.decode(MixPilotRemoteMappingApplyMode.self, forKey: .applyMode)
        mandatory = try container.decode(Bool.self, forKey: .mandatory)
        rolloutPercentage = try container.decode(Int.self, forKey: .rolloutPercentage)
        releaseNotes = try container.decode(String.self, forKey: .releaseNotes)
        validationSummary = try container.decode([String: String].self, forKey: .validationSummary)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(channel, forKey: .channel)
        try container.encode(software, forKey: .software)
        try container.encode(controllerName, forKey: .controllerName)
        try container.encode(mappingVersion, forKey: .mappingVersion)
        try container.encode(minimumAppBuild, forKey: .minimumAppBuild)
        try container.encodeIfPresent(minimumSoftwareVersion, forKey: .minimumSoftwareVersion)
        try container.encodeIfPresent(maximumSoftwareVersion, forKey: .maximumSoftwareVersion)
        try container.encode(profile, forKey: .profile)
        try container.encode(profileSHA256, forKey: .profileSHA256)
        try container.encodeIfPresent(generatedPresetSHA256, forKey: .generatedPresetSHA256)
        try container.encodeIfPresent(publisherSignature, forKey: .publisherSignature)
        try container.encode(applyMode, forKey: .applyMode)
        try container.encode(mandatory, forKey: .mandatory)
        try container.encode(rolloutPercentage, forKey: .rolloutPercentage)
        try container.encode(releaseNotes, forKey: .releaseNotes)
        try container.encode(validationSummary, forKey: .validationSummary)
        try container.encode(publishedAt, forKey: .publishedAt)
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
    public let minimumSoftwareVersion: String?
    public let maximumSoftwareVersion: String?
    public let disabledActions: [String]
    public let requiredValidations: [String]
    public let warnings: [String]
    public let blockLive: Bool
    public let rolloutPercentage: Int
    public let publishedAt: Date

    public var backendIdentifier: DJBackendIdentifier? {
        DJBackendIdentifier(rawValue: software.lowercased())
    }

    @available(*, deprecated, renamed: "minimumSoftwareVersion")
    public var minimumRekordboxVersion: String? { minimumSoftwareVersion }

    @available(*, deprecated, renamed: "maximumSoftwareVersion")
    public var maximumRekordboxVersion: String? { maximumSoftwareVersion }

    public func applies(
        currentAppBuild: Int,
        backend: DJBackendIdentifier,
        softwareVersion: String?,
        controllerName: String,
        installationID: UUID
    ) -> Bool {
        guard backendIdentifier == backend else { return false }
        guard currentAppBuild >= minimumAppBuild else { return false }
        guard self.controllerName == "*" ||
                self.controllerName.caseInsensitiveCompare(controllerName) == .orderedSame else {
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
        if let minimumSoftwareVersion {
            guard let softwareVersion,
                  Self.compareVersions(softwareVersion, minimumSoftwareVersion) != .orderedAscending else {
                return false
            }
        }
        if let maximumSoftwareVersion,
           let softwareVersion,
           Self.compareVersions(softwareVersion, maximumSoftwareVersion) == .orderedDescending {
            return false
        }
        return true
    }

    @available(*, deprecated, message: "Pass the active backend and software version explicitly")
    public func applies(
        currentAppBuild: Int,
        rekordboxVersion: String?,
        controllerName: String,
        installationID: UUID
    ) -> Bool {
        applies(
            currentAppBuild: currentAppBuild,
            backend: .rekordbox,
            softwareVersion: rekordboxVersion,
            controllerName: controllerName,
            installationID: installationID
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case channel
        case software
        case controllerName = "controller_name"
        case minimumAppBuild = "minimum_app_build"
        case minimumSoftwareVersion = "minimum_software_version"
        case maximumSoftwareVersion = "maximum_software_version"
        case legacyMinimumRekordboxVersion = "minimum_rekordbox_version"
        case legacyMaximumRekordboxVersion = "maximum_rekordbox_version"
        case disabledActions = "disabled_actions"
        case requiredValidations = "required_validations"
        case warnings
        case blockLive = "block_live"
        case rolloutPercentage = "rollout_percentage"
        case publishedAt = "published_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        channel = try container.decode(String.self, forKey: .channel)
        software = try container.decode(String.self, forKey: .software)
        controllerName = try container.decode(String.self, forKey: .controllerName)
        minimumAppBuild = try container.decode(Int.self, forKey: .minimumAppBuild)
        minimumSoftwareVersion = try container.decodeIfPresent(String.self, forKey: .minimumSoftwareVersion)
            ?? container.decodeIfPresent(String.self, forKey: .legacyMinimumRekordboxVersion)
        maximumSoftwareVersion = try container.decodeIfPresent(String.self, forKey: .maximumSoftwareVersion)
            ?? container.decodeIfPresent(String.self, forKey: .legacyMaximumRekordboxVersion)
        disabledActions = try container.decode([String].self, forKey: .disabledActions)
        requiredValidations = try container.decode([String].self, forKey: .requiredValidations)
        warnings = try container.decode([String].self, forKey: .warnings)
        blockLive = try container.decode(Bool.self, forKey: .blockLive)
        rolloutPercentage = try container.decode(Int.self, forKey: .rolloutPercentage)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
    }
}

public enum MixPilotRemoteMappingValidationError: Error, LocalizedError, Equatable {
    case incompatible
    case profileHashMismatch(expected: String, actual: String)
    case generatedPresetHashMismatch(expected: String, actual: String)
    case emptyMapping
    case unsupportedGeneratedPreset(DJBackendIdentifier)

    public var errorDescription: String? {
        switch self {
        case .incompatible:
            "Ce mapping ne correspond pas à cette version de MixPilot, au logiciel DJ actif ou à ce contrôleur."
        case .profileHashMismatch:
            "Le mapping reçu ne correspond pas à son empreinte de sécurité."
        case .generatedPresetHashMismatch:
            "L’artefact recompilé localement ne correspond pas à la version publiée."
        case .emptyMapping:
            "Le mapping distant ne contient aucune commande exploitable."
        case .unsupportedGeneratedPreset(let backend):
            "Aucun générateur d’artefact distant n’est défini pour \(backend.displayName)."
        }
    }
}

public enum MixPilotRemoteMappingArtifactKind: String, Codable, Hashable, Sendable {
    case profile
    case rekordboxCSV = "rekordbox_csv"
}

public struct MixPilotValidatedRemoteMapping: Sendable {
    public let release: MixPilotRemoteMappingRelease
    public let profileSHA256: String
    public let artifactKind: MixPilotRemoteMappingArtifactKind
    public let generatedArtifactSHA256: String?
    public let generatedArtifactText: String?

    public init(
        release: MixPilotRemoteMappingRelease,
        profileSHA256: String,
        artifactKind: MixPilotRemoteMappingArtifactKind,
        generatedArtifactSHA256: String?,
        generatedArtifactText: String?
    ) {
        self.release = release
        self.profileSHA256 = profileSHA256
        self.artifactKind = artifactKind
        self.generatedArtifactSHA256 = generatedArtifactSHA256
        self.generatedArtifactText = generatedArtifactText
    }

    @available(*, deprecated, renamed: "generatedArtifactSHA256")
    public var presetSHA256: String? { generatedArtifactSHA256 }

    @available(*, deprecated, renamed: "generatedArtifactText")
    public var presetCSV: String? { generatedArtifactText }
}

public struct MixPilotRemoteMappingValidator: Sendable {
    public init() {}

    public func validate(
        release: MixPilotRemoteMappingRelease,
        currentAppBuild: Int,
        backend: DJBackendIdentifier,
        softwareVersion: String?,
        controllerName: String,
        installationID: UUID
    ) throws -> MixPilotValidatedRemoteMapping {
        guard release.isCompatible(
            currentAppBuild: currentAppBuild,
            backend: backend,
            softwareVersion: softwareVersion,
            controllerName: controllerName,
            installationID: installationID
        ) else {
            throw MixPilotRemoteMappingValidationError.incompatible
        }
        guard !release.profile.mappings.isEmpty else {
            throw MixPilotRemoteMappingValidationError.emptyMapping
        }

        let profileHash = try Self.profileSHA256(release.profile)
        guard profileHash.caseInsensitiveCompare(release.profileSHA256) == .orderedSame else {
            throw MixPilotRemoteMappingValidationError.profileHashMismatch(
                expected: release.profileSHA256,
                actual: profileHash
            )
        }

        switch backend {
        case .rekordbox:
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
                artifactKind: .rekordboxCSV,
                generatedArtifactSHA256: presetHash,
                generatedArtifactText: preset.csv
            )

        case .djay, .serato:
            guard release.generatedPresetSHA256 == nil else {
                throw MixPilotRemoteMappingValidationError.unsupportedGeneratedPreset(backend)
            }
            return MixPilotValidatedRemoteMapping(
                release: release,
                profileSHA256: profileHash,
                artifactKind: .profile,
                generatedArtifactSHA256: nil,
                generatedArtifactText: nil
            )
        }
    }

    @available(*, deprecated, message: "Pass the active backend and software version explicitly")
    public func validate(
        release: MixPilotRemoteMappingRelease,
        currentAppBuild: Int,
        rekordboxVersion: String?,
        controllerName: String,
        installationID: UUID
    ) throws -> MixPilotValidatedRemoteMapping {
        try validate(
            release: release,
            currentAppBuild: currentAppBuild,
            backend: .rekordbox,
            softwareVersion: rekordboxVersion,
            controllerName: controllerName,
            installationID: installationID
        )
    }

    public static func profileSHA256(_ profile: MIDIMappingProfile) throws -> String {
        sha256(try encodedProfile(profile))
    }

    public static func encodedProfile(_ profile: MIDIMappingProfile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(profile)
    }

    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private extension MixPilotCompatibilityOverride {
    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
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
}
