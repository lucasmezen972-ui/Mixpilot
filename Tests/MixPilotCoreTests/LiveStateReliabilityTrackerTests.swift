import Testing
@testable import MixPilotCore

@Test("One transient unreliable read is tolerated")
func transientUnreliableReadIsTolerated() {
    var tracker = LiveStateReliabilityTracker(failureThreshold: 2)

    #expect(!tracker.record(isReliable: false))
    #expect(tracker.consecutiveFailures == 1)
}

@Test("Repeated unreliable reads require a safe manual handoff")
func repeatedUnreliableReadsRequireHandoff() {
    var tracker = LiveStateReliabilityTracker(failureThreshold: 2)

    #expect(!tracker.record(isReliable: false))
    #expect(tracker.record(isReliable: false))
    #expect(tracker.consecutiveFailures == 2)
}

@Test("A reliable observation resets the failure window")
func reliableObservationResetsFailures() {
    var tracker = LiveStateReliabilityTracker(failureThreshold: 2)

    #expect(!tracker.record(isReliable: false))
    #expect(!tracker.record(isReliable: true))
    #expect(tracker.consecutiveFailures == 0)
    #expect(!tracker.record(isReliable: false))
}

@Test("The tracker always uses a positive threshold")
func trackerNormalizesInvalidThresholds() {
    var tracker = LiveStateReliabilityTracker(failureThreshold: 0)

    #expect(tracker.failureThreshold == 1)
    #expect(tracker.record(isReliable: false))
}
