#if os(macOS)
import Foundation
import XCTest

final class SpotifyAuthenticationPresentationTests: XCTestCase {
    func testPresentationAnchorUsesMainActorWithoutRuntimeAssumptions() throws {
        let source = try repositoryFile(
            "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift"
        )

        XCTAssertTrue(source.contains(
            "extension SpotifyLibraryCoordinator: ASWebAuthenticationPresentationContextProviding"
        ))
        XCTAssertTrue(source.contains("func presentationAnchor("))
        XCTAssertTrue(source.contains("NSApp.keyWindow"))
        XCTAssertTrue(source.contains("NSApp.mainWindow"))
        XCTAssertFalse(source.contains("nonisolated func presentationAnchor"))
        XCTAssertFalse(source.contains("MainActor.assumeIsolated"))
        XCTAssertFalse(source.contains("DispatchQueue.main.sync"))
    }

    func testReleaseBundleRegistersSpotifyCallbackScheme() throws {
        let script = try repositoryFile("Scripts/build_release.sh")

        XCTAssertTrue(script.contains("CFBundleURLTypes"))
        XCTAssertTrue(script.contains("CFBundleURLSchemes"))
        XCTAssertTrue(script.contains("mixpilot-spotify"))
        XCTAssertTrue(script.contains("plutil -lint"))
        XCTAssertTrue(script.contains("PlistBuddy"))
    }

    private func repositoryFile(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
#endif
