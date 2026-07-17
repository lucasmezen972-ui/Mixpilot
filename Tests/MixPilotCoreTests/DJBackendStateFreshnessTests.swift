import Foundation
import Testing
@testable import MixPilotCore

@Test func recentReliableStateIsAccepted() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let state = DJBackendState(observedAt: now.addingTimeInterval(-1), isReliable: true)
    #expect(state.isReliableAndFresh(at: now, maximumAge: 2))
}

@Test func staleStateIsRejected() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let state = DJBackendState(observedAt: now.addingTimeInterval(-3), isReliable: true)
    #expect(!state.isReliableAndFresh(at: now, maximumAge: 2))
}

@Test func unreliableStateIsRejected() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let state = DJBackendState(observedAt: now, isReliable: false)
    #expect(!state.isReliableAndFresh(at: now, maximumAge: 2))
}

@Test func futureStateIsRejected() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let state = DJBackendState(observedAt: now.addingTimeInterval(1), isReliable: true)
    #expect(!state.isReliableAndFresh(at: now, maximumAge: 2))
}
