import Foundation

/// Tracks temporary losses of trustworthy deck state during a Live.
///
/// A single missed observation can be caused by a transient Accessibility or
/// scheduling delay. Repeated misses mean MixPilot can no longer reconcile its
/// plan with the DJ software and must hand control back at the next safe point.
public struct LiveStateReliabilityTracker: Sendable, Hashable {
    public let failureThreshold: Int
    public private(set) var consecutiveFailures: Int

    public init(failureThreshold: Int = 2, consecutiveFailures: Int = 0) {
        self.failureThreshold = max(1, failureThreshold)
        self.consecutiveFailures = max(0, consecutiveFailures)
    }

    /// Records the latest observation and returns `true` when automatic control
    /// must stop because the state has remained unreliable for too long.
    @discardableResult
    public mutating func record(isReliable: Bool) -> Bool {
        if isReliable {
            consecutiveFailures = 0
            return false
        }

        consecutiveFailures += 1
        return consecutiveFailures >= failureThreshold
    }
}
