import Foundation

public struct MixPilotMappingProvenance: Codable, Hashable, Sendable {
    public let releaseID: UUID
    public let sourceRepository: String
    public let sourceCommitSHA: String
    public let sourceManifestPath: String
    public let sourceManifestSHA256: String

    public init(
        releaseID: UUID,
        sourceRepository: String,
        sourceCommitSHA: String,
        sourceManifestPath: String,
        sourceManifestSHA256: String
    ) {
        self.releaseID = releaseID
        self.sourceRepository = sourceRepository
        self.sourceCommitSHA = sourceCommitSHA
        self.sourceManifestPath = sourceManifestPath
        self.sourceManifestSHA256 = sourceManifestSHA256
    }

    enum CodingKeys: String, CodingKey {
        case releaseID = "id"
        case sourceRepository = "source_repository"
        case sourceCommitSHA = "source_commit_sha"
        case sourceManifestPath = "source_manifest_path"
        case sourceManifestSHA256 = "source_manifest_sha256"
    }
}

public struct MixPilotMappingManifestValidation: Codable, Hashable, Sendable {
    public let advancedActions: Int
    public let dmgChecksum: String
    public let releaseBuild: String
    public let simulation250: String
    public let simulation50: String
    public let supportedActions: Int
    public let unitTests: String

    public init(
        advancedActions: Int,
        dmgChecksum: String,
        releaseBuild: String,
        simulation250: String,
        simulation50: String,
        supportedActions: Int,
        unitTests: String
    ) {
        self.advancedActions = advancedActions
        self.dmgChecksum = dmgChecksum
        self.releaseBuild = releaseBuild
        self.simulation250 = simulation250
        self.simulation50 = simulation50
        self.supportedActions = supportedActions
        self.unitTests = unitTests
    }

    enum CodingKeys: String, CodingKey {
        case advancedActions = "advanced_actions"
        case dmgChecksum = "dmg_checksum"
        case releaseBuild = "release_build"
        case simulation250 = "simulation_250"
        case simulation50 = "simulation_50"
        case supportedActions = "supported_actions"
        case unitTests = "unit_tests"
    }

    public var isComplete: Bool {
        unitTests == "passed"
            && simulation50 == "passed"
            && simulation250 == "passed"
            && releaseBuild == "passed"
            && dmgChecksum == "passed"
            && supportedActions > 0
    }
}

public struct MixPilotMappingProvenanceManifest: Codable, Hashable, Sendable {
    public let applyMode: MixPilotRemoteMappingApplyMode
    public let channel: String
    public let ciRunNumber: Int
    public let controllerName: String
    public let generatedArtifactSHA256: String?
    public let mandatory: Bool
    public let mappingVersion: Int
    public let maximumSoftwareVersion: String?
    public let minimumAppBuild: Int
    public let minimumSoftwareVersion: String?
    public let profileSHA256: String
    public let releaseID: UUID
    public let releaseNotes: String
    public let repository: String
    public let schemaVersion: Int
    public let software: String
    public let validation: MixPilotMappingManifestValidation

    public init(
        applyMode: MixPilotRemoteMappingApplyMode,
        channel: String,
        ciRunNumber: Int,
        controllerName: String,
        generatedArtifactSHA256: String?,
        mandatory: Bool,
        mappingVersion: Int,
        maximumSoftwareVersion: String?,
        minimumAppBuild: Int,
        minimumSoftwareVersion: String?,
        profileSHA256: String,
        releaseID: UUID,
        releaseNotes: String,
        repository: String,
        schemaVersion: Int,
        software: String,
        validation: MixPilotMappingManifestValidation
    ) {
        self.applyMode = applyMode
        self.channel = channel
        self.ciRunNumber = ciRunNumber
        self.controllerName = controllerName
        self.generatedArtifactSHA256 = generatedArtifactSHA256
        self.mandatory = mandatory
        self.mappingVersion = mappingVersion
        self.maximumSoftwareVersion = maximumSoftwareVersion
        self.minimumAppBuild = minimumAppBuild
        self.minimumSoftwareVersion = minimumSoftwareVersion
        self.profileSHA256 = profileSHA256
        self.releaseID = releaseID
        self.releaseNotes = releaseNotes
        self.repository = repository
        self.schemaVersion = schemaVersion
        self.software = software
        self.validation = validation
    }

