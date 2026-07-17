import Testing
@testable import MixPilotCore

@Test("One transient unreliable read is tolerated")
func transientUnreliableReadIsTolerated() {
    var tracker = LiveStateReliabilityTracker(failureThreshold: 2)

    let shouldHandOff = tracker.record(isReliable: false)

    #expect(!shouldHandOff)
    #expect(tracker.consecutiveFailures == 1)
}

@Test("Repeated unreliable reads require a safe manual handoff")
func repeatedUnreliableReadsRequireHandoff() {
    var tracker = LiveStateReliabilityTracker(failureThreshold: 2)

    let firstResult = tracker.record(isReliable: false)
    let secondResult = tracker.record(isReliable: false)

    #expect(!firstResult)
    #expect(secondResult)
    #expect(tracker.consecutiveFailures == 2)
}

@Test("A reliable observation resets the failure window")
func reliableObservationResetsFailures() {
    var tracker = LiveStateReliabilityTracker(failureThreshold: 2)

    let firstFailure = tracker.record(isReliable: false)
    let reliableResult = tracker.record(isReliable: true)
    let nextFailure = tracker.record(isReliable: false)

    #expect(!firstFailure)
    #expect(!reliableResult)
    #expect(tracker.consecutiveFailures == 1)
    #expect(!nextFailure)
}

@Test("The tracker always uses a positive threshold")
func trackerNormalizesInvalidThresholds() {
    var tracker = LiveStateReliabilityTracker(failureThreshold: 0)

    let shouldHandOff = tracker.record(isReliable: false)

    #expect(tracker.failureThreshold == 1)
    #expect(shouldHandOff)
}
