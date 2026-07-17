import Foundation

public enum RekordboxCompatibilityRoute: String, Codable, Sendable {
    case officialXML
    case adaptiveJSON
    case oneLibrary
    case encryptedDatabaseRead
    case midiLearn
    case accessibility
    case proDJLink

    public var displayName: String {
        switch self {
        case .officialXML: "XML officiel"
        case .adaptiveJSON: "JSON adaptatif"
        case .oneLibrary: "OneLibrary"
        case .encryptedDatabaseRead: "Base chiffrée en lecture"
        case .midiLearn: "MIDI Learn"
        case .accessibility: "Accessibilité macOS"
        case .proDJLink: "PRO DJ LINK"
        }
    }
}

public enum RekordboxCompatibilityConfidence: String, Codable, Comparable, Sendable {
    case documented
    case observedInOpenSource
    case requiresDeviceValidation
    case unavailable

    private var rank: Int {
        switch self {
        case .unavailable: 0
        case .requiresDeviceValidation: 1
        case .observedInOpenSource: 2
        case .documented: 3
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }

    public var displayName: String {
        switch self {
        case .documented: "Documenté"
        case .observedInOpenSource: "Observé et testé par la communauté"
        case .requiresDeviceValidation: "Validation sur le Mac requise"
        case .unavailable: "Non disponible"
        }
    }
}

public struct RekordboxCompatibilityFeature: Identifiable, Codable, Hashable, Sendable {
    public var id: String { key }
    public var key: String
    public var title: String
    public var detail: String
    public var route: RekordboxCompatibilityRoute
    public var minimumVersion: String?
    public var confidence: RekordboxCompatibilityConfidence
    public var requiresRekordboxClosed: Bool
    public var safeDuringLive: Bool

