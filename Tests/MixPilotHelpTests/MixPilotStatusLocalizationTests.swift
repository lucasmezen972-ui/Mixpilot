import Testing
@testable import MixPilotHelp

@Test("Critical preparation, mapping and Live statuses resolve in every language")
func criticalStatusKeysResolve() {
    let catalog = MixPilotHelpCatalog.shared
    let keys = [
        "status.preparation.no_visible_playlist",
        "status.preparation.audio_start_failed",
        "status.preparation.source_unavailable",
        "status.mapping.create_failed",
        "status.mapping.command_rejected",
        "status.live.arm_choose_backend",
        "status.live.reconcile_state_lost",
        "status.live.manual_safe_point",
        "status.event.manual_active",
        "status.event.set_completed",
    ]

    for language in MixPilotHelpLanguage.allCases {
        for key in keys {
            let value = catalog.localized(key, language: language, table: "Status")
            #expect(!value.isEmpty)
            #expect(value != key)
            #expect(value.count > 5)
        }
    }
}

@Test("Status formats preserve counts, versions, decks and measured values")
func statusFormatsRender() {
    let catalog = MixPilotHelpCatalog.shared

    for language in MixPilotHelpLanguage.allCases {
        let backend = catalog.localizedFormat(
            "status.backend.connected_version",
            language: language,
            table: "Status",
            "rekordbox",
            "7.1.0"
        )
        let prepared = catalog.localizedFormat(
            "status.preparation.tracks_prepared",
            language: language,
            table: "Status",
            50,
            "djay Pro"
        )
        let audio = catalog.localizedFormat(
            "status.preparation.critical_silence",
            language: language,
            table: "Status",
            3.5
        )
        let transition = catalog.localizedFormat(
            "status.log.transition_progress",
            language: language,
            table: "Status",
            4,
            87
        )

        #expect(backend.contains("rekordbox"))
        #expect(backend.contains("7.1.0"))
        #expect(prepared.contains("50"))
        #expect(prepared.contains("djay Pro"))
        #expect(audio.contains("3"))
        #expect(transition.contains("4"))
        #expect(transition.contains("87"))
        #expect(!backend.contains("%@"))
        #expect(!prepared.contains("%d"))
        #expect(!audio.contains("%.1f"))
        #expect(!transition.contains("%d"))
    }
}

@Test("Long safety copy remains complete in all supported languages")
func longSafetyCopyIsNotTruncatedInResources() {
    let catalog = MixPilotHelpCatalog.shared
    let keys = [
        "status.live.coordinator_mismatch",
        "status.live.reconcile_state_lost",
        "status.preparation.audio_start_failed",
        "status.mapping.command_rejected",
    ]

    for language in MixPilotHelpLanguage.allCases {
        for key in keys {
            let value = catalog.localized(key, language: language, table: "Status")
            #expect(value.count >= 35)
            #expect(value.last == "." || value.last == "…")
        }
    }
}
