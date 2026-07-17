import Foundation

public enum RekordboxMIDIControlType: String, Codable, Hashable, Sendable {
    case button = "Button"
    case knobSlider = "KnobSlider"
    case rotary = "Rotary"
}

public enum RekordboxMIDIScope: String, Codable, Hashable, Sendable {
    case global
    case deckA
    case deckB
}

public struct RekordboxMIDICommandDefinition: Codable, Hashable, Sendable {
    public var csvName: String
    public var controlType: RekordboxMIDIControlType
    public var scope: RekordboxMIDIScope
    public var sourceVersions: [String]
    public var semanticWarning: String?

    public init(
        csvName: String,
        controlType: RekordboxMIDIControlType,
        scope: RekordboxMIDIScope,
        sourceVersions: [String] = ["6.6.3", "6.7.4"],
        semanticWarning: String? = nil
    ) {
        self.csvName = csvName
        self.controlType = controlType
        self.scope = scope
        self.sourceVersions = sourceVersions
        self.semanticWarning = semanticWarning
    }
}

public enum RekordboxMIDICommandRegistry {
    /// Conservative subset observed in both the rekordbox 6.6.3 and 6.7.4
    /// command catalogues supplied to the project. Newer versions may retain
    /// these commands, but a real import and device test is still required.
    public static func definition(for action: SeratoAction) -> RekordboxMIDICommandDefinition? {
        switch action {
        case .playA:
            button("PlayPause", .deckA)
        case .playB:
            button("PlayPause", .deckB)
        case .pauseA:
            button("PlayPause", .deckA, warning: "rekordbox exposes PlayPause as a toggle; pause requires deck-state verification.")
        case .pauseB:
            button("PlayPause", .deckB, warning: "rekordbox exposes PlayPause as a toggle; pause requires deck-state verification.")
        case .cueA:
            button("Cue", .deckA)
        case .cueB:
            button("Cue", .deckB)
        case .syncA:
            button("Sync", .deckA)
        case .syncB:
            button("Sync", .deckB)
        case .loadA:
            button("Load", .deckA)
        case .loadB:
            button("Load", .deckB)
        case .browserUp:
            button("BrowseUp", .global)
        case .browserDown:
            button("BrowseDown", .global)
        case .volumeA:
            slider("ChannelFader", .deckA)
        case .volumeB:
            slider("ChannelFader", .deckB)
        case .crossfader:
            slider("CrossFader", .global)
        case .lowEQA:
            slider("EQLow", .deckA)
        case .lowEQB:
            slider("EQLow", .deckB)
        case .midEQA:
            slider("EQMid", .deckA)
        case .midEQB:
            slider("EQMid", .deckB)
        case .highEQA:
            slider("EQHigh", .deckA)
        case .highEQB:
            slider("EQHigh", .deckB)
        case .pitchA:
            slider("TempoSlider", .deckA)
        case .pitchB:
            slider("TempoSlider", .deckB)
        case .loopA:
            button("BeatLoop4", .deckA)
        case .loopB:
            button("BeatLoop4", .deckB)
        case .exitLoopA:
            button("ReloopExit", .deckA)
        case .exitLoopB:
            button("ReloopExit", .deckB)
        case .browserFocus,
             .filterA, .filterB,
             .echoA, .echoB,
             .echoAmountA, .echoAmountB:
            nil
        }
    }

    public static var verifiedCSVNames: Set<String> {
        Set(SeratoAction.allCases.compactMap { definition(for: $0)?.csvName })
    }

    private static func button(
        _ csvName: String,
        _ scope: RekordboxMIDIScope,
        warning: String? = nil
    ) -> RekordboxMIDICommandDefinition {
        RekordboxMIDICommandDefinition(
            csvName: csvName,
            controlType: .button,
            scope: scope,
            semanticWarning: warning
        )
    }

    private static func slider(
        _ csvName: String,
        _ scope: RekordboxMIDIScope
    ) -> RekordboxMIDICommandDefinition {
        RekordboxMIDICommandDefinition(
            csvName: csvName,
            controlType: .knobSlider,
            scope: scope
        )
    }
}

public struct RekordboxMIDIPreset: Codable, Hashable, Sendable {
    public var controllerName: String
    public var generatedAt: Date
    public var csv: String
    public var supportedActions: [SeratoAction]
    public var unsupportedActions: [SeratoAction]
    public var warnings: [String]
    public var observedCommandCatalogueVersions: [String]
    public var validationStatus: DJBackendValidationStatus

    public init(
        controllerName: String,
        generatedAt: Date,
        csv: String,
        supportedActions: [SeratoAction],
        unsupportedActions: [SeratoAction],
        warnings: [String],
        observedCommandCatalogueVersions: [String] = ["6.6.3", "6.7.4"],
        validationStatus: DJBackendValidationStatus = .requiresDeviceValidation
    ) {
        self.controllerName = controllerName
        self.generatedAt = generatedAt
        self.csv = csv
        self.supportedActions = supportedActions
        self.unsupportedActions = unsupportedActions
        self.warnings = warnings
        self.observedCommandCatalogueVersions = observedCommandCatalogueVersions
        self.validationStatus = validationStatus
    }
}

public enum RekordboxMIDIPresetError: Error, LocalizedError, Equatable {
    case emptyControllerName
    case noSupportedMappings
    case malformedHeader
    case malformedRow(line: Int, columnCount: Int)
    case invalidMIDIHex(line: Int, value: String)
    case duplicateMIDIHex(String)
    case unknownCommand(line: Int, command: String)
    case missingInput(line: Int)

