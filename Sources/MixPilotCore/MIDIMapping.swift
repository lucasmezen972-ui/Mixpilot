import Foundation

public enum SeratoAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case playA
    case playB
    case pauseA
    case pauseB
    case cueA
    case cueB
    case syncA
    case syncB
    case loadA
    case loadB
    case browserUp
    case browserDown
    case browserFocus
    case volumeA
    case volumeB
    case crossfader
    case lowEQA
    case lowEQB
    case midEQA
    case midEQB
    case highEQA
    case highEQB
    case filterA
    case filterB
    case pitchA
    case pitchB
    case echoA
    case echoB
    case echoAmountA
    case echoAmountB
    case loopA
    case loopB
    case exitLoopA
    case exitLoopB

    public var id: String { rawValue }

    public static func play(deck: DeckID) -> Self { deck == .a ? .playA : .playB }
    public static func pause(deck: DeckID) -> Self { deck == .a ? .pauseA : .pauseB }
    public static func cue(deck: DeckID) -> Self { deck == .a ? .cueA : .cueB }
    public static func sync(deck: DeckID) -> Self { deck == .a ? .syncA : .syncB }
    public static func load(deck: DeckID) -> Self { deck == .a ? .loadA : .loadB }
    public static func volume(deck: DeckID) -> Self { deck == .a ? .volumeA : .volumeB }
    public static func lowEQ(deck: DeckID) -> Self { deck == .a ? .lowEQA : .lowEQB }
    public static func filter(deck: DeckID) -> Self { deck == .a ? .filterA : .filterB }
    public static func echo(deck: DeckID) -> Self { deck == .a ? .echoA : .echoB }
    public static func echoAmount(deck: DeckID) -> Self { deck == .a ? .echoAmountA : .echoAmountB }
}

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
    public static let currentSchemaVersion = 1
    public static let confirmationDefaultsKey = "MixPilotMappingConfirmationsV1"

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

    public subscript(action: SeratoAction) -> MIDIMessageMapping? {
        get { mappings[action.rawValue] }
        set {
            mappings[action.rawValue] = newValue
            updatedAt = Date()
        }
    }

    public var configuredRatio: Double {
        guard !SeratoAction.allCases.isEmpty else { return 1 }
        let configured = SeratoAction.allCases.filter { self[$0] != nil }.count
        return Double(configured) / Double(SeratoAction.allCases.count)
    }

    public var confirmationRatio: Double {
        guard !SeratoAction.allCases.isEmpty else { return 1 }
        let confirmations = UserDefaults.standard.dictionary(forKey: Self.confirmationDefaultsKey) as? [String: Bool] ?? [:]
        let confirmed = SeratoAction.allCases.filter { action in
            self[action] != nil && confirmations[action.rawValue] == true
        }.count
        return Double(confirmed) / Double(SeratoAction.allCases.count)
    }

    /// A mapping is considered ready only when the MIDI message exists and the user
    /// has confirmed the corresponding Serato control actually reacted as expected.
    public var completionRatio: Double {
        min(configuredRatio, confirmationRatio)
    }

    public static var developmentDefault: MIDIMappingProfile {
        var profile = MIDIMappingProfile(name: "MixPilot Development Default")

        let notes: [(SeratoAction, UInt8)] = [
            (.playA, 60), (.playB, 61), (.pauseA, 62), (.pauseB, 63),
            (.cueA, 64), (.cueB, 65), (.syncA, 66), (.syncB, 67),
            (.loadA, 68), (.loadB, 69), (.browserUp, 70), (.browserDown, 71),
            (.browserFocus, 72), (.echoA, 73), (.echoB, 74), (.loopA, 75),
            (.loopB, 76), (.exitLoopA, 77), (.exitLoopB, 78),
        ]
        for (action, note) in notes {
            profile[action] = MIDIMessageMapping(kind: .note, number: note, isMomentary: true)
        }

        let controls: [(SeratoAction, UInt8, UInt8, UInt8)] = [
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
        return profile
    }
}

public protocol SeratoCommandSending: Sendable {
    func trigger(_ action: SeratoAction) async throws
    func set(_ action: SeratoAction, value: Double) async throws
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
