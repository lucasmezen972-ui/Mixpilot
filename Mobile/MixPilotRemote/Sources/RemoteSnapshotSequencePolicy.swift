import Foundation

struct RemoteSnapshotSequencePolicy: Sendable {
    private(set) var lastSequenceByEndpoint: [String: Int] = [:]

    mutating func shouldAccept(sequence: Int, endpointID: String) -> Bool {
        let previous = lastSequenceByEndpoint[endpointID]
        guard previous == nil || sequence > previous! else { return false }
        lastSequenceByEndpoint[endpointID] = sequence
        return true
    }

    func lastSequence(for endpointID: String) -> Int? {
        lastSequenceByEndpoint[endpointID]
    }

    mutating func reset(endpointID: String) {
        lastSequenceByEndpoint.removeValue(forKey: endpointID)
    }
}
