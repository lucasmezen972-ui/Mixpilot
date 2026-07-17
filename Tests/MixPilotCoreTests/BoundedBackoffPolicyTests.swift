import Testing
@testable import MixPilotCore

@Test func boundedBackoff() {
    var policy = BoundedBackoffPolicy(limit: 4, firstDelay: 0.25, maximumDelay: 1)
    #expect(policy.nextDelay() == 0.25)
    #expect(policy.nextDelay() == 0.5)
    #expect(policy.nextDelay() == 1)
    #expect(policy.nextDelay() == 1)
    #expect(policy.nextDelay() == nil)
}

@Test func backoffReset() {
    var policy = BoundedBackoffPolicy(limit: 2, firstDelay: 0.5, maximumDelay: 2)
    _ = policy.nextDelay()
    _ = policy.nextDelay()
    policy.reset()
    #expect(policy.count == 0)
    #expect(policy.nextDelay() == 0.5)
}