    public init(
        key: String,
        title: String,
        detail: String,
        route: RekordboxCompatibilityRoute,
        minimumVersion: String? = nil,
        confidence: RekordboxCompatibilityConfidence,
        requiresRekordboxClosed: Bool = false,
        safeDuringLive: Bool = true
    ) {
        self.key = key
        self.title = title
        self.detail = detail
        self.route = route
        self.minimumVersion = minimumVersion
        self.confidence = confidence
        self.requiresRekordboxClosed = requiresRekordboxClosed
        self.safeDuringLive = safeDuringLive
    }
}

public enum RekordboxCompatibilityCatalog {
    public static let features: [RekordboxCompatibilityFeature] = [
        .init(
            key: "xml-library",
            title: "Bibliothèque XML rekordbox",
            detail: "Titres, artistes, BPM, tonalité, durée, notes, grille TEMPO, repères POSITION_MARK et arbre de playlists.",
            route: .officialXML,
            confidence: .documented
        ),
        .init(
            key: "json-adaptive",
            title: "JSON multi-schémas",
            detail: "Accepte les enveloppes et noms de champs de rekordbox-connect, MCP/pyrekordbox, OneLibrary et les futurs champs inconnus.",
            route: .adaptiveJSON,
            confidence: .observedInOpenSource
        ),
        .init(
            key: "onelibrary",
            title: "OneLibrary rekordbox 7.x",
            detail: "Modèle compatible avec exportLibrary.db : pistes, playlists, cues, MyTags et historiques quand ils sont exportés en JSON par un adaptateur.",
            route: .oneLibrary,
            minimumVersion: "7.0.0",
            confidence: .observedInOpenSource
        ),
        .init(
            key: "database-read",
            title: "Base rekordbox 6/7 en lecture",
            detail: "Interopérabilité avec les sorties de rekordbox-connect et pyrekordbox sans modifier la base ouverte.",
            route: .encryptedDatabaseRead,
            minimumVersion: "6.0.0",
            confidence: .observedInOpenSource
        ),
        .init(
            key: "spotify-library",
            title: "Bibliothèque Spotify",
            detail: "Détection du fournisseur, des URI streamées et de l’éligibilité par version ; aucun téléchargement ni copie du flux.",
            route: .adaptiveJSON,
            minimumVersion: "7.2.3",
            confidence: .requiresDeviceValidation
        ),
        .init(
            key: "midi-core",
            title: "Contrôle decks et mixeur",
            detail: "Play/Pause, Cue, Sync, Load, navigation, faders, EQ, tempo, boucles et sortie de boucle par preset .midi.csv.",
            route: .midiLearn,
            minimumVersion: "5.3.0",
            confidence: .documented
        ),
        .init(
            key: "midi-window",
            title: "Focus de fenêtre",
            detail: "Commande SwitchActiveWindow issue des catalogues rekordbox fournis.",
            route: .midiLearn,
            minimumVersion: "6.6.3",
            confidence: .requiresDeviceValidation
        ),
        .init(
            key: "midi-cfx",
            title: "Color FX par canal",
            detail: "CFXParameterCH1/CH2 pilote le paramètre Color FX ; le filtre doit être sélectionné dans rekordbox avant le Live.",
            route: .midiLearn,
            minimumVersion: "6.7.4",
            confidence: .requiresDeviceValidation
        ),
        .init(
            key: "automix",
            title: "Automix rekordbox",
            detail: "La commande AutoMixStartStop est répertoriée, mais son comportement et son abonnement doivent être confirmés sur l’installation cible.",
            route: .midiLearn,
            minimumVersion: "6.7.4",
            confidence: .requiresDeviceValidation
        ),
        .init(
            key: "accessibility",
            title: "Actions d’interface protégées",
            detail: "Boutons, menus, incréments et confirmations exposés par macOS, avec empreinte, armement et double confirmation destructive.",
            route: .accessibility,
            minimumVersion: "6.0.0",
            confidence: .requiresDeviceValidation
        ),
        .init(
            key: "pro-dj-link",
            title: "Matériel AlphaTheta / Pioneer",
            detail: "Architecture prévue pour les données PRO DJ LINK et OneLibrary, sans activer de contrôle réseau non validé.",
            route: .proDJLink,
            confidence: .observedInOpenSource
        ),
    ]
}

public struct RekordboxExtendedCommand: Identifiable, Codable, Hashable, Sendable {
    public var id: String { csvName }
    public var csvName: String
    public var title: String
    public var category: String
    public var sourceVersions: [String]
    public var runtimeWired: Bool
    public var warning: String?

