#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = ROOT / "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift"
TEST_PATH = ROOT / "Tests/MixPilotSystemTests/SpotifyAuthenticationPresentationTests.swift"


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return source.replace(old, new, 1)


def main() -> None:
    source = SOURCE_PATH.read_text(encoding="utf-8")
    if "SpotifyWebAuthenticationSessionFactory.makeSession(" in source:
        print("Spotify callback actor fix is already applied.")
        return

    source = replace_once(
        source,
        """    private var webAuthenticationSession: ASWebAuthenticationSession?\n    private var webAuthenticationPresentationContext: SpotifyAuthenticationPresentationContext?\n    private var refreshTask: Task<SpotifyStoredSession, Error>?\n""",
        """    private var webAuthenticationSession: ASWebAuthenticationSession?\n    private var webAuthenticationPresentationContext: SpotifyAuthenticationPresentationContext?\n    private var webAuthenticationCallbackRelay: SpotifyAuthenticationCallbackRelay?\n    private var webAuthenticationSessionID: UUID?\n    private var refreshTask: Task<SpotifyStoredSession, Error>?\n""",
        "authentication session storage",
    )

    source = replace_once(
        source,
        """            let session = ASWebAuthenticationSession(\n                url: authorizationURL,\n                callbackURLScheme: Self.callbackURL.scheme\n            ) { [weak self] callbackURL, error in\n                Task { @MainActor [weak self] in\n                    guard let self else { return }\n                    self.webAuthenticationSession = nil\n                    self.webAuthenticationPresentationContext = nil\n\n                    if error != nil {\n                        self.clearPendingAuthorization()\n                        self.present(SpotifyBridgeError.authorizationCancelled)\n                        return\n                    }\n                    guard let callbackURL else {\n                        self.clearPendingAuthorization()\n                        self.present(SpotifyBridgeError.invalidCallback)\n                        return\n                    }\n                    await self.completeAuthorization(callbackURL)\n                }\n            }\n""",
        """            let sessionID = UUID()\n            let callbackRelay = SpotifyAuthenticationCallbackRelay(\n                sessionID: sessionID,\n                coordinator: self\n            )\n            let session = SpotifyWebAuthenticationSessionFactory.makeSession(\n                url: authorizationURL,\n                callbackURLScheme: Self.callbackURL.scheme,\n                relay: callbackRelay\n            )\n""",
        "main-actor authentication callback",
    )

    source = replace_once(
        source,
        """            webAuthenticationPresentationContext = presentationContext\n            webAuthenticationSession = session\n\n            guard session.start() else {\n""",
        """            webAuthenticationPresentationContext = presentationContext\n            webAuthenticationCallbackRelay = callbackRelay\n            webAuthenticationSessionID = sessionID\n            webAuthenticationSession = session\n\n            guard session.start() else {\n""",
        "authentication session retention",
    )

    source = replace_once(
        source,
        """    func disconnect() {\n""",
        """    fileprivate func handleAuthenticationCallback(\n        _ result: SpotifyAuthenticationCallbackResult,\n        sessionID: UUID\n    ) async {\n        guard webAuthenticationSessionID == sessionID else { return }\n\n        webAuthenticationSession = nil\n        webAuthenticationPresentationContext = nil\n        webAuthenticationCallbackRelay = nil\n        webAuthenticationSessionID = nil\n\n        switch result {\n        case let .success(callbackURL):\n            await completeAuthorization(callbackURL)\n        case .cancelled:\n            clearPendingAuthorization()\n            present(SpotifyBridgeError.authorizationCancelled)\n        case .invalidCallback:\n            clearPendingAuthorization()\n            present(SpotifyBridgeError.invalidCallback)\n        }\n    }\n\n    func disconnect() {\n""",
        "main-actor callback receiver",
    )

    source = replace_once(
        source,
        """    private func cancelAuthorizationSession() {\n        webAuthenticationSession?.cancel()\n        webAuthenticationSession = nil\n        webAuthenticationPresentationContext = nil\n    }\n""",
        """    private func cancelAuthorizationSession() {\n        webAuthenticationSession?.cancel()\n        webAuthenticationSession = nil\n        webAuthenticationPresentationContext = nil\n        webAuthenticationCallbackRelay = nil\n        webAuthenticationSessionID = nil\n    }\n""",
        "authorization cancellation cleanup",
    )

    source = replace_once(
        source,
        "// SAFETY: The presentation anchor is captured once on the MainActor, remains\n",
        """fileprivate enum SpotifyAuthenticationCallbackResult: Sendable {\n    case success(URL)\n    case cancelled\n    case invalidCallback\n}\n\nprivate final class SpotifyAuthenticationCallbackRelay: @unchecked Sendable {\n    private let sessionID: UUID\n    private weak var coordinator: SpotifyLibraryCoordinator?\n\n    init(sessionID: UUID, coordinator: SpotifyLibraryCoordinator) {\n        self.sessionID = sessionID\n        self.coordinator = coordinator\n    }\n\n    func receive(callbackURL: URL?, error: Error?) {\n        let result: SpotifyAuthenticationCallbackResult\n        if error != nil {\n            result = .cancelled\n        } else if let callbackURL {\n            result = .success(callbackURL)\n        } else {\n            result = .invalidCallback\n        }\n\n        let sessionID = sessionID\n        let coordinator = coordinator\n        Task { @MainActor [weak coordinator] in\n            await coordinator?.handleAuthenticationCallback(result, sessionID: sessionID)\n        }\n    }\n}\n\nprivate enum SpotifyWebAuthenticationSessionFactory {\n    static func makeSession(\n        url: URL,\n        callbackURLScheme: String?,\n        relay: SpotifyAuthenticationCallbackRelay\n    ) -> ASWebAuthenticationSession {\n        ASWebAuthenticationSession(\n            url: url,\n            callbackURLScheme: callbackURLScheme\n        ) { [relay] callbackURL, error in\n            relay.receive(callbackURL: callbackURL, error: error)\n        }\n    }\n}\n\n// SAFETY: The presentation anchor is captured once on the MainActor, remains\n""",
        "actor-neutral callback relay",
    )

    for forbidden in (
        ") { [weak self] callbackURL, error in",
        "Task { @MainActor [weak self] in",
    ):
        if forbidden in source:
            raise SystemExit(f"unsafe callback pattern remains: {forbidden}")

    SOURCE_PATH.write_text(source, encoding="utf-8")

    tests = TEST_PATH.read_text(encoding="utf-8")
    marker = "    func testOAuthCallbackParsingRejectsDuplicateParametersWithoutDictionaryTrap() throws {"
    actor_test = '''    func testAuthenticationCallbackIsCreatedOutsideTheMainActor() throws {\n        let source = try repositoryFile(\n            "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift"\n        )\n\n        XCTAssertTrue(source.contains("private enum SpotifyWebAuthenticationSessionFactory"))\n        XCTAssertTrue(source.contains("private final class SpotifyAuthenticationCallbackRelay"))\n        XCTAssertTrue(source.contains("SpotifyWebAuthenticationSessionFactory.makeSession("))\n        XCTAssertTrue(source.contains("relay.receive(callbackURL: callbackURL, error: error)"))\n        XCTAssertTrue(source.contains("Task { @MainActor [weak coordinator] in"))\n        XCTAssertTrue(source.contains("guard webAuthenticationSessionID == sessionID else { return }"))\n        XCTAssertFalse(source.contains(") { [weak self] callbackURL, error in"))\n        XCTAssertFalse(source.contains("Task { @MainActor [weak self] in"))\n    }\n\n'''
    if "testAuthenticationCallbackIsCreatedOutsideTheMainActor" not in tests:
        if tests.count(marker) != 1:
            raise SystemExit("Could not locate Spotify authentication test insertion point")
        tests = tests.replace(marker, actor_test + marker, 1)
        TEST_PATH.write_text(tests, encoding="utf-8")

    print("Spotify callback actor fix applied.")


if __name__ == "__main__":
    main()
