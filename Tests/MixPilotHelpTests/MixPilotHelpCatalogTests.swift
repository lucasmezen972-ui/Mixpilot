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
