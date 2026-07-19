import Foundation

public struct SeratoXMLPreset: Hashable, Sendable {
    public var name: String
    public var version: String
    public var xml: String
    public var supportedActions: [SeratoAction]
    public var unsupportedActions: [SeratoAction]

    public init(
        name: String,
        version: String,
        xml: String,
        supportedActions: [SeratoAction],
        unsupportedActions: [SeratoAction]
    ) {
        self.name = name
        self.version = version
        self.xml = xml
        self.supportedActions = supportedActions
        self.unsupportedActions = unsupportedActions
    }

    public var coverageRatio: Double {
        guard !SeratoAction.allCases.isEmpty else { return 1 }
        return Double(supportedActions.count) / Double(SeratoAction.allCases.count)
    }
}

public struct SeratoXMLPresetGenerator: Sendable {
    public static let presetName = "MixPilot Autopilot"
    public static let presetVersion = "1.0.1"

    public init() {}

    public func generate(
        profile: MIDIMappingProfile,
        seratoApplicationVersion: String = "Serato DJ Pro 4.x"
    ) -> SeratoXMLPreset {
        var controls: [String] = []
        var supported: [SeratoAction] = []
        var unsupported: [SeratoAction] = []

        for action in SeratoAction.allCases {
            guard let mapping = profile[action],
                  let binding = binding(for: action) else {
                unsupported.append(action)
                continue
            }
            controls.append(renderControl(mapping: mapping, binding: binding))
            supported.append(action)
        }

        let sourceNotice = """
            <!--
              MixPilot Autopilot generated preset \(Self.presetVersion).
              XML structure is based on public Serato DJ Pro mappings distributed
              under the MIT License by marscanbueno/serato-dj-pro-midi-maps.
              Command names and translation forms are cross-checked against
              Kovarsk/SERATO-XML-WIKI and additional public Serato mappings.

              File installation is AUTOMATED_SUCCESS only. Actual Serato control
              remains REQUIRES_SERATO_VALIDATION until tested on the target Mac.
            -->
            """

        let xml = """
        <midi app="\(escapeAttribute(seratoApplicationVersion))">
        \(sourceNotice)
        \(controls.joined(separator: "\n"))
        </midi>
        """

        return SeratoXMLPreset(
            name: Self.presetName,
            version: Self.presetVersion,
            xml: xml,
            supportedActions: supported,
            unsupportedActions: unsupported
        )
    }

    private func binding(for action: SeratoAction) -> SeratoXMLBinding? {
        switch action {
        case .playA, .pauseA:
            return .toggle(command: "play", deckSet: "Default", deckID: 0)
        case .playB, .pauseB:
            return .toggle(command: "play", deckSet: "Default", deckID: 1)
        case .cueA:
            return .explicit(command: "cue", deckSet: "Default", deckID: 0)
        case .cueB:
            return .explicit(command: "cue", deckSet: "Default", deckID: 1)
        case .syncA:
            return .toggle(command: "sync", deckSet: "Default", deckID: 0)
        case .syncB:
            return .toggle(command: "sync", deckSet: "Default", deckID: 1)
        case .loadA:
            return .explicit(command: "load_track", deckSet: "Default", deckID: 0)
        case .loadB:
            return .explicit(command: "load_track", deckSet: "Default", deckID: 1)
        case .browserUp:
            return .staticValue(command: "library_scroll", deckSet: "Default", deckID: 0, value: "up", actionOn: "hold")
        case .browserDown:
            return .staticValue(command: "library_scroll", deckSet: "Default", deckID: 0, value: "down", actionOn: "hold")
        case .browserFocus:
            return .staticValue(command: "tab_library", deckSet: "Default", deckID: 0, value: "TAB", actionOn: "press")
        case .volumeA:
            return .continuous(command: "upfader", deckSet: "Default", deckID: 0)
        case .volumeB:
            return .continuous(command: "upfader", deckSet: "Default", deckID: 1)
        case .lowEQA:
            return .continuous(command: "deck_eq_lo", deckSet: "Default", deckID: 0)
        case .lowEQB:
            return .continuous(command: "deck_eq_lo", deckSet: "Default", deckID: 1)
        case .midEQA:
            return .continuous(command: "deck_eq_mid", deckSet: "Default", deckID: 0)
        case .midEQB:
            return .continuous(command: "deck_eq_mid", deckSet: "Default", deckID: 1)
        case .highEQA:
            return .continuous(command: "deck_eq_hi", deckSet: "Default", deckID: 0)
        case .highEQB:
            return .continuous(command: "deck_eq_hi", deckSet: "Default", deckID: 1)
        case .filterA:
            return .continuous(command: "deck_filter_auto", deckSet: "Default", deckID: 0)
        case .filterB:
            return .continuous(command: "deck_filter_auto", deckSet: "Default", deckID: 1)
        case .pitchA:
            return .continuous(command: "pitch_slider", deckSet: "Default", deckID: 0)
        case .pitchB:
            return .continuous(command: "pitch_slider", deckSet: "Default", deckID: 1)
        case .loopA, .exitLoopA:
            return .toggle(command: "auto_loop_enable", deckSet: "Default", deckID: 0)
        case .loopB, .exitLoopB:
            return .toggle(command: "auto_loop_enable", deckSet: "Default", deckID: 1)
        case .crossfader, .echoA, .echoB, .echoAmountA, .echoAmountB:
            // Their exact control target or FX slot selection is deliberately not
            // guessed. The transition engine has a volume-fader fallback.
            return nil
        }
    }

