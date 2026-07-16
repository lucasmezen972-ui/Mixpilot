import Foundation
import MixPilotCore

private struct MappingReleaseCandidate: Encodable {
    let channel = "stable"
    let software = "rekordbox"
    let controllerName: String
    let mappingVersion: Int
    let minimumAppBuild: Int
    let minimumRekordboxVersion = "5.3.0"
    let maximumRekordboxVersion: String? = nil
    let profile: MIDIMappingProfile
    let profileSHA256: String
    let generatedPresetSHA256: String
    let publisherSignature: String? = nil
    let applyMode: String
    let mandatory: Bool
    let rolloutPercentage: Int
    let status = "draft"
    let releaseNotes: String
    let validationSummary: [String: String]

    enum CodingKeys: String, CodingKey {
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
        case status
        case releaseNotes = "release_notes"
        case validationSummary = "validation_summary"
    }
}

private func argument(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name),
          CommandLine.arguments.indices.contains(index + 1) else {
        return nil
    }
    return CommandLine.arguments[index + 1]
}

private let mappingVersion = Int(argument("--mapping-version") ?? "") ?? 1
private let minimumAppBuild = Int(argument("--minimum-app-build") ?? "") ?? 1
private let outputPath = argument("--output") ?? "mapping-release-candidate.json"
private let releaseNotes = argument("--notes") ?? "Mapping MixPilot généré et validé par la CI."
private let applyMode = argument("--apply-mode") ?? "notify"
private let rolloutPercentage = Int(argument("--rollout") ?? "") ?? 0
private let mandatory = CommandLine.arguments.contains("--mandatory")
private let controllerName = RekordboxMIDIPresetGenerator.defaultControllerName
private let profile = MIDIMappingProfile.developmentDefault

let profileSHA256 = try MixPilotRemoteMappingValidator.profileSHA256(profile)
let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
    profile: profile,
    controllerName: controllerName
)
let presetSHA256 = MixPilotRemoteMappingValidator.sha256(Data(preset.csv.utf8))

let candidate = MappingReleaseCandidate(
    controllerName: controllerName,
    mappingVersion: mappingVersion,
    minimumAppBuild: minimumAppBuild,
    profile: profile,
    profileSHA256: profileSHA256,
    generatedPresetSHA256: presetSHA256,
    applyMode: applyMode,
    mandatory: mandatory,
    rolloutPercentage: min(100, max(0, rolloutPercentage)),
    releaseNotes: releaseNotes,
    validationSummary: [
        "supported_actions": String(preset.base.supportedActions.count),
        "advanced_actions": String(preset.addedActions.count),
        "profile_sha256": profileSHA256,
        "preset_sha256": presetSHA256,
        "device_validation": "required_before_published"
    ]
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let data = try encoder.encode(candidate)
let outputURL = URL(fileURLWithPath: outputPath)
try data.write(to: outputURL, options: .atomic)
print(outputURL.path)
