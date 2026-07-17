import Foundation

public struct RemoteListenerRestartPolicy: Sendable, Hashable {
    public let maximumAttempts: Int
    public let initialDelay: TimeInterval
    public let maximumDelay: TimeInterval
    public let stableResetInterval: TimeInterval

    public private(set) var attempt: Int
    public private(set) var readySince: Date?

    public init(
        maximumAttempts: Int = 5,
        initialDelay: TimeInterval = 1,
        maximumDelay: TimeInterval = 30,
        stableResetInterval: TimeInterval = 60,
        attempt: Int = 0,
        readySince: Date? = nil
    ) {
        self.maximumAttempts = max(1, maximumAttempts)
        self.initialDelay = max(0.1, initialDelay)
        self.maximumDelay = max(self.initialDelay, maximumDelay)
        self.stableResetInterval = max(1, stableResetInterval)
        self.attempt = max(0, attempt)
        self.readySince = readySince
    }

    public mutating func markReady(at date: Date = Date()) {
        readySince = date
    }

    public mutating func nextDelay(after date: Date = Date()) -> TimeInterval? {
        if let readySince, date.timeIntervalSince(readySince) >= stableResetInterval {
            attempt = 0
        }
        readySince = nil
        guard attempt < maximumAttempts else { return nil }
        let delay = min(maximumDelay, initialDelay * pow(2, Double(min(attempt, 30))))
        attempt += 1
        return delay
    }

    public mutating func reset() {
        attempt = 0
        readySince = nil
    }
}