    public init(
        csvName: String,
        title: String,
        category: String,
        sourceVersions: [String] = ["6.6.3", "6.7.4"],
        runtimeWired: Bool = false,
        warning: String? = nil
    ) {
        self.csvName = csvName
        self.title = title
        self.category = category
        self.sourceVersions = sourceVersions
        self.runtimeWired = runtimeWired
        self.warning = warning
    }
}

public enum RekordboxExtendedCommandCatalog {
    public static let commands: [RekordboxExtendedCommand] = [
        .init(csvName: "Browse", title: "Navigation rotative", category: "Bibliothèque"),
        .init(csvName: "BrowseUp", title: "Titre précédent", category: "Bibliothèque", runtimeWired: true),
        .init(csvName: "BrowseDown", title: "Titre suivant", category: "Bibliothèque", runtimeWired: true),
        .init(csvName: "Back", title: "Fermer le dossier", category: "Bibliothèque"),
        .init(csvName: "Forward", title: "Ouvrir le dossier", category: "Bibliothèque"),
        .init(csvName: "SwitchActiveWindow", title: "Changer de fenêtre active", category: "Bibliothèque", runtimeWired: true),
        .init(csvName: "Preview", title: "Préécoute", category: "Préparation"),
        .init(csvName: "PlayPausePreview", title: "Lecture préécoute", category: "Préparation"),
        .init(csvName: "SkipPreview", title: "Avancer la préécoute", category: "Préparation"),
        .init(csvName: "PlayPause", title: "Lecture / pause", category: "Deck", runtimeWired: true),
        .init(csvName: "Cue", title: "Cue", category: "Deck", runtimeWired: true),
        .init(csvName: "Sync", title: "Sync", category: "Deck", runtimeWired: true),
        .init(csvName: "Load", title: "Charger sur le deck", category: "Deck", runtimeWired: true),
        .init(csvName: "Master", title: "Deck maître", category: "Deck"),
        .init(csvName: "Vinyl", title: "Mode Vinyl", category: "Deck"),
        .init(csvName: "Quantize", title: "Quantize", category: "Deck"),
        .init(csvName: "BeatLoop4", title: "Boucle 4 temps", category: "Boucles", runtimeWired: true),
        .init(csvName: "ReloopExit", title: "Sortir / revenir à la boucle", category: "Boucles", runtimeWired: true),
        .init(csvName: "LoopHalf", title: "Diviser la boucle", category: "Boucles"),
        .init(csvName: "LoopDouble", title: "Doubler la boucle", category: "Boucles"),
        .init(csvName: "LoopIn", title: "Entrée de boucle", category: "Boucles"),
        .init(csvName: "LoopOut", title: "Sortie de boucle", category: "Boucles"),
        .init(csvName: "SemitoneDown", title: "Demi-ton inférieur", category: "Tonalité"),
        .init(csvName: "SemitoneUp", title: "Demi-ton supérieur", category: "Tonalité"),
        .init(csvName: "ChannelFader", title: "Volume de canal", category: "Mixeur", runtimeWired: true),
        .init(csvName: "CrossFader", title: "Crossfader", category: "Mixeur", runtimeWired: true),
        .init(csvName: "EQLow", title: "EQ grave", category: "Mixeur", runtimeWired: true),
        .init(csvName: "EQMid", title: "EQ médium", category: "Mixeur", runtimeWired: true),
        .init(csvName: "EQHigh", title: "EQ aigu", category: "Mixeur", runtimeWired: true),
        .init(csvName: "TempoSlider", title: "Tempo", category: "Mixeur", runtimeWired: true),
        .init(
            csvName: "CFXParameterCH1",
            title: "Paramètre Color FX canal 1",
            category: "Effets",
            sourceVersions: ["6.7.4"],
            runtimeWired: true,
            warning: "Le Color FX sélectionné doit être Filter avant le Live."
        ),
        .init(
            csvName: "CFXParameterCH2",
            title: "Paramètre Color FX canal 2",
            category: "Effets",
            sourceVersions: ["6.7.4"],
            runtimeWired: true,
            warning: "Le Color FX sélectionné doit être Filter avant le Live."
        ),
        .init(
            csvName: "AutoMixStartStop",
            title: "Démarrer / arrêter Automix",
            category: "Automix",
            sourceVersions: ["6.7.4"],
            warning: "Non branché au moteur tant que son comportement Spotify n’est pas confirmé."
        ),
    ]

    public static var runtimeCoverage: Double {
        guard !commands.isEmpty else { return 1 }
        return Double(commands.filter(\.runtimeWired).count) / Double(commands.count)
    }
}

public struct RekordboxAdvancedMIDIPreset: Codable, Hashable, Sendable {
    public var base: RekordboxMIDIPreset
    public var csv: String
    public var addedActions: [SeratoAction]
    public var warnings: [String]

    public init(base: RekordboxMIDIPreset, csv: String, addedActions: [SeratoAction], warnings: [String]) {
        self.base = base
        self.csv = csv
        self.addedActions = addedActions
        self.warnings = warnings
    }
}

public struct RekordboxAdvancedMIDIPresetGenerator: Sendable {
    public init() {}

