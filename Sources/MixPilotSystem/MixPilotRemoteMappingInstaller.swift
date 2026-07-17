#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotMIDI

public enum MixPilotRemoteMappingInstallerError: Error, LocalizedError {
    case persistenceVerificationFailed

    public var errorDescription: String? {
        switch self {
        case .persistenceVerificationFailed:
            "Le correctif distant écrit sur le disque n’a pas pu être vérifié."
        }
    }
}

public struct MixPilotRemoteMappingInstallResult: Sendable {
    public let releaseID: UUID
    public let mappingVersion: Int
    public let backend: DJBackendIdentifier
    public let previousProfileSHA256: String
    public let appliedProfileSHA256: String
    public let artifactKind: MixPilotRemoteMappingArtifactKind
    public let generatedArtifactSHA256: String?
    public let generatedArtifactURL: URL?

    @available(*, deprecated, renamed: "generatedArtifactSHA256")
    public var presetSHA256: String? { generatedArtifactSHA256 }

    @available(*, deprecated, renamed: "generatedArtifactURL")
    public var presetURL: URL? { generatedArtifactURL }
}

private struct MixPilotRemoteMappingBackup: Codable, Sendable {
    let profile: MIDIMappingProfile
    let profileSHA256: String
    let createdAt: Date
}

private struct MixPilotRemoteMappingLocalState: Codable, Sendable {
    let releaseID: UUID
    let mappingVersion: Int
    let backend: DJBackendIdentifier?
    let profileSHA256: String
    let artifactKind: MixPilotRemoteMappingArtifactKind?
    let generatedArtifactSHA256: String?
    let generatedArtifactURL: URL?
    let stagedAt: Date
}

