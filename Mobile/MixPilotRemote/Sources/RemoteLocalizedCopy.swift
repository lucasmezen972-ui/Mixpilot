import MixPilotHelp

@MainActor
enum RemoteLocalizedCopy {
    private static let catalog = MixPilotHelpCatalog.shared

    static var language: MixPilotHelpLanguage {
        MixPilotLanguagePreference.current()
    }

    static func text(_ key: String) -> String {
        catalog.localized(key, language: language, table: "Remote")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, locale: Locale(identifier: language.rawValue), arguments: arguments)
    }
}
