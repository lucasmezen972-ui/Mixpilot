import Foundation

public struct BoundedBackoffPolicy: Sendable, Hashable {
    public let limit: Int
    public let firstDelay: TimeInterval
    public let maximumDelay: TimeInterval
    public private(set) var count: Int

    public init(limit: Int = 4, firstDelay: TimeInterval = 0.25, maximumDelay: TimeInterval = 4, count: Int = 0) {
        self.limit = max(1, limit)
        self.firstDelay = max(0.05, firstDelay)
        self.maximumDelay = max(self.firstDelay, maximumDelay)
        self.count = max(0, count)
    }

    public mutating func nextDelay() -> TimeInterval? {
        guard count < limit else { return nil }
        let value = min(maximumDelay, firstDelay * pow(2, Double(min(count, 30))))
        count += 1
        return value
    }

    public mutating func reset() {
        count = 0
    }
}