    @available(*, deprecated, message: "Use generic software-version and artifact fields")
    public init(
        applyMode: MixPilotRemoteMappingApplyMode,
        channel: String,
        ciRunNumber: Int,
        controllerName: String,
        generatedPresetSHA256: String,
        mandatory: Bool,
        mappingVersion: Int,
        maximumRekordboxVersion: String?,
        minimumAppBuild: Int,
        minimumRekordboxVersion: String?,
        profileSHA256: String,
        releaseID: UUID,
        releaseNotes: String,
        repository: String,
        schemaVersion: Int,
        software: String,
        validation: MixPilotMappingManifestValidation
    ) {
        self.init(
            applyMode: applyMode,
            channel: channel,
            ciRunNumber: ciRunNumber,
            controllerName: controllerName,
            generatedArtifactSHA256: generatedPresetSHA256,
            mandatory: mandatory,
            mappingVersion: mappingVersion,
            maximumSoftwareVersion: maximumRekordboxVersion,
            minimumAppBuild: minimumAppBuild,
            minimumSoftwareVersion: minimumRekordboxVersion,
            profileSHA256: profileSHA256,
            releaseID: releaseID,
            releaseNotes: releaseNotes,
            repository: repository,
            schemaVersion: schemaVersion,
            software: software,
            validation: validation
        )
    }

    @available(*, deprecated, renamed: "generatedArtifactSHA256")
    public var generatedPresetSHA256: String? { generatedArtifactSHA256 }

    @available(*, deprecated, renamed: "minimumSoftwareVersion")
    public var minimumRekordboxVersion: String? { minimumSoftwareVersion }

    @available(*, deprecated, renamed: "maximumSoftwareVersion")
    public var maximumRekordboxVersion: String? { maximumSoftwareVersion }

    enum CodingKeys: String, CodingKey {
        case applyMode = "apply_mode"
        case channel
        case ciRunNumber = "ci_run_number"
        case controllerName = "controller_name"
        case generatedArtifactSHA256 = "generated_artifact_sha256"
        case legacyGeneratedPresetSHA256 = "generated_preset_sha256"
        case mandatory
        case mappingVersion = "mapping_version"
        case maximumSoftwareVersion = "maximum_software_version"
        case legacyMaximumRekordboxVersion = "maximum_rekordbox_version"
        case minimumAppBuild = "minimum_app_build"
        case minimumSoftwareVersion = "minimum_software_version"
        case legacyMinimumRekordboxVersion = "minimum_rekordbox_version"
        case profileSHA256 = "profile_sha256"
        case releaseID = "release_id"
        case releaseNotes = "release_notes"
        case repository
        case schemaVersion = "schema_version"
        case software
        case validation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        applyMode = try container.decode(MixPilotRemoteMappingApplyMode.self, forKey: .applyMode)
        channel = try container.decode(String.self, forKey: .channel)
        ciRunNumber = try container.decode(Int.self, forKey: .ciRunNumber)
        controllerName = try container.decode(String.self, forKey: .controllerName)
        generatedArtifactSHA256 = try container.decodeIfPresent(String.self, forKey: .generatedArtifactSHA256)
            ?? container.decodeIfPresent(String.self, forKey: .legacyGeneratedPresetSHA256)
        mandatory = try container.decode(Bool.self, forKey: .mandatory)
        mappingVersion = try container.decode(Int.self, forKey: .mappingVersion)
        maximumSoftwareVersion = try container.decodeIfPresent(String.self, forKey: .maximumSoftwareVersion)
            ?? container.decodeIfPresent(String.self, forKey: .legacyMaximumRekordboxVersion)
        minimumAppBuild = try container.decode(Int.self, forKey: .minimumAppBuild)
        minimumSoftwareVersion = try container.decodeIfPresent(String.self, forKey: .minimumSoftwareVersion)
            ?? container.decodeIfPresent(String.self, forKey: .legacyMinimumRekordboxVersion)
        profileSHA256 = try container.decode(String.self, forKey: .profileSHA256)
        releaseID = try container.decode(UUID.self, forKey: .releaseID)
        releaseNotes = try container.decode(String.self, forKey: .releaseNotes)
        repository = try container.decode(String.self, forKey: .repository)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        software = try container.decode(String.self, forKey: .software)
        validation = try container.decode(MixPilotMappingManifestValidation.self, forKey: .validation)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(applyMode, forKey: .applyMode)
        try container.encode(channel, forKey: .channel)
        try container.encode(ciRunNumber, forKey: .ciRunNumber)
        try container.encode(controllerName, forKey: .controllerName)
        try container.encodeIfPresent(generatedArtifactSHA256, forKey: .generatedArtifactSHA256)
        try container.encode(mandatory, forKey: .mandatory)
        try container.encode(mappingVersion, forKey: .mappingVersion)
        try container.encodeIfPresent(maximumSoftwareVersion, forKey: .maximumSoftwareVersion)
        try container.encode(minimumAppBuild, forKey: .minimumAppBuild)
        try container.encodeIfPresent(minimumSoftwareVersion, forKey: .minimumSoftwareVersion)
        try container.encode(profileSHA256, forKey: .profileSHA256)
        try container.encode(releaseID, forKey: .releaseID)
        try container.encode(releaseNotes, forKey: .releaseNotes)
        try container.encode(repository, forKey: .repository)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(software, forKey: .software)
        try container.encode(validation, forKey: .validation)
    }
}

