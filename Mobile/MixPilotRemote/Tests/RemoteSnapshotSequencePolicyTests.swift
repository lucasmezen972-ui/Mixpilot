import XCTest

final class RemoteSnapshotSequencePolicyTests: XCTestCase {
    func testStaleAndDuplicateSnapshotsAreRejected() {
        var policy = RemoteSnapshotSequencePolicy()
        XCTAssertTrue(policy.shouldAccept(sequence: 42, endpointID: "mac-a"))
        XCTAssertFalse(policy.shouldAccept(sequence: 42, endpointID: "mac-a"))
        XCTAssertFalse(policy.shouldAccept(sequence: 41, endpointID: "mac-a"))
        XCTAssertTrue(policy.shouldAccept(sequence: 43, endpointID: "mac-a"))
    }

    func testReconnectKeepsLastSequenceForSameMac() {
        var policy = RemoteSnapshotSequencePolicy()
        XCTAssertTrue(policy.shouldAccept(sequence: 12, endpointID: "mac-a"))
        XCTAssertEqual(policy.lastSequence(for: "mac-a"), 12)

        XCTAssertFalse(policy.shouldAccept(sequence: 10, endpointID: "mac-a"))
        XCTAssertTrue(policy.shouldAccept(sequence: 1, endpointID: "mac-b"))
        XCTAssertEqual(policy.lastSequence(for: "mac-a"), 12)
        XCTAssertEqual(policy.lastSequence(for: "mac-b"), 1)
    }
}
