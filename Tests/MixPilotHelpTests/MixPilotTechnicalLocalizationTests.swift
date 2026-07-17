import Testing
@testable import MixPilotHelp

@Test("Technical workflow keys resolve in every supported language")
func technicalKeysResolve() {
    let catalog = MixPilotHelpCatalog.shared
    let keys = [
        "technical.quick.title",
        "technical.quick.continue",
        "technical.rehearsal.player_unavailable",
        "technical.analysis.warning",
        "technical.inspector.no_transition_detail",
        "technical.rekordbox_hub.title",
        "technical.rekordbox_lab.read_only",
        "technical.device.subtitle",
        "technical.rekordbox_mapping.warning",
        "technical.serato_mapping.warning",
        "technical.cloud.compatibility_title",
    ]

    for language in MixPilotHelpLanguage.allCases {
        for key in keys {
            let value = catalog.localized(key, language: language, table: "Technical")
            #expect(!value.isEmpty)
            #expect(value != key)
        }
    }
}

@Test("Technical counts and confidence values render without placeholder leaks")
func technicalFormatsRender() {
    let catalog = MixPilotHelpCatalog.shared

    for language in MixPilotHelpLanguage.allCases {
        let ready = catalog.localizedFormat(
            "technical.quick.ready_format",
            language: language,
            table: "Technical",
            42,
            "rekordbox"
        )
        let confidence = catalog.localizedFormat(
            "technical.rehearsal.confidence_format",
            language: language,
            table: "Technical",
            87
        )
        let columns = catalog.localizedFormat(
            "technical.rekordbox_lab.columns_format",
            language: language,
            table: "Technical",
            12
        )
        let result = catalog.localizedFormat(
            "technical.device.result_format",
            language: language,
            table: "Technical",
            "PlayPause",
            "OK"
        )

        #expect(ready.contains("42"))
        #expect(ready.contains("rekordbox"))
        #expect(confidence.contains("87"))
        #expect(columns.contains("12"))
        #expect(result.contains("PlayPause"))
        #expect(result.contains("OK"))
        #expect(!ready.contains("%d"))
        #expect(!ready.contains("%@"))
        #expect(!confidence.contains("%d"))
        #expect(!columns.contains("%d"))
        #expect(!result.contains("%@"))
    }
}

@Test("Technical safety instructions remain substantive")
func technicalSafetyInstructionsRemainSubstantive() {
    let catalog = MixPilotHelpCatalog.shared
    let keys = [
        "technical.rekordbox_lab.read_only",
        "technical.device.subtitle",
        "technical.rekordbox_mapping.warning",
        "technical.serato_mapping.warning",
        "technical.analysis.warning",
    ]

    for language in MixPilotHelpLanguage.allCases {
        for key in keys {
            let value = catalog.localized(key, language: language, table: "Technical")
            #expect(value.count >= 35)
            #expect(value.last == ".")
        }
    }
}
