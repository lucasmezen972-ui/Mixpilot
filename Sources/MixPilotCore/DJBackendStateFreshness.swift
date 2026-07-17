import Foundation

public extension DJBackendState {
    func isReliableAndFresh(
        at now: Date = Date(),
        maximumAge: TimeInterval
    ) -> Bool {
        guard isReliable else { return false }
        let age = now.timeIntervalSince(observedAt)
        return age >= 0 && age <= max(0, maximumAge)
    }
}
