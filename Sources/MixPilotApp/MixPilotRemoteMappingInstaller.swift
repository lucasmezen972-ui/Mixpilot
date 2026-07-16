#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotMIDI

struct MixPilotRemoteMappingInstallResult: Sendable {
    let releaseID: UUID
    let mappingVersion: Int
    let previousProfileSHA256: String
    let appliedProfileSHA256: String
    let presetSHA256: String
    let presetURL: URL
}

private struct MixPilotRemoteMappingBackup: Codable, Sendable {
    let profile: MIDIMappingProfile
    let profileSHA256: String
    let createdAt: Date
}

private struct MixPilotRemoteMappingLocalState: Codable, Sendable {
    let releaseID: UUID
    let mappingVersion: Int
    let profileSHA256: String
    let presetSHA256: String
    let presetURL: URL
    let stagedAt: Date
}

actor MixPilotRemoteMappingInstaller {
    private let mappingStore = MIDIMappingProfileStore()
    private let validator = MixPilotRemoteMappingValidator()
    private let rootDirectory: URL
    private let installationID: UUID

    init() {
        let supportRoot = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        rootDirectory = supportRoot
            .appendingPathComponent("MixPilot Autopilot", isDirectory: true)
            .appendingPathComponent("Remote Mappings", isDirectory: true)
        installationID = Self.loadInstallationID()
    }

    func stage(
        release: MixPilotRemoteMappingRelease,
        currentAppBuild: Int,
        rekordboxVersion: String?,
        controllerName: String
    ) async throws -> MixPilotRemoteMappingInstallResult {
        let validated = try validator.validate(
            release: release,
            currentAppBuild: currentAppBuild,
            rekordboxVersion: rekordboxVersion,
            controllerName: controllerName,
            installationID: installationID
        )
        let currentProfile = (try? await mappingStore.load()) ?? .developmentDefault
        let previousHash = try MixPilotRemoteMappingValidator.profileSHA256(currentProfile)

        try createDirectories()
        try saveBackup(profile: currentProfile, hash: previousHash)
        _ = try await mappingStore.save(release.profile)

        let presetURL = rootDirectory
            .appendingPathComponent("Active", isDirectory: true)
            .appendingPathComponent("MixPilot Virtual Controller Remote v\(release.mappingVersion).midi.csv")
        try FileManager.default.createDirectory(
            at: presetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let presetData = Data(validated.presetCSV.utf8)
        try presetData.write(to: presetURL, options: .atomic)
        guard try Data(contentsOf: presetURL) == presetData else {
            throw RekordboxMappingExportError.verificationFailed
        }

        let state = MixPilotRemoteMappingLocalState(
            releaseID: release.id,
            mappingVersion: release.mappingVersion,
            profileSHA256: validated.profileSHA256,
            presetSHA256: validated.presetSHA256,
            presetURL: presetURL,
            stagedAt: Date()
        )
        try encode(state, to: rootDirectory.appendingPathComponent("state.json"))

        return MixPilotRemoteMappingInstallResult(
            releaseID: release.id,
            mappingVersion: release.mappingVersion,
            previousProfileSHA256: previousHash,
            appliedProfileSHA256: validated.profileSHA256,
            presetSHA256: validated.presetSHA256,
            presetURL: presetURL
        )
    }

    func rollback(controllerName: String) async throws -> MixPilotRemoteMappingInstallResult {
        let backupURL = rootDirectory.appendingPathComponent("backup.json")
        let backup: MixPilotRemoteMappingBackup = try decode(from: backupURL)
        _ = try await mappingStore.save(backup.profile)

        let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
            profile: backup.profile,
            controllerName: controllerName
        )
        let presetData = Data(preset.csv.utf8)
        let presetHash = MixPilotRemoteMappingValidator.sha256(presetData)
        let presetURL = rootDirectory
            .appendingPathComponent("Rollback", isDirectory: true)
            .appendingPathComponent("MixPilot Virtual Controller Rollback.midi.csv")
        try FileManager.default.createDirectory(
            at: presetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try presetData.write(to: presetURL, options: .atomic)

        let currentState = try? loadState()
        try? FileManager.default.removeItem(at: rootDirectory.appendingPathComponent("state.json"))

        return MixPilotRemoteMappingInstallResult(
            releaseID: currentState?.releaseID ?? UUID(),
            mappingVersion: currentState?.mappingVersion ?? 0,
            previousProfileSHA256: currentState?.profileSHA256 ?? "",
            appliedProfileSHA256: backup.profileSHA256,
            presetSHA256: presetHash,
            presetURL: presetURL
        )
    }

    func currentState() throws -> (releaseID: UUID, mappingVersion: Int, profileSHA256: String)? {
        guard FileManager.default.fileExists(atPath: rootDirectory.appendingPathComponent("state.json").path) else {
            return nil
        }
        let state = try loadState()
        return (state.releaseID, state.mappingVersion, state.profileSHA256)
    }

    private func loadState() throws -> MixPilotRemoteMappingLocalState {
        try decode(from: rootDirectory.appendingPathComponent("state.json"))
    }

    private func saveBackup(profile: MIDIMappingProfile, hash: String) throws {
        try encode(
            MixPilotRemoteMappingBackup(profile: profile, profileSHA256: hash, createdAt: Date()),
            to: rootDirectory.appendingPathComponent("backup.json")
        )
    }

    private func createDirectories() throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    private func encode<Value: Encodable>(_ value: Value, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private func decode<Value: Decodable>(from url: URL) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Value.self, from: Data(contentsOf: url))
    }

    private static func loadInstallationID() -> UUID {
        let key = "mixpilot.cloud.installation-id"
        if let value = UserDefaults.standard.string(forKey: key),
           let id = UUID(uuidString: value) {
            return id
        }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }
}
#endif
