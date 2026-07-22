#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match in {path}, found {count}")
    path.write_text(source.replace(old, new, 1), encoding="utf-8")


def insert_before(path: Path, marker: str, addition: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    count = source.count(marker)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one marker in {path}, found {count}")
    path.write_text(source.replace(marker, addition + marker, 1), encoding="utf-8")


identity_path = ROOT / "Sources/MixPilotSystem/MixPilotCloudIdentity.swift"
identity_path.write_text(r'''#if os(macOS)
import Foundation

public struct MixPilotCloudAccount: Equatable, Sendable {
    public let userID: UUID
    public let email: String?

    public init(userID: UUID, email: String?) {
        self.userID = userID
        self.email = email
    }
}

public enum MixPilotCloudIdentityState: Equatable, Sendable {
    case checking
    case signedOut
    case linkSent(email: String)
    case signedIn(MixPilotCloudAccount)
    case failed(message: String)

    public var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }
}

public enum MixPilotCloudIdentityError: Error, LocalizedError, Equatable {
    case signedOut
    case invalidEmail
    case invalidCallback
    case callbackRejected(String)

    public var errorDescription: String? {
        switch self {
        case .signedOut:
            "Connecte ton compte MixPilot pour utiliser les services en ligne facultatifs."
        case .invalidEmail:
            "Entre une adresse e-mail valide."
        case .invalidCallback:
            "Ce lien de connexion ne correspond pas à MixPilot."
        case .callbackRejected:
            "Le lien de connexion n’a pas pu être validé. Demande un nouveau lien."
        }
    }
}

public enum MixPilotCloudIdentityPolicy {
    public static let callbackURL: URL = {
        var components = URLComponents()
        components.scheme = "mixpilot-autopilot"
        components.host = "auth"
        components.path = "/callback"
        return components.url ?? URL(fileURLWithPath: "/invalid-mixpilot-auth-callback")
    }()

    public static func normalizedEmail(_ rawValue: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.count <= 254,
              let at = value.lastIndex(of: "@"),
              at != value.startIndex,
              value.index(after: at) < value.endIndex,
              value[value.index(after: at)...].contains("."),
              !value.contains(where: { $0.isWhitespace }) else {
            throw MixPilotCloudIdentityError.invalidEmail
        }
        return value
    }

    public static func acceptsCallback(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == callbackURL.scheme?.lowercased(),
              url.host?.lowercased() == callbackURL.host?.lowercased(),
              url.path == callbackURL.path,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return false
        }
        let codes = items.filter { $0.name == "code" }
        guard codes.count == 1, !(codes[0].value ?? "").isEmpty else { return false }
        return !items.contains { $0.name == "error" }
    }
}
#endif
''', encoding="utf-8")

account_view_path = ROOT / "Sources/MixPilotApp/MixPilotCloudAccountView.swift"
account_view_path.write_text(r'''#if os(macOS)
import MixPilotSystem
import SwiftUI

struct MixPilotCloudAccountView: View {
    @ObservedObject var cloud: MixPilotCloudCoordinator
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Compte MixPilot", systemImage: "person.crop.circle.badge.checkmark")
                .font(.title2.bold())

            Text("Le compte sert uniquement aux mises à jour, correctifs de compatibilité et diagnostics facultatifs. Le Live reste entièrement local.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            switch cloud.identityState {
            case .checking:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Vérification de la session…")
                }

            case .signedOut:
                signInForm

            case .linkSent(let address):
                Label("Lien envoyé à \(address)", systemImage: "envelope.badge")
                    .font(.headline)
                Text("Ouvre le message sur ce Mac puis clique sur le lien. MixPilot terminera la connexion automatiquement.")
                    .foregroundStyle(.secondary)
                Button("Envoyer un nouveau lien") {
                    email = address
                    cloud.requestMagicLink(email: email)
                }

            case .signedIn(let account):
                Label("Compte connecté", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text(account.email ?? account.userID.uuidString)
                    .textSelection(.enabled)
                Button("Se déconnecter", role: .destructive) {
                    cloud.signOut()
                }

            case .failed(let message):
                Label("Connexion non terminée", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(message)
                    .foregroundStyle(.secondary)
                signInForm
            }

            Spacer()

            Text("Le lien de connexion utilise PKCE et la session est conservée dans le Trousseau macOS par le SDK Supabase.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
        .onAppear { cloud.refreshIdentity() }
    }

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connexion par e-mail")
                .font(.headline)
            TextField("lucas@exemple.com", text: $email)
                .textContentType(.emailAddress)
                .disableAutocorrection(true)
                .onSubmit { cloud.requestMagicLink(email: email) }
            Button("M’envoyer un lien de connexion") {
                cloud.requestMagicLink(email: email)
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
#endif
''', encoding="utf-8")

# Main cloud service: share one persistent PKCE session and never create anonymous users.
service = ROOT / "Sources/MixPilotSystem/MixPilotCloudService.swift"
replace_once(
    service,
    '    public static let updateChannel = "stable"\n',
    '    public static let updateChannel = "stable"\n    public static let authenticationStorageKey = "mixpilot.cloud.auth.v1"\n',
    "cloud auth storage key",
)
replace_once(
    service,
    '    private var anonymousAuthenticationUnavailable = false\n',
    '',
    "remove anonymous cloud flag",
)
replace_once(
    service,
    '''    ) {
        self.supabase = supabase ?? SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.publishableKey
        )
        self.urlSession = urlSession ?? URLSession(configuration: .ephemeral)
''',
    '''    ) {
        let resolvedSession = urlSession ?? URLSession(configuration: .ephemeral)
        self.urlSession = resolvedSession
        self.supabase = supabase ?? SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: MixPilotCloudIdentityPolicy.callbackURL,
                    storageKey: Self.authenticationStorageKey,
                    flowType: .pkce,
                    emitLocalSessionAsInitialSession: true
                ),
                global: .init(session: resolvedSession)
            )
        )
''',
    "configure cloud PKCE client",
)
insert_before(
    service,
    '    @discardableResult\n    public func connect(',
    '''    public func accountIfAvailable() async throws -> MixPilotCloudAccount? {
        guard supabase.auth.currentSession != nil else { return nil }
        let session = try await authenticatedSession()
        return MixPilotCloudAccount(userID: session.user.id, email: session.user.email)
    }

    public func requestMagicLink(email rawEmail: String) async throws -> String {
        let email = try MixPilotCloudIdentityPolicy.normalizedEmail(rawEmail)
        try await supabase.auth.signInWithOTP(
            email: email,
            redirectTo: MixPilotCloudIdentityPolicy.callbackURL,
            shouldCreateUser: true
        )
        return email
    }

    @discardableResult
    public func handleAuthenticationCallback(_ url: URL) async throws -> MixPilotCloudAccount {
        guard MixPilotCloudIdentityPolicy.acceptsCallback(url) else {
            throw MixPilotCloudIdentityError.invalidCallback
        }
        do {
            let session = try await supabase.auth.session(from: url)
            resetCloudContext()
            return MixPilotCloudAccount(userID: session.user.id, email: session.user.email)
        } catch {
            throw MixPilotCloudIdentityError.callbackRejected(String(describing: type(of: error)))
        }
    }

    public func signOut() async throws {
        await closeSession()
        try await supabase.auth.signOut()
        resetCloudContext()
    }

''',
    "insert explicit cloud identity API",
)
replace_once(
    service,
    '''        self.sessionID = nil
    }

    private func authenticatedSession() async throws -> Session {
        do {
            let session = try await supabase.auth.session
            if session.isExpired {
                return try await supabase.auth.refreshSession()
            }
            return session
        } catch {
            guard !anonymousAuthenticationUnavailable else {
                throw MixPilotCloudError.authenticationUnavailable
            }
            do {
                return try await supabase.auth.signInAnonymously()
            } catch {
                if (error as? AuthError)?.errorCode == .anonymousProviderDisabled {
                    anonymousAuthenticationUnavailable = true
                    throw MixPilotCloudError.authenticationUnavailable
                }
                throw error
            }
        }
    }
''',
    '''        resetCloudContext()
    }

    private func authenticatedSession() async throws -> Session {
        guard supabase.auth.currentSession != nil else {
            throw MixPilotCloudIdentityError.signedOut
        }
        let session = try await supabase.auth.session
        if session.isExpired {
            return try await supabase.auth.refreshSession()
        }
        return session
    }

    private func resetCloudContext() {
        ownerID = nil
        deviceID = nil
        sessionID = nil
    }
''',
    "replace anonymous cloud authentication",
)

# Mapping service must read the same persistent account and fail closed when signed out.
mapping = ROOT / "Sources/MixPilotSystem/MixPilotRemoteMappingService.swift"
replace_once(
    mapping,
    '    private var anonymousAuthenticationUnavailable = false\n',
    '',
    "remove anonymous mapping flag",
)
replace_once(
    mapping,
    '''        supabase = SupabaseClient(
            supabaseURL: MixPilotCloudService.projectURL,
            supabaseKey: MixPilotCloudService.publishableKey
        )
''',
    '''        supabase = SupabaseClient(
            supabaseURL: MixPilotCloudService.projectURL,
            supabaseKey: MixPilotCloudService.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: MixPilotCloudIdentityPolicy.callbackURL,
                    storageKey: MixPilotCloudService.authenticationStorageKey,
                    flowType: .pkce,
                    emitLocalSessionAsInitialSession: true
                ),
                global: .init(session: urlSession)
            )
        )
''',
    "configure mapping PKCE client",
)
replace_once(
    mapping,
    '''    private func authenticatedSession() async throws -> Session {
        do {
            let session = try await supabase.auth.session
            if session.isExpired {
                return try await supabase.auth.refreshSession()
            }
            return session
        } catch {
            guard !anonymousAuthenticationUnavailable else {
                throw MixPilotCloudError.authenticationUnavailable
            }
            do {
                return try await supabase.auth.signInAnonymously()
            } catch {
                if (error as? AuthError)?.errorCode == .anonymousProviderDisabled {
                    anonymousAuthenticationUnavailable = true
                    throw MixPilotCloudError.authenticationUnavailable
                }
                throw error
            }
        }
    }
''',
    '''    private func authenticatedSession() async throws -> Session {
        guard supabase.auth.currentSession != nil else {
            throw MixPilotCloudIdentityError.signedOut
        }
        let session = try await supabase.auth.session
        if session.isExpired {
            return try await supabase.auth.refreshSession()
        }
        return session
    }
''',
    "replace anonymous mapping authentication",
)

# Coordinator: explicit identity state, user actions and fail-closed online loop.
coordinator = ROOT / "Sources/MixPilotApp/MixPilotCloudCoordinator.swift"
replace_once(
    coordinator,
    '    @Published private(set) var connectionState: MixPilotCloudConnectionState = .idle\n',
    '    @Published private(set) var connectionState: MixPilotCloudConnectionState = .idle\n    @Published private(set) var identityState: MixPilotCloudIdentityState = .checking\n',
    "publish identity state",
)
replace_once(
    coordinator,
    '''            if !value {
                _ = await refreshRemoteCompatibility(showNoUpdateMessage: false)
            }
''',
    '''            if !value, identityState.isSignedIn {
                _ = await refreshRemoteCompatibility(showNoUpdateMessage: false)
            }
''',
    "guard compatibility refresh by identity",
)
insert_before(
    coordinator,
    '    func checkNow() {\n',
    '''    func refreshIdentity() {
        Task { [weak self] in
            guard let self else { return }
            await updateIdentityFromStoredSession()
        }
    }

    func requestMagicLink(email: String) {
        identityState = .checking
        statusDetail = "Envoi du lien de connexion…"
        Task { [weak self] in
            guard let self else { return }
            do {
                let normalized = try await service.requestMagicLink(email: email)
                identityState = .linkSent(email: normalized)
                statusDetail = "Un lien de connexion a été envoyé à \(normalized). Ouvre-le sur ce Mac."
            } catch {
                let message = humanIdentityMessage(error)
                identityState = .failed(message: message)
                statusDetail = message
            }
        }
    }

    func handleAuthenticationCallback(_ url: URL) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let account = try await service.handleAuthenticationCallback(url)
                identityState = .signedIn(account)
                statusDetail = account.email.map { "Compte connecté • \($0)" } ?? "Compte MixPilot connecté."
                restartLoopAfterIdentityChange()
            } catch {
                let message = humanIdentityMessage(error)
                identityState = .failed(message: message)
                statusDetail = message
            }
        }
    }

    func signOut() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await service.signOut()
            } catch {
                // Local session cleanup remains the priority; server logout is best-effort.
            }
            identityState = .signedOut
            connectionState = .idle
            statusDetail = "Compte déconnecté • le Live local reste disponible."
            availableUpdate = nil
            availableMapping = nil
            activeCompatibilityOverride = nil
            lastHeartbeatAt = nil
            restartLoopAfterIdentityChange()
        }
    }

''',
    "insert coordinator identity actions",
)
replace_once(
    coordinator,
    '''    func checkNow() {
        Task { [weak self] in
''',
    '''    func checkNow() {
        guard identityState.isSignedIn else {
            statusDetail = "Connecte ton compte MixPilot pour vérifier les mises à jour en ligne."
            return
        }
        Task { [weak self] in
''',
    "guard check now",
)
insert_before(
    coordinator,
    '    private func runLoop() async {\n',
    '''    private func updateIdentityFromStoredSession() async {
        do {
            if let account = try await service.accountIfAvailable() {
                identityState = .signedIn(account)
            } else if case .linkSent = identityState {
                // Preserve the useful confirmation while the user opens the e-mail.
            } else {
                identityState = .signedOut
            }
        } catch {
            identityState = .failed(message: humanIdentityMessage(error))
        }
    }

    private func restartLoopAfterIdentityChange() {
        loopTask?.cancel()
        loopTask = nil
        heartbeatCounter = 0
        start(liveMode: liveMode)
    }

''',
    "insert identity loop helpers",
)
replace_once(
    coordinator,
    '''            do {
                let backend = await backendContextProvider()
''',
    '''            do {
                guard let account = try await service.accountIfAvailable() else {
                    if case .linkSent = identityState {
                        // Keep the confirmation while the callback is pending.
                    } else {
                        identityState = .signedOut
                    }
                    connectionState = .idle
                    statusDetail = "Connecte ton compte MixPilot pour activer les services en ligne facultatifs."
                    try await Task.sleep(for: .seconds(30))
                    continue
                }
                identityState = .signedIn(account)
                let backend = await backendContextProvider()
''',
    "gate cloud loop by account",
)
replace_once(
    coordinator,
    '''            } catch is CancellationError {
                break
            } catch MixPilotCloudError.authenticationUnavailable {
''',
    '''            } catch is CancellationError {
                break
            } catch let error as MixPilotCloudIdentityError where error == .signedOut {
                identityState = .signedOut
                connectionState = .idle
                statusDetail = error.localizedDescription
                connected = false
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    break
                }
            } catch MixPilotCloudError.authenticationUnavailable {
''',
    "handle signed-out loop state",
)
replace_once(
    coordinator,
    '''    private func checkForUpdate(showNoUpdateMessage: Bool) async -> Bool {
        do {
''',
    '''    private func checkForUpdate(showNoUpdateMessage: Bool) async -> Bool {
        guard identityState.isSignedIn else { return false }
        do {
''',
    "guard update checks",
)
replace_once(
    coordinator,
    '''    private func refreshRemoteCompatibility(showNoUpdateMessage: Bool) async -> Bool {
        guard let backend = await backendContextProvider() else {
''',
    '''    private func refreshRemoteCompatibility(showNoUpdateMessage: Bool) async -> Bool {
        guard identityState.isSignedIn else { return false }
        guard let backend = await backendContextProvider() else {
''',
    "guard mapping refresh",
)
replace_once(
    coordinator,
    '''    private func processRemoteCommands() async {
        do {
''',
    '''    private func processRemoteCommands() async {
        guard identityState.isSignedIn else { return }
        do {
''',
    "guard remote commands",
)
insert_before(
    coordinator,
    '    private func humanCloudError(_ error: Error) -> String {\n',
    '''    private func humanIdentityMessage(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let message = localized.errorDescription,
           !message.isEmpty {
            return message
        }
        return "La connexion au compte MixPilot n’a pas pu être terminée. Le Live local reste disponible."
    }

''',
    "insert human identity message",
)

# App scene: callback, account window and discoverable commands.
app = ROOT / "Sources/MixPilotApp/MixPilotApp.swift"
replace_once(
    app,
    '''                    cloud.start(liveMode: model.isLiveRunning)
                }
                .onChange(of: model.isLiveRunning) { _, isLiveRunning in
''',
    '''                    cloud.start(liveMode: model.isLiveRunning)
                }
                .onOpenURL { url in
                    cloud.handleAuthenticationCallback(url)
                }
                .onChange(of: model.isLiveRunning) { _, isLiveRunning in
''',
    "register cloud callback handler",
)
insert_before(
    app,
    '        Window("Choisir le logiciel DJ", id: "dj-software") {\n',
    '''        Window("Compte MixPilot", id: "cloud-account") {
            MixPilotCloudAccountView(cloud: cloud)
        }
        .defaultSize(width: 560, height: 420)

''',
    "add cloud account window",
)
replace_once(
    app,
    '''                Button("Vérifier les mises à jour") {
                    cloud.checkNow()
                }
''',
    '''                Button("Compte MixPilot") {
                    NSApp.sendAction(#selector(MixPilotAccountWindowAction.openAccountWindow), to: nil, from: nil)
                }

                Button("Vérifier les mises à jour") {
                    cloud.checkNow()
                }
''',
    "add account command menu action",
)
replace_once(
    app,
    '''            Button("Préparer un set rapidement") {
                openWindow(id: "quick-set")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
''',
    '''            Button("Préparer un set rapidement") {
                openWindow(id: "quick-set")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("Compte MixPilot") {
                openWindow(id: "cloud-account")
            }
            .keyboardShortcut(",", modifiers: [.command, .option])
''',
    "add account window command",
)
# Avoid an AppKit responder indirection: the primary menu already receives openWindow through commands.
source = app.read_text(encoding="utf-8")
source = source.replace(
    '''                Button("Compte MixPilot") {
                    NSApp.sendAction(#selector(MixPilotAccountWindowAction.openAccountWindow), to: nil, from: nil)
                }

''',
    '',
    1,
)
app.write_text(source, encoding="utf-8")

# Packaging: register both Spotify and account callbacks and validate both.
build = ROOT / "Scripts/build_release.sh"
replace_once(
    build,
    '''    </dict>
  </array>
  <key>NSHumanReadableCopyright</key>''',
    '''    </dict>
    <dict>
      <key>CFBundleURLName</key><string>com.mixpilot.autopilot.auth</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>mixpilot-autopilot</string>
      </array>
    </dict>
  </array>
  <key>NSHumanReadableCopyright</key>''',
    "register account callback scheme",
)
replace_once(
    build,
    '''if [[ "$registered_spotify_scheme" != "mixpilot-spotify" ]]; then
  echo "Spotify OAuth callback scheme is missing from the packaged application." >&2
  exit 1
fi
''',
    '''if [[ "$registered_spotify_scheme" != "mixpilot-spotify" ]]; then
  echo "Spotify OAuth callback scheme is missing from the packaged application." >&2
  exit 1
fi
registered_account_scheme="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:1:CFBundleURLSchemes:0' "$APP_DIR/Contents/Info.plist")"
if [[ "$registered_account_scheme" != "mixpilot-autopilot" ]]; then
  echo "MixPilot account callback scheme is missing from the packaged application." >&2
  exit 1
fi
''',
    "validate account callback scheme",
)

# Regression tests.
test_path = ROOT / "Tests/MixPilotSystemTests/CloudIdentityTests.swift"
test_path.write_text(r'''#if os(macOS)
import Foundation
@testable import MixPilotSystem
import XCTest

final class CloudIdentityTests: XCTestCase {
    func testEmailNormalizationIsExplicitAndBounded() throws {
        XCTAssertEqual(
            try MixPilotCloudIdentityPolicy.normalizedEmail("  Lucas@Example.COM "),
            "lucas@example.com"
        )
        XCTAssertThrowsError(try MixPilotCloudIdentityPolicy.normalizedEmail("lucas"))
        XCTAssertThrowsError(try MixPilotCloudIdentityPolicy.normalizedEmail("@example.com"))
        XCTAssertThrowsError(try MixPilotCloudIdentityPolicy.normalizedEmail("lucas@localhost"))
        XCTAssertThrowsError(try MixPilotCloudIdentityPolicy.normalizedEmail("lucas @example.com"))
    }

    func testOnlyOneValidMixPilotPKCECodeIsAccepted() throws {
        XCTAssertTrue(MixPilotCloudIdentityPolicy.acceptsCallback(
            try XCTUnwrap(URL(string: "mixpilot-autopilot://auth/callback?code=abc123"))
        ))
        XCTAssertFalse(MixPilotCloudIdentityPolicy.acceptsCallback(
            try XCTUnwrap(URL(string: "mixpilot-autopilot://auth/callback"))
        ))
        XCTAssertFalse(MixPilotCloudIdentityPolicy.acceptsCallback(
            try XCTUnwrap(URL(string: "mixpilot-autopilot://auth/callback?code=a&code=b"))
        ))
        XCTAssertFalse(MixPilotCloudIdentityPolicy.acceptsCallback(
            try XCTUnwrap(URL(string: "mixpilot-autopilot://evil/callback?code=abc123"))
        ))
        XCTAssertFalse(MixPilotCloudIdentityPolicy.acceptsCallback(
            try XCTUnwrap(URL(string: "https://auth/callback?code=abc123"))
        ))
    }

    func testCloudSourcesNeverAttemptAnonymousSignup() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let paths = [
            "Sources/MixPilotSystem/MixPilotCloudService.swift",
            "Sources/MixPilotSystem/MixPilotRemoteMappingService.swift"
        ]
        for path in paths {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertFalse(source.contains("signInAnonymously"), "Anonymous auth returned in \(path)")
            XCTAssertTrue(source.contains("MixPilotCloudIdentityError.signedOut"))
        }
    }

    func testPackagedAppRegistersBothAuthenticationSchemes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let script = try String(
            contentsOf: root.appendingPathComponent("Scripts/build_release.sh"),
            encoding: .utf8
        )
        XCTAssertTrue(script.contains("mixpilot-spotify"))
        XCTAssertTrue(script.contains("mixpilot-autopilot"))
    }
}
#endif
''', encoding="utf-8")

# Final source contracts before compilation.
for file_path in (service, mapping):
    source = file_path.read_text(encoding="utf-8")
    if "signInAnonymously" in source:
        raise SystemExit(f"anonymous authentication remains in {file_path}")
    if "MixPilotCloudIdentityError.signedOut" not in source:
        raise SystemExit(f"signed-out boundary missing in {file_path}")

for needle, file_path in (
    ("mixpilot-autopilot", build),
    ("cloud.handleAuthenticationCallback(url)", app),
    ("MixPilotCloudAccountView", app),
    ("identityState", coordinator),
):
    if needle not in file_path.read_text(encoding="utf-8"):
        raise SystemExit(f"missing explicit identity contract {needle} in {file_path}")
