import XCTest
@testable import MixPilotCore

final class HelpCenterTests: XCTestCase {
    func testEveryLocaleContainsEveryStableTopicID() {
        for locale in HelpLocale.allCases {
            let catalog = HelpCenterCatalog(locale: locale)
            XCTAssertEqual(Set(catalog.topics.map(\.id)), Set(HelpTopicID.allCases))
            XCTAssertTrue(catalog.topics.allSatisfy { !$0.title.isEmpty && !$0.body.isEmpty })
        }
    }

    func testSearchIsCaseAndDiacriticInsensitive() {
        let catalog = HelpCenterCatalog(locale: .french)
        XCTAssertEqual(catalog.search("PREFLIGHT").first?.id, .preflight)
        XCTAssertEqual(catalog.search("depannage").first?.id, .troubleshooting)
    }

    func testEmptySearchReturnsAllTopics() {
        let catalog = HelpCenterCatalog(locale: .english)
        XCTAssertEqual(catalog.search("  ").count, HelpTopicID.allCases.count)
    }

    func testIncidentRoutingProvidesContextualHelp() {
        let catalog = HelpCenterCatalog(locale: .spanish)
        let silenceTopics = catalog.topics(for: .audioSilence).map(\.id)
        XCTAssertTrue(silenceTopics.contains(.emergencyPlayback))
        XCTAssertTrue(silenceTopics.contains(.troubleshooting))

        let midiTopics = catalog.topics(for: .midiUnavailable).map(\.id)
        XCTAssertTrue(midiTopics.contains(.connection))
        XCTAssertTrue(midiTopics.contains(.mappings))
    }

    func testLongLocalizedTextRemainsAvailableOffline() {
        for locale in HelpLocale.allCases {
            let catalog = HelpCenterCatalog(locale: locale)
            XCTAssertTrue(catalog.topics.allSatisfy { $0.body.count >= 60 })
        }
    }
}