public actor MixPilotRemoteMappingInstaller {
    private let mappingStore = MIDIMappingProfileStore()
    private let validator = MixPilotRemoteMappingValidator()
    private let rootDirectory: URL
    private let installationID: UUID

    public init(rootDirectory: URL? = nil, installationID: UUID? = nil) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let supportRoot = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.homeDirectoryForCurrentUser
            self.rootDirectory = supportRoot
                .appendingPathComponent("MixPilot Autopilot", isDirectory: true)
                .appendingPathComponent("Remote Mappings", isDirectory: true)
        }
        self.installationID = installationID ?? Self.loadInstallationID()
    }

    public func stage(
        release: MixPilotRemoteMappingRelease,
        currentAppBuild: Int,
        backend: DJBackendIdentifier,
        softwareVersion: String?,
        controllerName: String
    ) async throws -> MixPilotRemoteMappingInstallResult {
        let validated = try validator.validate(
            release: release,
            currentAppBuild: currentAppBuild,
            backend: backend,
            softwareVersion: softwareVersion,
            controllerName: controllerName,
            installationID: installationID
        )
        let currentProfile = (try? await mappingStore.load()) ?? .developmentDefault
        let previousHash = try MixPilotRemoteMappingValidator.profileSHA256(currentProfile)

        try createDirectories()
        try saveBackup(profile: currentProfile, hash: previousHash)
        _ = try await mappingStore.save(release.profile)

        let artifact = try persistArtifact(
            validated: validated,
            mappingVersion: release.mappingVersion
        )
        let state = MixPilotRemoteMappingLocalState(
            releaseID: release.id,
            mappingVersion: release.mappingVersion,
            backend: backend,
            profileSHA256: validated.profileSHA256,
            artifactKind: validated.artifactKind,
            generatedArtifactSHA256: artifact.sha256,
            generatedArtifactURL: artifact.url,
            stagedAt: Date()
        )
        try encode(state, to: rootDirectory.appendingPathComponent("state.json"))

        return MixPilotRemoteMappingInstallResult(
            releaseID: release.id,
            mappingVersion: release.mappingVersion,
            backend: backend,
            previousProfileSHA256: previousHash,
            appliedProfileSHA256: validated.profileSHA256,
            artifactKind: validated.artifactKind,
            generatedArtifactSHA256: artifact.sha256,
            generatedArtifactURL: artifact.url
        )
    }

    @available(*, deprecated, message: "Pass the active backend and software version explicitly")
    public func stage(
        release: MixPilotRemoteMappingRelease,
        currentAppBuild: Int,
        rekordboxVersion: String?,
        controllerName: String
    ) async throws -> MixPilotRemoteMappingInstallResult {
        try await stage(
            release: release,
            currentAppBuild: currentAppBuild,
            backend: .rekordbox,
            softwareVersion: rekordboxVersion,
            controllerName: controllerName
        )
    }

    public func rollback(
        backend: DJBackendIdentifier,
        controllerName: String
    ) async throws -> MixPilotRemoteMappingInstallResult {
        let backupURL = rootDirectory.appendingPathComponent("backup.json")
        let backup: MixPilotRemoteMappingBackup = try decode(from: backupURL)
        _ = try await mappingStore.save(backup.profile)

        let artifact: (kind: MixPilotRemoteMappingArtifactKind, sha256: String?, url: URL?)
        switch backend {
        case .rekordbox:
            let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
                profile: backup.profile,
                controllerName: controllerName
            )
            let data = Data(preset.csv.utf8)
            let url = rootDirectory
                .appendingPathComponent("Rollback", isDirectory: true)
                .appendingPathComponent("MixPilot Virtual Controller Rollback.midi.csv")
            try writeAndVerify(data, to: url)
            artifact = (
                .rekordboxCSV,
                MixPilotRemoteMappingValidator.sha256(data),
                url
            )
        case .djay, .serato:
            artifact = (.profile, nil, nil)
        }

        let currentState = try? loadState()
        try? FileManager.default.removeItem(at: rootDirectory.appendingPathComponent("state.json"))

        return MixPilotRemoteMappingInstallResult(
            releaseID: currentState?.releaseID ?? UUID(),
            mappingVersion: currentState?.mappingVersion ?? 0,
            backend: backend,
            previousProfileSHA256: currentState?.profileSHA256 ?? "",
            appliedProfileSHA256: backup.profileSHA256,
            artifactKind: artifact.kind,
            generatedArtifactSHA256: artifact.sha256,
            generatedArtifactURL: artifact.url
        )
    }

    @available(*, deprecated, message: "Pass the active backend explicitly")
    public func rollback(controllerName: String) async throws -> MixPilotRemoteMappingInstallResult {
        try await rollback(backend: .rekordbox, controllerName: controllerName)
    }

    public func currentState() throws -> (
        releaseID: UUID,
        mappingVersion: Int,
        backend: DJBackendIdentifier?,
        profileSHA256: String
    )? {
        guard FileManager.default.fileExists(atPath: rootDirectory.appendingPathComponent("state.json").path) else {
            return nil
        }
        let state = try loadState()
        return (state.releaseID, state.mappingVersion, state.backend, state.profileSHA256)
    }

    private func persistArtifact(
        validated: MixPilotValidatedRemoteMapping,
        mappingVersion: Int
    ) throws -> (sha256: String?, url: URL?) {
        guard let text = validated.generatedArtifactText else {
            return (nil, nil)
        }
        let url: URL
        switch validated.artifactKind {
        case .profile:
            return (nil, nil)
        case .rekordboxCSV:
            url = rootDirectory
                .appendingPathComponent("Active", isDirectory: true)
                .appendingPathComponent("MixPilot Virtual Controller Remote v\(mappingVersion).midi.csv")
        }
        let data = Data(text.utf8)
        try writeAndVerify(data, to: url)
        return (
            validated.generatedArtifactSHA256 ?? MixPilotRemoteMappingValidator.sha256(data),
            url
        )
    }

    private func writeAndVerify(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == data else {
            throw MixPilotRemoteMappingInstallerError.persistenceVerificationFailed
        }
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