    public func generate(
        profile: MIDIMappingProfile,
        controllerName: String = RekordboxMIDIPresetGenerator.defaultControllerName,
        generatedAt: Date = Date()
    ) throws -> RekordboxAdvancedMIDIPreset {
        let base = try RekordboxMIDIPresetGenerator().generate(
            profile: profile,
            controllerName: controllerName,
            generatedAt: generatedAt
        )
        var lines = base.csv.split(whereSeparator: \.isNewline).map(String.init)
        var usedCodes = Set(lines.dropFirst().compactMap(Self.inputCode))
        var added: [SeratoAction] = []
        var warnings = base.warnings

        let additions: [(SeratoAction, String, RekordboxMIDIControlType, RekordboxMIDIScope, String)] = [
            (.browserFocus, "SwitchActiveWindow", .button, .global, "Vérifie que le raccourci ouvre bien la vue Bibliothèque utilisée en Live."),
            (.filterA, "CFXParameterCH1", .knobSlider, .global, "Sélectionne Filter comme Color FX avant le Live."),
            (.filterB, "CFXParameterCH2", .knobSlider, .global, "Sélectionne Filter comme Color FX avant le Live."),
        ]

        for addition in additions {
            guard let mapping = profile[addition.0] else { continue }
            let code = RekordboxMIDIPresetGenerator.midiHex(for: mapping)
            guard usedCodes.insert(code).inserted else {
                throw RekordboxMIDIPresetError.duplicateMIDIHex(code)
            }
            lines.append(Self.row(
                action: addition.0,
                csvName: addition.1,
                controlType: addition.2,
                scope: addition.3,
                midiHex: code
            ))
            added.append(addition.0)
            warnings.append("\(addition.0.rawValue): \(addition.4)")
        }

        warnings.append("Echo n’est pas généré automatiquement : les catalogues exposent des slots FX génériques, pas une sélection Echo suffisamment déterministe.")
        warnings.append("Le preset avancé reste en MIDI 7 bits ; les jogs et messages 14 bits nécessitent une phase d’apprentissage dédiée.")
        let csv = lines.joined(separator: "\n") + "\n"
        try Self.validate(csv: csv)
        return RekordboxAdvancedMIDIPreset(base: base, csv: csv, addedActions: added, warnings: warnings)
    }

    private static func row(
        action: SeratoAction,
        csvName: String,
        controlType: RekordboxMIDIControlType,
        scope: RekordboxMIDIScope,
        midiHex: String
    ) -> String {
        var columns = Array(repeating: "", count: 15)
        columns[0] = csvName
        columns[1] = action.rawValue
        columns[2] = controlType.rawValue
        switch scope {
        case .global: columns[3] = midiHex
        case .deckA: columns[4] = midiHex
        case .deckB: columns[5] = midiHex
        }
        columns[13] = "Fast;"
        columns[14] = "MixPilot Advanced \(action.rawValue)"
        return columns.joined(separator: ",")
    }

    private static func inputCode(_ line: String) -> String? {
        let columns = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard columns.count == 15 else { return nil }
        return columns[3...7].first { !$0.isEmpty }
    }

    private static func validate(csv: String) throws {
        let allowed = RekordboxMIDICommandRegistry.verifiedCSVNames.union([
            "SwitchActiveWindow", "CFXParameterCH1", "CFXParameterCH2"
        ])
        let lines = csv.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.first?.hasPrefix("@file,1,") == true else {
            throw RekordboxMIDIPresetError.malformedHeader
        }
        var used = Set<String>()
        for (index, line) in lines.dropFirst().enumerated() {
            let columns = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard columns.count == 15 else {
                throw RekordboxMIDIPresetError.malformedRow(line: index + 2, columnCount: columns.count)
            }
            guard allowed.contains(columns[0]) else {
                throw RekordboxMIDIPresetError.unknownCommand(line: index + 2, command: columns[0])
            }
            let codes = columns[3...7].filter { !$0.isEmpty }
            guard codes.count == 1, let code = codes.first else {
                throw RekordboxMIDIPresetError.missingInput(line: index + 2)
            }
            guard code.count == 4,
                  code.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains($0) }) else {
                throw RekordboxMIDIPresetError.invalidMIDIHex(line: index + 2, value: code)
            }
            guard used.insert(code.uppercased()).inserted else {
                throw RekordboxMIDIPresetError.duplicateMIDIHex(code.uppercased())
            }
        }
    }
}
