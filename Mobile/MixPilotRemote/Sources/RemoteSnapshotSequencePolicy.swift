import Foundation

struct RemoteSnapshotSequencePolicy: Sendable {
    private(set) var lastSequenceByEndpoint: [String: Int] = [:]

    mutating func shouldAccept(sequence: Int, endpointID: String) -> Bool {
        guard sequence >= 0 else { return false }

        if let previous = lastSequenceByEndpoint[endpointID] {
            if sequence > previous {
                lastSequenceByEndpoint[endpointID] = sequence
                return true
            }

            // WebSocket delivery is ordered inside one connection. Receiving a
            // new stream at sequence 0 or 1 therefore means the Mac bridge was
            // restarted or a fresh session was negotiated, not that an old
            // packet overtook a newer one.
            if sequence <= 1, previous > 1 {
                lastSequenceByEndpoint[endpointID] = sequence
                return true
            }
            return false
        }

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
