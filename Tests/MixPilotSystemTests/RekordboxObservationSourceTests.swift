#if os(macOS)
import Foundation
import Testing
@testable import MixPilotSystem

@Test("rekordbox observation sources distinguish live data from cached data")
func rekordboxObservationSourceFreshness() {
    let observedAt = Date(timeIntervalSince1970: 1_234)

    let currentSources: [RekordboxLibrarySource] = [
        .accessibility(observedAt: observedAt),
        .visibleText(observedAt: observedAt),
        .freshOCR(observedAt: observedAt),
    ]
    let informationalSources: [RekordboxLibrarySource] = [
        .cachedOCR(observedAt: observedAt),
        .spotifyAPI(synchronizedAt: observedAt),
    ]

    #expect(currentSources.allSatisfy { $0.isCurrentObservation })
    #expect(informationalSources.allSatisfy { !$0.isCurrentObservation })
    #expect((currentSources + informationalSources).allSatisfy { $0.date == observedAt })
}
#endif
