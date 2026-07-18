#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation
import MixPilotCore

private struct MappingReleaseCandidate: Encodable {
    let id: UUID
    let channel = "stable"
    let software: String
    let controllerName: String
    let mappingVersion: Int
    let minimumAppBuild: Int
    let minimumSoftwareVersion: String?
    let maximumSoftwareVersion: String?
    let profile: MIDIMappingProfile
    let profileSHA256: String
    let generatedPresetSHA256: String?
    let publisherSignature: String?
    let applyMode: String
    let mandatory: Bool
    let rolloutPercentage: Int
    let status = "draft"
    let releaseNotes: String
    let validationSummary: [String: String]
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case channel
        case software
        case controllerName = "controller_name"
        case mappingVersion = "mapping_version"
        case minimumAppBuild = "minimum_app_build"
        case minimumSoftwareVersion = "minimum_software_version"
        case maximumSoftwareVersion = "maximum_software_version"
        case profile
        case profileSHA256 = "profile_sha256"
        case generatedPresetSHA256 = "generated_preset_sha256"
        case publisherSignature = "publisher_signature"
        case applyMode = "apply_mode"
        case mandatory
        case rolloutPercentage = "rollout_percentage"
        case status
        case releaseNotes = "release_notes"
        case validationSummary = "validation_summary"
        case publishedAt = "published_at"
    }
}

private func argument(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name),
          CommandLine.arguments.indices.contains(index + 1) else {
        return nil
    }
    return CommandLine.arguments[index + 1]
}

private func backendArgument() throws -> DJBackendIdentifier {
    let value = (argument("--backend") ?? DJBackendIdentifier.rekordbox.rawValue).lowercased()
    guard let backend = DJBackendIdentifier(rawValue: value) else {
        throw PublisherError.invalidBackend(value)
    }
    return backend
}

private func defaultControllerName(for backend: DJBackendIdentifier) -> String {
    backend == .rekordbox
        ? RekordboxMIDIPresetGenerator.defaultControllerName
        : "MixPilot Virtual Controller"
}

private func signingKey() throws -> Curve25519.Signing.PrivateKey {
    guard let encoded = ProcessInfo.processInfo.environment["MIXPILOT_SIGNING_KEY_BASE64"],
          let raw = Data(base64Encoded: encoded) else {
        throw PublisherError.missingSigningKey
    }
    do {
        return try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
    } catch {
        throw PublisherError.malformedSigningKey
    }
}

private enum PublisherError: Error, LocalizedError {
    case invalidBackend(String)
    case invalidReleaseID
    case invalidPublishedAt
    case missingSigningKey
    case malformedSigningKey

    var errorDescription: String? {
        switch self {
        case .invalidBackend(let value):
            "Backend inconnu : \(value). Utilise djay, rekordbox ou serato."
        case .invalidReleaseID:
            "--release-id doit contenir un UUID stable avant la signature."
        case .invalidPublishedAt:
            "--published-at doit être une date ISO 8601 stable avant la signature."
        case .missingSigningKey:
            "MIXPILOT_SIGNING_KEY_BASE64 est requis avec --sign."
        case .malformedSigningKey:
            "La donnée de signature fournie par l’environnement CI est invalide."
        }
    }
}