public enum MixPilotMappingProvenanceError: Error, LocalizedError, Equatable {
    case untrustedRepository
    case invalidCommit
    case invalidManifestPath
    case manifestTooLarge
    case manifestDigestMismatch
    case malformedManifest
    case releaseMismatch
    case incompleteCI

    public var errorDescription: String? {
        switch self {
        case .untrustedRepository: "Le dépôt d’origine du mapping n’est pas autorisé."
        case .invalidCommit: "Le commit d’origine du mapping est invalide."
        case .invalidManifestPath: "Le chemin du manifeste de mapping est invalide."
        case .manifestTooLarge: "Le manifeste de mapping dépasse la taille autorisée."
        case .manifestDigestMismatch: "Le manifeste GitHub ne correspond pas à son empreinte Supabase."
        case .malformedManifest: "Le manifeste GitHub est illisible."
        case .releaseMismatch: "Le manifeste GitHub et la version Supabase ne correspondent pas."
        case .incompleteCI: "Le manifeste ne prouve pas une validation CI complète."
        }
    }
}

public struct MixPilotMappingProvenanceVerifier: Sendable {
    public static let trustedRepository = "lucasmezen972-ui/Mixpilot"
    public static let maximumManifestBytes = 262_144

    public init() {}

    public func validate(
        release: MixPilotRemoteMappingRelease,
        provenance: MixPilotMappingProvenance,
        manifestData: Data
    ) throws -> MixPilotMappingProvenanceManifest {
        guard provenance.releaseID == release.id,
              provenance.sourceRepository == Self.trustedRepository else {
            throw MixPilotMappingProvenanceError.untrustedRepository
        }
        guard provenance.sourceCommitSHA.range(
            of: "^[A-Fa-f0-9]{40}$",
            options: .regularExpression
        ) != nil else {
            throw MixPilotMappingProvenanceError.invalidCommit
        }
        guard provenance.sourceManifestPath.range(
            of: "^MappingReleases/[A-Za-z0-9._/-]+\\.json$",
            options: .regularExpression
        ) != nil else {
            throw MixPilotMappingProvenanceError.invalidManifestPath
        }
        guard manifestData.count <= Self.maximumManifestBytes else {
            throw MixPilotMappingProvenanceError.manifestTooLarge
        }
        let digest = MixPilotRemoteMappingValidator.sha256(manifestData)
        guard digest.caseInsensitiveCompare(provenance.sourceManifestSHA256) == .orderedSame else {
            throw MixPilotMappingProvenanceError.manifestDigestMismatch
        }

        let manifest: MixPilotMappingProvenanceManifest
        do {
            manifest = try JSONDecoder().decode(MixPilotMappingProvenanceManifest.self, from: manifestData)
        } catch {
            throw MixPilotMappingProvenanceError.malformedManifest
        }

        guard manifest.schemaVersion == 1,
              manifest.repository == Self.trustedRepository,
              manifest.releaseID == release.id,
              manifest.channel == release.channel,
              manifest.software.caseInsensitiveCompare(release.software) == .orderedSame,
              manifest.controllerName == release.controllerName,
              manifest.mappingVersion == release.mappingVersion,
              manifest.minimumAppBuild == release.minimumAppBuild,
              manifest.minimumSoftwareVersion == release.minimumSoftwareVersion,
              manifest.maximumSoftwareVersion == release.maximumSoftwareVersion,
              manifest.profileSHA256.caseInsensitiveCompare(release.profileSHA256) == .orderedSame,
              Self.hashesMatch(manifest.generatedArtifactSHA256, release.generatedPresetSHA256),
              manifest.applyMode == release.applyMode,
              manifest.mandatory == release.mandatory,
              manifest.releaseNotes == release.releaseNotes else {
            throw MixPilotMappingProvenanceError.releaseMismatch
        }
        guard manifest.validation.isComplete else {
            throw MixPilotMappingProvenanceError.incompleteCI
        }
        return manifest
    }

    public static func rawManifestURL(for provenance: MixPilotMappingProvenance) throws -> URL {
        guard provenance.sourceRepository == trustedRepository else {
            throw MixPilotMappingProvenanceError.untrustedRepository
        }
        guard provenance.sourceCommitSHA.range(
            of: "^[A-Fa-f0-9]{40}$",
            options: .regularExpression
        ) != nil else {
            throw MixPilotMappingProvenanceError.invalidCommit
        }
        guard provenance.sourceManifestPath.range(
            of: "^MappingReleases/[A-Za-z0-9._/-]+\\.json$",
            options: .regularExpression
        ) != nil else {
            throw MixPilotMappingProvenanceError.invalidManifestPath
        }
        let value = "https://raw.githubusercontent.com/\(trustedRepository)/\(provenance.sourceCommitSHA)/\(provenance.sourceManifestPath)"
        guard let url = URL(string: value) else {
            throw MixPilotMappingProvenanceError.invalidManifestPath
        }
        return url
    }

    private static func hashesMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case let (left?, right?): left.caseInsensitiveCompare(right) == .orderedSame
        default: false
        }
    }
}
