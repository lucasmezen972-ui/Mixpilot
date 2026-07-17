import Testing
@testable import MixPilotHelp

@Test("macOS command, window and alert keys resolve in every language")
func commandKeysResolve() {
    let catalog = MixPilotHelpCatalog.shared
    let keys = [
        "commands.prepare",
        "commands.verify",
        "commands.remote.unavailable",
        "commands.remote.new_pairing_code",
        "commands.take_control_now",
        "commands.window.rekordbox_validation",
        "commands.window.help",
        "commands.alert.pairing_unavailable.detail",
        "commands.alert.remote_disabled.detail",
        "commands.check_online_services",
    ]

    for language in MixPilotHelpLanguage.allCases {
        for key in keys {
            let value = catalog.localized(key, language: language, table: "Commands")
            #expect(!value.isEmpty)
            #expect(value != key)
        }
    }
}

@Test("Pairing alert format renders the short-lived code in every language")
func pairingAlertFormatRendersCode() {
    let catalog = MixPilotHelpCatalog.shared

    for language in MixPilotHelpLanguage.allCases {
        let value = catalog.localizedFormat(
            "commands.alert.pairing_development.detail_format",
            language: language,
            table: "Commands",
            "123456"
        )

        #expect(value.contains("123456"))
        #expect(!value.contains("%@"))
        #expect(value.count > 80)
    }
}