    private func renderControl(mapping: MIDIMessageMapping, binding: SeratoXMLBinding) -> String {
        let channel = Int(mapping.channel) + 1
        let eventType = mapping.kind == .note ? "Note On" : "Control Change"
        let dataType = mapping.kind == .controlChange ? " data_type=\"Absolute 7\"" : ""
        let command = escapeElementName(binding.command)
        let deckSet = escapeAttribute(binding.deckSet)
        let translation = renderTranslation(binding.translation)

        return """
            <control channel="\(channel)" event_type="\(eventType)"\(dataType) control="\(mapping.number)">
                <userio event="click">
                    <\(command) deck_set="\(deckSet)" deck_id="\(binding.deckID)" slot_id="\(binding.slotID)">
                        \(translation)
                    </\(command)>
                </userio>
            </control>
        """
    }

    private func renderTranslation(_ translation: SeratoXMLTranslation) -> String {
        switch translation {
        case .explicit(let actionOn):
            return "<translation action_on=\"\(escapeAttribute(actionOn))\" behaviour=\"explicit\"/>"
        case .toggle(let actionOn):
            return "<translation action_on=\"\(escapeAttribute(actionOn))\" behaviour=\"toggle\"/>"
        case .staticValue(let actionOn, let value):
            return "<translation action_on=\"\(escapeAttribute(actionOn))\" behaviour=\"static\" static_value=\"\(escapeAttribute(value))\"/>"
        }
    }

    private func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func escapeElementName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return value.unicodeScalars.allSatisfy(allowed.contains) ? value : "unsupported_command"
    }
}

private struct SeratoXMLBinding: Sendable {
    var command: String
    var deckSet: String
    var deckID: Int
    var slotID: Int
    var translation: SeratoXMLTranslation

    static func explicit(command: String, deckSet: String, deckID: Int, slotID: Int = 0) -> Self {
        Self(command: command, deckSet: deckSet, deckID: deckID, slotID: slotID, translation: .explicit(actionOn: "press"))
    }

    static func toggle(command: String, deckSet: String, deckID: Int, slotID: Int = 0) -> Self {
        Self(command: command, deckSet: deckSet, deckID: deckID, slotID: slotID, translation: .toggle(actionOn: "press"))
    }

    static func continuous(command: String, deckSet: String, deckID: Int, slotID: Int = 0) -> Self {
        Self(command: command, deckSet: deckSet, deckID: deckID, slotID: slotID, translation: .explicit(actionOn: "any"))
    }

    static func staticValue(
        command: String,
        deckSet: String,
        deckID: Int,
        slotID: Int = 0,
        value: String,
        actionOn: String
    ) -> Self {
        Self(
            command: command,
            deckSet: deckSet,
            deckID: deckID,
            slotID: slotID,
            translation: .staticValue(actionOn: actionOn, value: value)
        )
    }
}

private enum SeratoXMLTranslation: Sendable {
    case explicit(actionOn: String)
    case toggle(actionOn: String)
    case staticValue(actionOn: String, value: String)
}
