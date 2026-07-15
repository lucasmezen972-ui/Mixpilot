#if os(macOS)
import Foundation
import MixPilotCore

public actor MappedSeratoController: SeratoCommandSending {
    private let controller: CoreMIDIController
    private var profile: MIDIMappingProfile

    public init(
        controller: CoreMIDIController,
        profile: MIDIMappingProfile = .developmentDefault
    ) {
        self.controller = controller
        self.profile = profile
    }

    public func replaceProfile(_ profile: MIDIMappingProfile) {
        self.profile = profile
    }

    public func currentProfile() -> MIDIMappingProfile {
        profile
    }

    public func trigger(_ action: SeratoAction) async throws {
        guard let mapping = profile[action] else {
            throw MIDIControllerError.missingMapping(action)
        }
        try controller.trigger(mapping)
    }

    public func set(_ action: SeratoAction, value: Double) async throws {
        guard let mapping = profile[action] else {
            throw MIDIControllerError.missingMapping(action)
        }
        try controller.set(mapping, normalizedValue: value)
    }

    public func testCriticalMappings() async -> [SeratoAction: Bool] {
        let critical: [SeratoAction] = [
            .playA, .playB, .pauseA, .pauseB,
            .syncA, .syncB, .loadA, .loadB,
            .crossfader, .volumeA, .volumeB,
            .lowEQA, .lowEQB,
        ]
        var result: [SeratoAction: Bool] = [:]
        for action in critical {
            result[action] = profile[action] != nil
        }
        return result
    }
}

public actor MIDIMappingProfileStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL = MIDIMappingProfileStore.defaultFileURL()) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> MIDIMappingProfile {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .developmentDefault
        }
        let profile = try decoder.decode(
            MIDIMappingProfile.self,
            from: Data(contentsOf: fileURL)
        )
        guard profile.schemaVersion <= MIDIMappingProfile.currentSchemaVersion else {
            return .developmentDefault
        }
        return profile
    }

    @discardableResult
    public func save(_ profile: MIDIMappingProfile) throws -> URL {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(profile)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    public func reset() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    public static func defaultFileURL() -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return root
            .appendingPathComponent("MixPilot Autopilot", isDirectory: true)
            .appendingPathComponent("midi-mapping.json", isDirectory: false)
    }
}
#endif
