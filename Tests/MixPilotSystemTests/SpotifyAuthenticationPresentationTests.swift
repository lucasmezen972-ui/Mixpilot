#if os(macOS)
import Foundation
import XCTest

final class SpotifyAuthenticationPresentationTests: XCTestCase {
    func testPresentationContextAvoidsRuntimeActorAssumptions() throws {
        let source = try repositoryFile(
            "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift"
        )

        XCTAssertTrue(source.contains(
            "@preconcurrency import AuthenticationServices"
        ))
        XCTAssertTrue(source.contains(
            "private final class SpotifyAuthenticationPresentationContext"
        ))
        XCTAssertTrue(source.contains(
            "private var webAuthenticationPresentationContext: SpotifyAuthenticationPresentationContext?"
        ))
        XCTAssertTrue(source.contains(
            "session.presentationContextProvider = presentationContext"
        ))
        XCTAssertTrue(source.contains(
            "webAuthenticationPresentationContext = presentationContext"
        ))
        XCTAssertTrue(source.contains("NSApp.keyWindow"))
        XCTAssertTrue(source.contains("NSApp.mainWindow"))
        XCTAssertTrue(source.contains(
            "nonisolated(unsafe) private let anchor: ASPresentationAnchor"
        ))
        XCTAssertTrue(source.contains(
            "nonisolated func presentationAnchor("
        ))
        XCTAssertTrue(source.contains(
            "SAFETY: The presentation anchor is captured once on the MainActor"
        ))
        XCTAssertFalse(source.contains("MainActor.assumeIsolated"))
        XCTAssertFalse(source.contains("DispatchQueue.main.sync"))
        XCTAssertFalse(source.contains(
            "extension SpotifyLibraryCoordinator: ASWebAuthenticationPresentationContextProviding"
        ))
    }

    func testOAuthCallbackParsingRejectsDuplicateParametersWithoutDictionaryTrap() throws {
        let source = try repositoryFile(
            "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift"
        )

        XCTAssertTrue(source.contains("struct SpotifyAuthorizationCallback"))
        XCTAssertTrue(source.contains("guard values[item.name] == nil"))
        XCTAssertTrue(source.contains("clearPendingAuthorization()"))
        XCTAssertFalse(source.contains("Dictionary(uniqueKeysWithValues:"))
        XCTAssertFalse(source.contains("URL(string: \"mixpilot-spotify://callback\")!"))
    }

    func testReleaseBundleRegistersSpotifyCallbackScheme() throws {
        let script = try repositoryFile("Scripts/build_release.sh")

        XCTAssertTrue(script.contains("CFBundleURLTypes"))
        XCTAssertTrue(script.contains("CFBundleURLSchemes"))
        XCTAssertTrue(script.contains("mixpilot-spotify"))
        XCTAssertTrue(script.contains("plutil -lint"))
        XCTAssertTrue(script.contains("PlistBuddy"))
    }

    func testReleaseRequiresBothIndependentAudits() throws {
        let buildScript = try repositoryFile("Scripts/build_release.sh")
        let packageScript = try repositoryFile("Scripts/package_dmg.sh")

        for script in [buildScript, packageScript] {
            XCTAssertTrue(script.contains("ultimate_repository_audit.py"))
            XCTAssertTrue(script.contains("architecture_counter_audit.py"))
            XCTAssertTrue(script.contains("git_head"))
        }
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