    public var errorDescription: String? {
        switch self {
        case .emptyControllerName:
            "Le nom du contrôleur rekordbox est vide."
        case .noSupportedMappings:
            "Le profil ne contient aucune commande rekordbox vérifiée."
        case .malformedHeader:
            "L’en-tête @file du preset rekordbox est invalide."
        case .malformedRow(let line, let count):
            "La ligne \(line) du preset contient \(count) colonnes au lieu de 15."
        case .invalidMIDIHex(let line, let value):
            "Le code MIDI « \(value) » de la ligne \(line) n’est pas un code hexadécimal sur 4 caractères."
        case .duplicateMIDIHex(let value):
            "Le code MIDI \(value) est affecté plusieurs fois."
        case .unknownCommand(let line, let command):
            "La commande rekordbox « \(command) » de la ligne \(line) n’est pas dans le registre vérifié."
        case .missingInput(let line):
            "La ligne \(line) ne contient aucun MIDI IN."
        }
    }
}

public struct RekordboxMIDIPresetGenerator: Sendable {
    public static let defaultControllerName = "MixPilot Virtual Controller"

    public init() {}

    public func generate(
        profile: MIDIMappingProfile,
        controllerName: String = Self.defaultControllerName,
        generatedAt: Date = Date()
    ) throws -> RekordboxMIDIPreset {
        let cleanedName = controllerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { throw RekordboxMIDIPresetError.emptyControllerName }

        var rows: [String] = []
        var supported: [SeratoAction] = []
        var unsupported: [SeratoAction] = []
        var warnings: [String] = []

        for action in SeratoAction.allCases {
            guard let mapping = profile[action],
                  let definition = RekordboxMIDICommandRegistry.definition(for: action) else {
                if profile[action] != nil { unsupported.append(action) }
                continue
            }

            let midiHex = Self.midiHex(for: mapping)
            rows.append(Self.row(
                action: action,
                definition: definition,
                midiHex: midiHex
            ))
            supported.append(action)
            if let warning = definition.semanticWarning {
                warnings.append("\(action.rawValue): \(warning)")
            }
        }

        guard !supported.isEmpty else { throw RekordboxMIDIPresetError.noSupportedMappings }

        if !unsupported.isEmpty {
            warnings.append("Commandes exclues faute de nom rekordbox vérifié : \(unsupported.map(\.rawValue).joined(separator: ", ")).")
        }
        warnings.append("Le preset utilise uniquement des messages MIDI 7 bits. Les jog wheels et faders 14 bits nécessitent un traducteur ou un apprentissage dédié.")
        warnings.append("Les commandes proviennent des catalogues 6.6.3/6.7.4 et doivent être validées sur la version rekordbox installée, notamment 7.2.3 ou ultérieure avec Spotify.")

        let header = "@file,1,\(Self.escapeCSV(cleanedName))"
        let csv = ([header] + rows).joined(separator: "\n") + "\n"
        try RekordboxMIDIPresetValidator().validate(csv: csv)

        return RekordboxMIDIPreset(
            controllerName: cleanedName,
            generatedAt: generatedAt,
            csv: csv,
            supportedActions: supported,
            unsupportedActions: unsupported,
            warnings: warnings
        )
    }

    public static func midiHex(for mapping: MIDIMessageMapping) -> String {
        let statusBase: UInt8 = mapping.kind == .note ? 0x90 : 0xB0
        let status = statusBase | (mapping.channel & 0x0F)
        return String(format: "%02X%02X", status, mapping.number & 0x7F)
    }

    private static func row(
        action: SeratoAction,
        definition: RekordboxMIDICommandDefinition,
        midiHex: String
    ) -> String {
        var columns = Array(repeating: "", count: 15)
        columns[0] = definition.csvName
        columns[1] = action.rawValue
        columns[2] = definition.controlType.rawValue

        switch definition.scope {
        case .global:
            columns[3] = midiHex
        case .deckA:
            columns[4] = midiHex
        case .deckB:
            columns[5] = midiHex
        }

        columns[13] = definition.controlType == .button ? "Fast;" : "Fast;"
        columns[14] = "MixPilot \(action.rawValue)"
        return columns.map(Self.escapeCSV).joined(separator: ",")
    }

    private static func escapeCSV(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

public struct RekordboxMIDIPresetValidator: Sendable {
    public init() {}

    public func validate(csv: String) throws {
        let lines = csv
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        guard let header = lines.first,
              header.hasPrefix("@file,1,"),
              header.count > "@file,1,".count else {
            throw RekordboxMIDIPresetError.malformedHeader
        }

        var usedMIDI = Set<String>()
        for (offset, line) in lines.dropFirst().enumerated() {
            let lineNumber = offset + 2
            let columns = parseCSVLine(line)
            guard columns.count == 15 else {
                throw RekordboxMIDIPresetError.malformedRow(line: lineNumber, columnCount: columns.count)
            }
            let command = columns[0]
            guard RekordboxMIDICommandRegistry.verifiedCSVNames.contains(command) else {
                throw RekordboxMIDIPresetError.unknownCommand(line: lineNumber, command: command)
            }

            let inputCodes = columns[3...7].filter { !$0.isEmpty }
            guard inputCodes.count == 1, let code = inputCodes.first else {
                throw RekordboxMIDIPresetError.missingInput(line: lineNumber)
            }
            guard code.count == 4,
                  code.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains($0) }) else {
                throw RekordboxMIDIPresetError.invalidMIDIHex(line: lineNumber, value: code)
            }
            let normalized = code.uppercased()
            guard usedMIDI.insert(normalized).inserted else {
                throw RekordboxMIDIPresetError.duplicateMIDIHex(normalized)
            }
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var insideQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                let next = line.index(after: index)
                if insideQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    index = line.index(after: next)
                    continue
                }
                insideQuotes.toggle()
            } else if character == ",", !insideQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
            index = line.index(after: index)
        }
        fields.append(current)
        return fields
    }
}
