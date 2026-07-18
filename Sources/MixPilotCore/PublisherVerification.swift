#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#else
#error("MixPilotCore requires CryptoKit or the Swift Crypto package")
#endif
import Foundation

public enum MixPilotPublisherVerificationError: Error, LocalizedError, Equatable {
    case missingPublicKey
    case malformedPublicKey
    case missingSignature
    case malformedSignature
    case invalidSignature

    public var errorDescription: String? {
        switch self {
        case .missingPublicKey:
            "Aucune clé publique MixPilot approuvée n’est intégrée à cette version."
        case .malformedPublicKey:
            "La clé publique MixPilot intégrée est invalide."
        case .missingSignature:
            "La publication ne contient aucune signature éditeur."
        case .malformedSignature:
            "La signature éditeur n’est pas un encodage Ed25519 valide."
        case .invalidSignature:
            "La signature éditeur ne correspond pas au contenu publié."
        }
    }
}

public enum MixPilotPublisherVerification {
    public static func verify(
        signatureBase64: String?,
        payload: Data,
        publicKeyBase64: String?
    ) throws {
        guard let publicKeyBase64, !publicKeyBase64.isEmpty else {
            throw MixPilotPublisherVerificationError.missingPublicKey
        }
        guard let rawPublicKey = Data(base64Encoded: publicKeyBase64) else {
            throw MixPilotPublisherVerificationError.malformedPublicKey
        }
        guard let signatureBase64, !signatureBase64.isEmpty else {
            throw MixPilotPublisherVerificationError.missingSignature
        }
        guard let signature = Data(base64Encoded: signatureBase64) else {
            throw MixPilotPublisherVerificationError.malformedSignature
        }

        let publicKey: Curve25519.Signing.PublicKey
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: rawPublicKey)
        } catch {
            throw MixPilotPublisherVerificationError.malformedPublicKey
        }

        guard publicKey.isValidSignature(signature, for: payload) else {
            throw MixPilotPublisherVerificationError.invalidSignature
        }
    }
}

public enum MixPilotPublicationCanonicalizer {
    public static func appRelease(_ release: MixPilotCloudRelease) throws -> Data {
        try canonicalData(AppReleasePayload(
            id: release.id,
            channel: release.channel,
            version: release.version,
            build: release.build,
            minimumMacOS: release.minimumMacOS,
            downloadURL: release.downloadURL.absoluteString,
            releasePageURL: release.releasePageURL?.absoluteString,
            sha256: release.sha256.lowercased(),
            releaseNotes: release.releaseNotes,
            mandatory: release.mandatory,
            rolloutPercentage: release.rolloutPercentage,
            publishedAtMilliseconds: milliseconds(release.publishedAt)
        ))
    }

    public static func mappingRelease(_ release: MixPilotRemoteMappingRelease) throws -> Data {
        try canonicalData(MappingReleasePayload(
            id: release.id,
            channel: release.channel,
            software: release.software,
            controllerName: release.controllerName,
            mappingVersion: release.mappingVersion,
            minimumAppBuild: release.minimumAppBuild,
            minimumSoftwareVersion: release.minimumSoftwareVersion,
            maximumSoftwareVersion: release.maximumSoftwareVersion,
            profile: release.profile,
            profileSHA256: release.profileSHA256.lowercased(),
            generatedPresetSHA256: release.generatedPresetSHA256?.lowercased(),
            applyMode: release.applyMode.rawValue,
            mandatory: release.mandatory,
            rolloutPercentage: release.rolloutPercentage,
            releaseNotes: release.releaseNotes,
            validationSummary: release.validationSummary,
            publishedAtMilliseconds: milliseconds(release.publishedAt)
        ))
    }

    private static func canonicalData<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }
}

private struct AppReleasePayload: Encodable {
    let type = "mixpilot_app_release_v1"
    let id: UUID
    let channel: String
    let version: String
    let build: Int
    let minimumMacOS: String
    let downloadURL: String
    let releasePageURL: String?
    let sha256: String
    let releaseNotes: String
    let mandatory: Bool
    let rolloutPercentage: Int
    let publishedAtMilliseconds: Int64
}

private struct MappingReleasePayload: Encodable {
    let type = "mixpilot_mapping_release_v1"
    let id: UUID
    let channel: String
    let software: String
    let controllerName: String
    let mappingVersion: Int
    let minimumAppBuild: Int
    let minimumSoftwareVersion: String?
    let maximumSoftwareVersion: String?
    let profile: MIDIMappingProfile
    let profileSHA256: String
    let generatedPresetSHA256: String?
    let applyMode: String
    let mandatory: Bool
    let rolloutPercentage: Int
    let releaseNotes: String
    let validationSummary: [String: String]
    let publishedAtMilliseconds: Int64
}
