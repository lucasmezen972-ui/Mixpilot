#if os(macOS)
import Foundation
import MixPilotHelp

enum AppLocalizedCopy {
    static var language: MixPilotHelpLanguage {
        MixPilotLanguagePreference.current()
    }

    static func text(_ key: String) -> String {
        MixPilotHelpCatalog.shared.localized(key, language: language)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = text(key)
        return String(
            format: format,
            locale: Locale(identifier: language.rawValue),
            arguments: arguments
        )
    }
}
#endif
