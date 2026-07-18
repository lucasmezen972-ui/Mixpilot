import Foundation

public extension DJControlAction {
    /// Commands required by the unattended runtime. Crossfader and effects are
    /// intentionally absent because every transition must keep a verified
    /// volume/EQ fallback when a backend cannot guarantee those controls.
    static let automaticPresetCriticalActions: Set<DJControlAction> = [
        .playA, .playB, .pauseA, .pauseB,
        .syncA, .syncB,
        .loadA, .loadB,
        .browserUp, .browserDown, .browserFocus,
        .volumeA, .volumeB,
        .lowEQA, .lowEQB,
        .filterA, .filterB,
    ]
}

@available(*, deprecated, renamed: "DJControlAction")
public typealias SeratoAction = DJControlAction

public enum MIDIMessageKind: String, Codable, Sendable {
    case note
    case controlChange
}

public struct MIDIMessageMapping: Codable, Hashable, Sendable {
    public var kind: MIDIMessageKind
    public var channel: UInt8
    public var number: UInt8
    public var minimumRawValue: UInt8
    public var maximumRawValue: UInt8
    public var offRawValue: UInt8
    public var isMomentary: Bool

    public init(
        kind: MIDIMessageKind,
        channel: UInt8 = 0,
        number: UInt8,
        minimumRawValue: UInt8 = 0,
        maximumRawValue: UInt8 = 127,
        offRawValue: UInt8 = 0,
        isMomentary: Bool = false
    ) {
        self.kind = kind
        self.channel = min(channel, 15)
        self.number = min(number, 127)
        self.minimumRawValue = min(minimumRawValue, 127)
        self.maximumRawValue = min(maximumRawValue, 127)
        self.offRawValue = min(offRawValue, 127)
        self.isMomentary = isMomentary
    }

    public func rawValue(for normalizedValue: Double) -> UInt8 {
        let normalized = normalizedValue.clamped(to: 0...1)
        let lower = Double(min(minimumRawValue, maximumRawValue))
        let upper = Double(max(minimumRawValue, maximumRawValue))
        return UInt8((lower + ((upper - lower) * normalized)).rounded())
    }
}