private let backend = try backendArgument()
private let mappingVersion = Int(argument("--mapping-version") ?? "") ?? 1
private let minimumAppBuild = Int(argument("--minimum-app-build") ?? "") ?? 1
private let minimumSoftwareVersion = argument("--minimum-software-version")
private let maximumSoftwareVersion = argument("--maximum-software-version")
private let outputPath = argument("--output") ?? "mapping-release-candidate.json"
private let releaseNotes = argument("--notes") ?? "Mapping MixPilot généré et validé par la CI."
private let applyMode = argument("--apply-mode") ?? "notify"
private let rolloutPercentage = Int(argument("--rollout") ?? "") ?? 0
private let mandatory = CommandLine.arguments.contains("--mandatory")
private let shouldSign = CommandLine.arguments.contains("--sign")
private let controllerName = argument("--controller") ?? defaultControllerName(for: backend)
private let profile = MIDIMappingProfile.developmentDefault
private let releaseID: UUID = {
    guard let raw = argument("--release-id") else { return UUID() }
    guard let value = UUID(uuidString: raw) else { fatalError(PublisherError.invalidReleaseID.localizedDescription) }
    return value
}()
private let publishedAt: Date = {
    guard let raw = argument("--published-at") else { return Date() }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let value = formatter.date(from: raw) { return value }
    formatter.formatOptions = [.withInternetDateTime]
    guard let value = formatter.date(from: raw) else {
        fatalError(PublisherError.invalidPublishedAt.localizedDescription)
    }
    return value
}()

private let profileSHA256 = try MixPilotRemoteMappingValidator.profileSHA256(profile)
private let generatedArtifact: (hash: String?, supportedActions: Int, advancedActions: Int)
switch backend {
case .rekordbox:
    let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
        profile: profile,
        controllerName: controllerName
    )
    generatedArtifact = (
        MixPilotRemoteMappingValidator.sha256(Data(preset.csv.utf8)),
        preset.base.supportedActions.count,
        preset.addedActions.count
    )
case .djay, .serato:
    generatedArtifact = (nil, profile.mappings.count, 0)
}

private var validationSummary: [String: String] = [
    "supported_actions": String(generatedArtifact.supportedActions),
    "advanced_actions": String(generatedArtifact.advancedActions),
    "profile_sha256": profileSHA256,
    "backend": backend.rawValue,
    "device_validation": "required_before_published"
]
if let hash = generatedArtifact.hash {
    validationSummary["generated_artifact_sha256"] = hash
}

private let unsignedRelease = MixPilotRemoteMappingRelease(
    id: releaseID,
    channel: "stable",
    backend: backend,
    controllerName: controllerName,
    mappingVersion: mappingVersion,
    minimumAppBuild: minimumAppBuild,
    minimumSoftwareVersion: minimumSoftwareVersion,
    maximumSoftwareVersion: maximumSoftwareVersion,
    profile: profile,
    profileSHA256: profileSHA256,
    generatedPresetSHA256: generatedArtifact.hash,
    publisherSignature: nil,
    applyMode: MixPilotRemoteMappingApplyMode(rawValue: applyMode) ?? .notify,
    mandatory: mandatory,
    rolloutPercentage: min(100, max(0, rolloutPercentage)),
    releaseNotes: releaseNotes,
    validationSummary: validationSummary,
    publishedAt: publishedAt
)

private let publisherSignature: String? = try {
    guard shouldSign else { return nil }
    let key = try signingKey()
    let payload = try MixPilotPublicationCanonicalizer.mappingRelease(unsignedRelease)
    return try key.signature(for: payload).base64EncodedString()
}()

private let candidate = MappingReleaseCandidate(
    id: releaseID,
    software: backend.rawValue,
    controllerName: controllerName,
    mappingVersion: mappingVersion,
    minimumAppBuild: minimumAppBuild,
    minimumSoftwareVersion: minimumSoftwareVersion,
    maximumSoftwareVersion: maximumSoftwareVersion,
    profile: profile,
    profileSHA256: profileSHA256,
    generatedPresetSHA256: generatedArtifact.hash,
    publisherSignature: publisherSignature,
    applyMode: applyMode,
    mandatory: mandatory,
    rolloutPercentage: min(100, max(0, rolloutPercentage)),
    releaseNotes: releaseNotes,
    validationSummary: validationSummary,
    publishedAt: publishedAt
)

private let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
private let data = try encoder.encode(candidate)
private let outputURL = URL(fileURLWithPath: outputPath)
try data.write(to: outputURL, options: .atomic)
print(outputURL.path)
