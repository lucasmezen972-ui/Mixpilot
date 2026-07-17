#if os(macOS)
import Foundation
import MixPilotHelp

enum AppLocalizedCopy {
    static var language: MixPilotHelpLanguage {
        MixPilotLanguagePreference.current()
    }

    static func text(_ key: String, table: String? = nil) -> String {
        MixPilotHelpCatalog.shared.localized(key, language: language, table: table)
    }

    static func format(
        _ key: String,
        table: String? = nil,
        _ arguments: CVarArg...
    ) -> String {
        let format = text(key, table: table)
        return String(
            format: format,
            locale: Locale(identifier: language.rawValue),
            arguments: arguments
        )
    }

    static func workspace(_ key: String) -> String {
        text(key, table: "Workspace")
    }

    static func workspaceFormat(_ key: String, _ arguments: CVarArg...) -> String {
        formatted(workspace(key), arguments)
    }

    static func command(_ key: String) -> String {
        text(key, table: "Commands")
    }

    static func commandFormat(_ key: String, _ arguments: CVarArg...) -> String {
        formatted(command(key), arguments)
    }

    static func status(_ key: String) -> String {
        text(key, table: "Status")
    }

    static func statusFormat(_ key: String, _ arguments: CVarArg...) -> String {
        formatted(status(key), arguments)
    }

    static func technical(_ key: String) -> String {
        text(key, table: "Technical")
    }

    static func technicalFormat(_ key: String, _ arguments: CVarArg...) -> String {
        formatted(technical(key), arguments)
    }

    private static func formatted(_ format: String, _ arguments: [CVarArg]) -> String {
        String(
            format: format,
            locale: Locale(identifier: language.rawValue),
            arguments: arguments
        )
    }
}
#endif