public struct MIDIMappingProfile: Identifiable, Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 2
    public static let confirmationDefaultsKey = "MixPilotMappingConfirmationsV2"
    public static let automaticPresetActionsDefaultsKey = "MixPilotAutomaticPresetActionsV2"
    public static let automaticPresetVersionDefaultsKey = "MixPilotAutomaticPresetVersionV2"

    public static let legacyConfirmationDefaultsKey = "MixPilotMappingConfirmationsV1"
    public static let legacyAutomaticPresetActionsDefaultsKey = "MixPilotAutomaticSeratoPresetActionsV1"
    public static let legacyAutomaticPresetVersionDefaultsKey = "MixPilotAutomaticSeratoPresetVersionV1"

    public let id: UUID
    public var schemaVersion: Int
    public var name: String
    public var mappings: [String: MIDIMessageMapping]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        schemaVersion: Int = Self.currentSchemaVersion,
        name: String,
        mappings: [String: MIDIMessageMapping] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.mappings = mappings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public subscript(action: DJControlAction) -> MIDIMessageMapping? {
        get { mappings[action.rawValue] }
        set {
            mappings[action.rawValue] = newValue
            updatedAt = Date()
        }
    }

    public var configuredRatio: Double {
        guard !DJControlAction.allCases.isEmpty else { return 1 }
        let configured = DJControlAction.allCases.filter { self[$0] != nil }.count
        return Double(configured) / Double(DJControlAction.allCases.count)
    }

    public var confirmationRatio: Double {
        Self.manualConfirmationRatio(defaults: .standard)
    }

    public var automaticPresetCoverageRatio: Double {
        Self.automaticPresetCoverageRatio(defaults: .standard)
    }

    /// Installation proves that a versioned profile contains the required
    /// messages. It never proves that the selected DJ software or controller
    /// reacted correctly; real confirmation remains stored separately.
    public var completionRatio: Double {
        min(configuredRatio, max(confirmationRatio, automaticPresetCoverageRatio))
    }

    public static func recordAutomaticPresetInstallation(
        supportedActions: [DJControlAction],
        version: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(supportedActions.map(\.rawValue).sorted(), forKey: automaticPresetActionsDefaultsKey)
        defaults.set(version, forKey: automaticPresetVersionDefaultsKey)
    }

    public static func clearAutomaticPresetInstallation(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: automaticPresetActionsDefaultsKey)
        defaults.removeObject(forKey: automaticPresetVersionDefaultsKey)
        defaults.removeObject(forKey: legacyAutomaticPresetActionsDefaultsKey)
        defaults.removeObject(forKey: legacyAutomaticPresetVersionDefaultsKey)
    }

    public static func automaticPresetCoverageRatio(defaults: UserDefaults) -> Double {
        let required = DJControlAction.automaticPresetCriticalActions
        guard !required.isEmpty else { return 1 }
        let installed = Set(
            defaults.stringArray(forKey: automaticPresetActionsDefaultsKey)
                ?? defaults.stringArray(forKey: legacyAutomaticPresetActionsDefaultsKey)
                ?? []
        )
        let covered = required.filter { installed.contains($0.rawValue) }.count
        return Double(covered) / Double(required.count)
    }

    public static func manualConfirmationRatio(defaults: UserDefaults) -> Double {
        guard !DJControlAction.allCases.isEmpty else { return 1 }
        let confirmations = defaults.dictionary(forKey: confirmationDefaultsKey) as? [String: Bool]
            ?? defaults.dictionary(forKey: legacyConfirmationDefaultsKey) as? [String: Bool]
            ?? [:]
        let confirmed = DJControlAction.allCases.filter { confirmations[$0.rawValue] == true }.count
        return Double(confirmed) / Double(DJControlAction.allCases.count)
    }

    public static var developmentDefault: MIDIMappingProfile {
        let stableDate = Date(timeIntervalSince1970: 1_700_000_000)
        var profile = MIDIMappingProfile(
            id: UUID(uuidString: "D13C83D0-4EA7-4A21-9839-9B531466D10F")!,
            name: "MixPilot Development Default",
            createdAt: stableDate,
            updatedAt: stableDate
        )

        let notes: [(DJControlAction, UInt8)] = [
            (.playA, 60), (.playB, 61), (.pauseA, 62), (.pauseB, 63),
            (.cueA, 64), (.cueB, 65), (.syncA, 66), (.syncB, 67),
            (.loadA, 68), (.loadB, 69), (.browserUp, 70), (.browserDown, 71),
            (.browserFocus, 72), (.echoA, 73), (.echoB, 74), (.loopA, 75),
            (.loopB, 76), (.exitLoopA, 77), (.exitLoopB, 78),
        ]
        for (action, note) in notes {
            profile[action] = MIDIMessageMapping(kind: .note, number: note, isMomentary: true)
        }

        let controls: [(DJControlAction, UInt8, UInt8, UInt8)] = [
            (.crossfader, 10, 0, 127),
            (.volumeA, 11, 0, 127), (.volumeB, 12, 0, 127),
            (.lowEQA, 20, 0, 64), (.lowEQB, 21, 0, 64),
            (.midEQA, 22, 0, 64), (.midEQB, 23, 0, 64),
            (.highEQA, 24, 0, 64), (.highEQB, 25, 0, 64),
            (.filterA, 26, 0, 127), (.filterB, 27, 0, 127),
            (.pitchA, 28, 0, 127), (.pitchB, 29, 0, 127),
            (.echoAmountA, 30, 0, 127), (.echoAmountB, 31, 0, 127),
        ]
        for (action, controller, minimum, maximum) in controls {
            profile[action] = MIDIMessageMapping(
                kind: .controlChange,
                number: controller,
                minimumRawValue: minimum,
                maximumRawValue: maximum
            )
        }
        // Mapping assignments intentionally update the profile timestamp. Restore
        // the built-in fixture's stable publication timestamp before hashing it.
        profile.updatedAt = stableDate
        return profile
    }
}

public protocol DJCommandSending: Sendable {
    func trigger(_ action: DJControlAction) async throws
    func set(_ action: DJControlAction, value: Double) async throws
}

@available(*, deprecated, renamed: "DJCommandSending")
public typealias SeratoCommandSending = DJCommandSending

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
