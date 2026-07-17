import Foundation
import Testing
@testable import MixPilotHelp

@Test("Help article identifiers and keys are stable and unique")
func helpIdentifiersAreUnique() {
    let definitions = MixPilotHelpCatalog.definitions

    #expect(definitions.count == 11)
    #expect(Set(definitions.map(\.id)).count == definitions.count)
    #expect(Set(definitions.map(\.titleKey)).count == definitions.count)
    #expect(Set(definitions.map(\.bodyKey)).count == definitions.count)
}

@Test("Every supported language resolves every article")
func everyLanguageResolvesEveryArticle() {
    let catalog = MixPilotHelpCatalog.shared

    for language in MixPilotHelpLanguage.allCases {
        let articles = catalog.articles(language: language)
        #expect(articles.count == MixPilotHelpCatalog.definitions.count)

        for article in articles {
            #expect(!article.title.isEmpty)
            #expect(!article.summary.isEmpty)
            #expect(article.body.count > 40)
            #expect(!article.title.hasPrefix("help."))
            #expect(!article.body.hasPrefix("help."))
        }
    }
}

@Test("French search ignores case and diacritics")
func frenchSearchIgnoresDiacritics() {
    let catalog = MixPilotHelpCatalog.shared

    let accessibilite = catalog.search("ACCESSIBILITE", language: .french)
    let telecommande = catalog.search("telecommande", language: .french)

    #expect(accessibilite.contains { $0.id == "preflight" })
    #expect(telecommande.contains { $0.id == "iphone-remote" })
}

@Test("Search can be restricted to a category")
func searchCanFilterByCategory() {
    let catalog = MixPilotHelpCatalog.shared
    let results = catalog.search("audio", language: .english, category: .safety)

    #expect(!results.isEmpty)
    #expect(results.allSatisfy { $0.category == .safety })
}

@Test("The three languages do not silently fall back to one translation")
func languagesUseDistinctTranslations() {
    let catalog = MixPilotHelpCatalog.shared

    let french = catalog.articles(language: .french).first { $0.id == "getting-started" }
    let english = catalog.articles(language: .english).first { $0.id == "getting-started" }
    let spanish = catalog.articles(language: .spanish).first { $0.id == "getting-started" }

    #expect(french?.title != english?.title)
    #expect(english?.title != spanish?.title)
    #expect(french?.title != spanish?.title)
}

@Test("Preferred language uses a supported locale or French fallback")
func preferredLanguageUsesLocale() {
    #expect(MixPilotHelpLanguage.preferred(from: Locale(identifier: "en_US")) == .english)
    #expect(MixPilotHelpLanguage.preferred(from: Locale(identifier: "es_MX")) == .spanish)
    #expect(MixPilotHelpLanguage.preferred(from: Locale(identifier: "de_DE")) == .french)
}

@Test("Core macOS shell keys resolve in every language")
func coreMacOSShellKeysResolve() {
    let catalog = MixPilotHelpCatalog.shared
    let keys = [
        "app.nav.prepare",
        "app.nav.verify",
        "app.nav.live",
        "app.nav.advanced",
        "app.services.title",
        "app.compatibility_pause.title",
        "app.backend.hero.title",
        "app.backend.equal.detail",
        "app.backend.configure",
        "app.backend.summary.pending_detail",
    ]

    for language in MixPilotHelpLanguage.allCases {
        for key in keys {
            let value = catalog.localized(key, language: language)
            #expect(!value.isEmpty)
            #expect(value != key)
        }
    }
}

@Test("Core macOS shell placeholders render without leaking format tokens")
func coreMacOSShellPlaceholdersRender() {
    let catalog = MixPilotHelpCatalog.shared

    for language in MixPilotHelpLanguage.allCases {
        let version = catalog.localizedFormat(
            "app.backend.version_format",
            language: language,
            "7.0.1"
        )
        let compatibility = catalog.localizedFormat(
            "app.backend.compatibility_summary_format",
            language: language,
            4,
            12
        )
        let pending = catalog.localizedFormat(
            "app.backend.summary.pending_title_format",
            language: language,
            3
        )

        #expect(version.contains("7.0.1"))
        #expect(compatibility.contains("4"))
        #expect(compatibility.contains("12"))
        #expect(pending.contains("3"))
        #expect(!version.contains("%@"))
        #expect(!compatibility.contains("%d"))
        #expect(!pending.contains("%d"))
    }
}

@Test("Primary workspace keys resolve in every language")
func primaryWorkspaceKeysResolve() {
    let catalog = MixPilotHelpCatalog.shared
    let keys = [
        "workspace.prepare.title",
        "workspace.prepare.empty_message",
        "workspace.verify.title",
        "workspace.verify.allow_accessibility",
        "workspace.live.title_running",
        "workspace.live.take_control",
        "workspace.advanced.title",
        "workspace.advanced.simulation_detail",
        "workspace.backend.not_selected_detail",
        "workspace.transitions.subtitle",
    ]

    for language in MixPilotHelpLanguage.allCases {
        for key in keys {
            let value = catalog.localized(key, language: language, table: "Workspace")
            #expect(!value.isEmpty)
            #expect(value != key)
        }
    }
}

@Test("Workspace number and deck formats render in every language")
func workspaceFormatsRender() {
    let catalog = MixPilotHelpCatalog.shared

    for language in MixPilotHelpLanguage.allCases {
        let project = catalog.localizedFormat(
            "workspace.project.summary_format",
            language: language,
            table: "Workspace",
            10,
            9,
            2
        )
        let deck = catalog.localizedFormat(
            "workspace.live.deck_progress_format",
            language: language,
            table: "Workspace",
            "A",
            4,
            9
        )
        let transition = catalog.localizedFormat(
            "workspace.transitions.row_format",
            language: language,
            table: "Workspace",
            16,
            87
        )

        #expect(project.contains("10"))
        #expect(project.contains("9"))
        #expect(project.contains("2"))
        #expect(deck.contains("A"))
        #expect(deck.contains("4"))
        #expect(deck.contains("9"))
        #expect(transition.contains("16"))
        #expect(transition.contains("87"))
        #expect(!project.contains("%d"))
        #expect(!deck.contains("%@"))
        #expect(!transition.contains("%d"))
    }
}
