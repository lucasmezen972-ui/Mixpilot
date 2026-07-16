import CryptoKit
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
    public let generatedPresetSHA256: String
    public let mandatory: Bool
    public let mappingVersion: Int
    public let maximumRekordboxVersion: String?
    public let minimumAppBuild: Int
    public let minimumRekordboxVersion: String?
    public let profileSHA256: String
    public let releaseID: UUID
    public let releaseNotes: String
    public let repository: String
    public let schemaVersion: Int
    public let software: String
    public let validation: MixPilotMappingManifestValidation

    enum CodingKeys: String, CodingKey {
        case applyMode = "apply_mode"
        case channel
        case ciRunNumber = "ci_run_number"
        case controllerName = "controller_name"
        case generatedPresetSHA256 = "generated_preset_sha256"
        case mandatory
        case mappingVersion = "mapping_version"
        case maximumRekordboxVersion = "maximum_rekordbox_version"
        case minimumAppBuild = "minimum_app_build"
        case minimumRekordboxVersion = "minimum_rekordbox_version"
        case profileSHA256 = "profile_sha256"
        case releaseID = "release_id"
        case releaseNotes = "release_notes"
        case repository
        case schemaVersion = "schema_version"
        case software
        case validation
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
              manifest.software == release.software,
              manifest.controllerName == release.controllerName,
              manifest.mappingVersion == release.mappingVersion,
              manifest.minimumAppBuild == release.minimumAppBuild,
              manifest.minimumRekordboxVersion == release.minimumRekordboxVersion,
              manifest.maximumRekordboxVersion == release.maximumRekordboxVersion,
              manifest.profileSHA256.caseInsensitiveCompare(release.profileSHA256) == .orderedSame,
              manifest.generatedPresetSHA256.caseInsensitiveCompare(release.generatedPresetSHA256 ?? "") == .orderedSame,
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
}
