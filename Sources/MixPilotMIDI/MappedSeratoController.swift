#if os(macOS)
import Foundation
import MixPilotCore

public enum MappedMIDIControllerError: Error, LocalizedError {
    case continuousActionRequiresControlChange(DJControlAction)

    public var errorDescription: String? {
        switch self {
        case .continuousActionRequiresControlChange(let action):
            "La commande \(action.rawValue) doit utiliser un Control Change MIDI pour accepter une valeur continue."
        }
    }
}

public actor MappedMIDIController: DJCommandSending {
    // Some DJ applications sample virtual MIDI inputs on their UI/run-loop
    // cadence. A 12 ms press could be emitted and released between two samples,
    // especially while a streaming browser is refreshing. Keep a real button
    // pulse without making the control feel sluggish.
    private static let momentaryPulseDuration: Duration = .milliseconds(80)

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

    public func trigger(_ action: DJControlAction) async throws {
        guard let mapping = profile[action] else {
            throw MIDIControllerError.missingMapping(action)
        }

        switch mapping.kind {
        case .note:
            try controller.sendNoteOn(
                channel: mapping.channel,
                note: mapping.number,
                velocity: mapping.maximumRawValue
            )
            do {
                try await Task.sleep(for: Self.momentaryPulseDuration)
            } catch {
                try? controller.sendNoteOff(
                    channel: mapping.channel,
                    note: mapping.number,
                    velocity: mapping.offRawValue
                )
                throw error
            }
            try controller.sendNoteOff(
                channel: mapping.channel,
                note: mapping.number,
                velocity: mapping.offRawValue
            )

        case .controlChange where mapping.isMomentary:
            try controller.sendControlChangeRaw(
                channel: mapping.channel,
                controller: mapping.number,
                value: mapping.maximumRawValue
            )
            do {
                try await Task.sleep(for: Self.momentaryPulseDuration)
            } catch {
                try? controller.sendControlChangeRaw(
                    channel: mapping.channel,
                    controller: mapping.number,
                    value: mapping.offRawValue
                )
                throw error
            }
            try controller.sendControlChangeRaw(
                channel: mapping.channel,
                controller: mapping.number,
                value: mapping.offRawValue
            )

        case .controlChange:
            try controller.trigger(mapping)
        }
    }

    public func set(_ action: DJControlAction, value: Double) async throws {
        guard let mapping = profile[action] else {
            throw MIDIControllerError.missingMapping(action)
        }
        guard mapping.kind == .controlChange else {
            throw MappedMIDIControllerError.continuousActionRequiresControlChange(action)
        }
        try controller.set(mapping, normalizedValue: value)
    }

    public func testCriticalMappings() async -> [DJControlAction: Bool] {
        let critical = DJControlAction.automaticPresetCriticalActions.sorted { $0.rawValue < $1.rawValue }
        var result: [DJControlAction: Bool] = [:]
        for action in critical {
            result[action] = profile.hasRuntimeCompatibleMapping(for: action)
        }
        return result
    }
}

@available(*, deprecated, renamed: "MappedMIDIController")
public typealias MappedSeratoController = MappedMIDIController

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
