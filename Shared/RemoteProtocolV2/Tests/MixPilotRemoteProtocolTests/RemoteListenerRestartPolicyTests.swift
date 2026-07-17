import Foundation
import Testing
@testable import MixPilotRemoteProtocol

@Test("Listener restart delays grow exponentially and stop at the retry budget")
func listenerRestartDelaysAreBounded() {
    var policy = RemoteListenerRestartPolicy(
        maximumAttempts: 4,
        initialDelay: 1,
        maximumDelay: 4,
        stableResetInterval: 60
    )
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    #expect(policy.nextDelay(after: now) == 1)
    #expect(policy.nextDelay(after: now) == 2)
    #expect(policy.nextDelay(after: now) == 4)
    #expect(policy.nextDelay(after: now) == 4)
    #expect(policy.nextDelay(after: now) == nil)
}

@Test("A stable ready period resets the listener retry budget")
func stableReadyPeriodResetsBudget() {
    var policy = RemoteListenerRestartPolicy(
        maximumAttempts: 2,
        initialDelay: 1,
        maximumDelay: 8,
        stableResetInterval: 30
    )
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    #expect(policy.nextDelay(after: start) == 1)
    #expect(policy.nextDelay(after: start) == 2)
    #expect(policy.nextDelay(after: start) == nil)

    policy.markReady(at: start)
    #expect(policy.nextDelay(after: start.addingTimeInterval(31)) == 1)
    #expect(policy.attempt == 1)
}

@Test("A brief ready state does not hide a flapping listener")
func briefReadyStateKeepsFailureHistory() {
    var policy = RemoteListenerRestartPolicy(
        maximumAttempts: 3,
        initialDelay: 1,
        maximumDelay: 8,
        stableResetInterval: 30
    )
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    #expect(policy.nextDelay(after: start) == 1)
    policy.markReady(at: start)
    #expect(policy.nextDelay(after: start.addingTimeInterval(5)) == 2)
}

@Test("Reset clears listener retry state")
func manualResetClearsListenerRetryState() {
    var policy = RemoteListenerRestartPolicy(maximumAttempts: 2)
    _ = policy.nextDelay()
    policy.markReady()

    policy.reset()

    #expect(policy.attempt == 0)
    #expect(policy.readySince == nil)
}
