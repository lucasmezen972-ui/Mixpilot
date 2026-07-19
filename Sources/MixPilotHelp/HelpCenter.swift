import Foundation

public enum MixPilotHelpLanguage: String, CaseIterable, Codable, Sendable {
    case french = "fr"
    case english = "en"
    case spanish = "es"

    public static func preferred(from locale: Locale = .current) -> Self {
        let identifier = locale.language.languageCode?.identifier ?? locale.identifier
        return Self(rawValue: String(identifier.prefix(2)).lowercased()) ?? .french
    }
}

public enum MixPilotLanguagePreference {
    public static let defaultsKey = "mixpilot.preferred-language"

    public static func current(
        defaults: UserDefaults = .standard,
        locale: Locale = .current
    ) -> MixPilotHelpLanguage {
        defaults.string(forKey: defaultsKey)
            .flatMap(MixPilotHelpLanguage.init(rawValue:))
            ?? .preferred(from: locale)
    }

    public static func save(
        _ language: MixPilotHelpLanguage,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(language.rawValue, forKey: defaultsKey)
    }
}

public enum MixPilotHelpCategory: String, CaseIterable, Codable, Sendable {
    case start
    case backend
    case preparation
    case live
    case remote
    case safety
    case troubleshooting
}

public struct MixPilotHelpArticleDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: MixPilotHelpCategory
    public let symbol: String
    public let titleKey: String
    public let summaryKey: String
    public let bodyKey: String
    public let keywordsKey: String

    public init(
        id: String,
        category: MixPilotHelpCategory,
        symbol: String,
        titleKey: String,
        summaryKey: String,
        bodyKey: String,
        keywordsKey: String
    ) {
        self.id = id
        self.category = category
        self.symbol = symbol
        self.titleKey = titleKey
        self.summaryKey = summaryKey
        self.bodyKey = bodyKey
        self.keywordsKey = keywordsKey
    }
}

public struct MixPilotHelpArticle: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: MixPilotHelpCategory
    public let symbol: String
    public let title: String
    public let summary: String
    public let body: String
    public let keywords: String
}

public struct MixPilotHelpCatalog: Sendable {
    public static let shared = MixPilotHelpCatalog()

    public static let definitions: [MixPilotHelpArticleDefinition] = [
        article("getting-started", .start, "sparkles", "help.getting_started"),
        article("choose-backend", .backend, "waveform.badge.magnifyingglass", "help.choose_backend"),
        article("midi-mapping", .backend, "slider.horizontal.3", "help.midi_mapping"),
        article("prepare-set", .preparation, "music.note.list", "help.prepare_set"),
        article("transitions", .preparation, "arrow.triangle.2.circlepath", "help.transitions"),
        article("preflight", .preparation, "checkmark.shield", "help.preflight"),
        article("live", .live, "dot.radiowaves.left.and.right", "help.live"),
        article("iphone-remote", .remote, "iphone.gen3", "help.iphone_remote"),
        article("manual-control", .safety, "hand.raised", "help.manual_control"),
        article("emergency-audio", .safety, "speaker.wave.3", "help.emergency_audio"),
        article("troubleshooting", .troubleshooting, "wrench.and.screwdriver", "help.troubleshooting"),
    ]

    public init() {}

    public func articles(language: MixPilotHelpLanguage) -> [MixPilotHelpArticle] {
        Self.definitions.map { definition in
            MixPilotHelpArticle(
                id: definition.id,
                category: definition.category,
                symbol: definition.symbol,
                title: localized(definition.titleKey, language: language),
                summary: localized(definition.summaryKey, language: language),
                body: localized(definition.bodyKey, language: language),
                keywords: localized(definition.keywordsKey, language: language)
            )
        }
    }

    public func search(
        _ query: String,
        language: MixPilotHelpLanguage,
        category: MixPilotHelpCategory? = nil
    ) -> [MixPilotHelpArticle] {
        let normalizedQuery = Self.normalize(query)
        return articles(language: language).filter { article in
            guard category == nil || article.category == category else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            let haystack = Self.normalize(
                [article.title, article.summary, article.body, article.keywords]
                    .joined(separator: " ")
            )
            return haystack.contains(normalizedQuery)
        }
    }

    public func localized(
        _ key: String,
        language: MixPilotHelpLanguage,
        table: String? = nil
    ) -> String {
        guard let path = Self.resourceBundle().path(
            forResource: language.rawValue,
            ofType: "lproj"
        ),
        let bundle = Bundle(path: path) else {
            return key
        }
        return NSLocalizedString(key, tableName: table, bundle: bundle, comment: "")
    }

    public func localizedFormat(
        _ key: String,
        language: MixPilotHelpLanguage,
        table: String? = nil,
        _ arguments: CVarArg...
    ) -> String {
        let format = localized(key, language: language, table: table)
        return String(format: format, locale: Locale(identifier: language.rawValue), arguments: arguments)
    }

    public static func categoryTitleKey(_ category: MixPilotHelpCategory) -> String {
        "help.category.\(category.rawValue)"
    }

    public static func languageNameKey(_ language: MixPilotHelpLanguage) -> String {
        "help.language.\(language.rawValue)"
    }

    private static func resourceBundle() -> Bundle {
        if let resourcesURL = Bundle.main.resourceURL,
           let packagedBundle = Bundle(
               url: resourcesURL.appendingPathComponent("MixPilot_MixPilotHelp.bundle")
           ) {
            return packagedBundle
        }
        return .module
    }

    private static func article(
        _ id: String,
        _ category: MixPilotHelpCategory,
        _ symbol: String,
        _ prefix: String
    ) -> MixPilotHelpArticleDefinition {
        MixPilotHelpArticleDefinition(
            id: id,
            category: category,
            symbol: symbol,
            titleKey: "\(prefix).title",
            summaryKey: "\(prefix).summary",
            bodyKey: "\(prefix).body",
            keywordsKey: "\(prefix).keywords"
        )
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
