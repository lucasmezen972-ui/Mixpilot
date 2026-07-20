#if os(macOS)
import Foundation
import XCTest

final class SpotifyAuthenticationPresentationTests: XCTestCase {
    func testPresentationAnchorMarshalsToMainQueueBeforeAssumingMainActor() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = root.appendingPathComponent(
            "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("if Thread.isMainThread"))
        XCTAssertTrue(source.contains("DispatchQueue.main.sync"))
        XCTAssertTrue(source.contains("MainActor.assumeIsolated"))
        XCTAssertFalse(source.contains(
            "-> ASPresentationAnchor {\n        MainActor.assumeIsolated"
        ))
    }
}
#endif
