#if os(macOS)
import Foundation
import XCTest

final class SpotifyAuthenticationPresentationTests: XCTestCase {
    func testPresentationContextAvoidsRuntimeActorAssumptions() throws {
        let source = try repositoryFile(
            "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift"
        )

        XCTAssertTrue(source.contains(
            "private final class SpotifyAuthenticationPresentationContext"
        ))
        XCTAssertTrue(source.contains(
            "private var webAuthenticationPresentationContext: SpotifyAuthenticationPresentationContext?"
        ))
        XCTAssertTrue(source.contains(
            "session.presentationContextProvider = presentationContext"
        ))
        XCTAssertTrue(source.contains("NSApp.keyWindow"))
        XCTAssertTrue(source.contains("NSApp.mainWindow"))
        XCTAssertFalse(source.contains("MainActor.assumeIsolated"))
        XCTAssertFalse(source.contains("DispatchQueue.main.sync"))
        XCTAssertFalse(source.contains(
            "extension SpotifyLibraryCoordinator: ASWebAuthenticationPresentationContextProviding"
        ))
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
