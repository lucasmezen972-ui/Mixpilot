#if os(macOS)
import AppKit
import AuthenticationServices
import Combine
import Foundation
import MixPilotCore
import MixPilotSystem

@MainActor
enum SpotifyConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case synchronizing
    case failed(String)

    var isConnected: Bool {
        switch self {
        case .connected, .synchronizing:
            true
        case .disconnected, .connecting, .failed:
            false
        }
    }
}

@MainActor
final class SpotifyLibraryCoordinator: NSObject, ObservableObject {
    static let callbackURL = URL(string: "mixpilot-spotify://callback")!

    @Published var connectionState: SpotifyConnectionState = .disconnected
    @Published var accountName: String?
    @Published var accountIdentifier: String?
    @Published var lastSynchronizationAt: Date?
    @Published var playlists: [SpotifyLibraryPlaylist] = []
    @Published var selectedPlaylistID: String?
    @Published var selectedTracks: [SpotifyLibraryTrack] = []
    @Published var statusMessage = "Spotify n’est pas connecté."
    @Published var rekordboxStatus = RekordboxEnvironmentStatus(
        isRunning: false,
        processIdentifier: nil,
        applicationName: nil,
        bundleIdentifier: nil
    )
    @Published var rekordboxWindowObservation: DJWindowObservation?
    @Published var rekordboxLibrarySource: MixPilotSystem.RekordboxLibrarySource?
    @Published var playlistMatch: SpotifyPlaylistMatchResult?
    @Published var visibleRows: [DJLibraryRow] = []

    @Published var clientID: String {
        didSet {
            let normalized = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized != clientID {
                clientID = normalized
                return
            }
            UserDefaults.standard.set(normalized, forKey: Self.clientIDDefaultsKey)
        }
    }

    var selectedPlaylist: SpotifyLibraryPlaylist? {
        playlists.first { $0.id == selectedPlaylistID }
    }

    var matchedPlaylist: SpotifyLibraryPlaylist? {
        guard let id = playlistMatch?.matchedPlaylistID else { return nil }
        return playlists.first { $0.id == id }
    }

    private static let clientIDDefaultsKey = "MixPilotSpotifyClientID"
    private static let manualAssociationsDefaultsKey = "MixPilotSpotifyManualAssociationsV1"
    private static let scopes = [
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-library-read",
    ]

    private let tokenStore = SpotifyTokenStore()
    private let httpClient = SpotifyHTTPClient()
    private let matcher = SpotifyPlaylistMatcher()
    private let selector = SpotifyAutomaticSetSelector()
    private let accessibilityBridge: DJAccessibilityBridge
    private let rekordboxDetector: RekordboxApplicationDetector

    private var webAuthenticationSession: ASWebAuthenticationSession?
    private var webAuthenticationPresentationContext: SpotifyAuthenticationPresentationContext?
    private var refreshTask: Task<SpotifyStoredSession, Error>?
    private var currentSession: SpotifyStoredSession?
    private var pendingState: String?
    private var pendingVerifier: String?

    init(
        accessibilityBridge: DJAccessibilityBridge = DJAccessibilityBridge(),
        rekordboxDetector: RekordboxApplicationDetector = RekordboxApplicationDetector()
    ) {
        self.accessibilityBridge = accessibilityBridge
        self.rekordboxDetector = rekordboxDetector
        let stored = UserDefaults.standard.string(forKey: Self.clientIDDefaultsKey)
            ?? ProcessInfo.processInfo.environment["MIXPILOT_SPOTIFY_CLIENT_ID"]
            ?? ""
        clientID = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        super.init()
    }

    func restoreSession() async {
        guard !clientID.isEmpty,
              let stored = tokenStore.read(clientID: clientID) else {
            connectionState = .disconnected
            return
        }
        currentSession = stored
        connectionState = .connected
        statusMessage = "Session Spotify restaurée depuis le Trousseau macOS."
        do {
            try await synchronizeLibrary()
        } catch {
            present(error)
        }
    }

    func connect() {
        guard !clientID.isEmpty else {
            present(SpotifyBridgeError.missingClientID)
            return
        }
        do {
            let verifier = try SpotifyPKCE.randomURLSafeString(byteCount: 64)
            let state = try SpotifyPKCE.randomURLSafeString(byteCount: 32)
            let challenge = SpotifyPKCE.challenge(for: verifier)
            guard var components = URLComponents(string: "https://accounts.spotify.com/authorize") else {
                throw SpotifyBridgeError.invalidAuthorizationURL
            }
            components.queryItems = [
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "redirect_uri", value: Self.callbackURL.absoluteString),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "scope", value: Self.scopes.joined(separator: " ")),
                URLQueryItem(name: "show_dialog", value: "true"),
            ]
            guard let authorizationURL = components.url else {
                throw SpotifyBridgeError.invalidAuthorizationURL
            }

            pendingVerifier = verifier
            pendingState = state
            connectionState = .connecting
            statusMessage = "Connexion sécurisée à Spotify…"

            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: Self.callbackURL.scheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.webAuthenticationSession = nil
                    self.webAuthenticationPresentationContext = nil
                    if error != nil {
                        self.pendingVerifier = nil
                        self.pendingState = nil
                        self.present(SpotifyBridgeError.authorizationCancelled)
                        return
                    }
                    guard let callbackURL else {
                        self.present(SpotifyBridgeError.invalidCallback)
                        return
                    }
                    await self.completeAuthorization(callbackURL)
                }
            }
            let presentationContext = SpotifyAuthenticationPresentationContext(
                anchor: NSApp.keyWindow
                    ?? NSApp.mainWindow
                    ?? NSApp.windows.first(where: \.isVisible)
                    ?? NSApp.windows.first
                    ?? ASPresentationAnchor()
            )
            session.presentationContextProvider = presentationContext
            session.prefersEphemeralWebBrowserSession = true
            webAuthenticationPresentationContext = presentationContext
            webAuthenticationSession = session
            guard session.start() else {
                webAuthenticationSession = nil
                webAuthenticationPresentationContext = nil
                throw SpotifyBridgeError.authorizationCancelled
            }
        } catch {
            present(error)
        }
    }

    func disconnect() {
        webAuthenticationSession?.cancel()
        webAuthenticationSession = nil
        webAuthenticationPresentationContext = nil
        refreshTask?.cancel()
        refreshTask = nil
        try? tokenStore.remove(clientID: clientID)
        currentSession = nil
        accountName = nil
        accountIdentifier = nil
        playlists = []
        selectedPlaylistID = nil
        selectedTracks = []
        lastSynchronizationAt = nil
        connectionState = .disconnected
        statusMessage = "Compte Spotify déconnecté de MixPilot."
    }

    func synchronizeLibrary() async throws {
        connectionState = .synchronizing
        statusMessage = "Synchronisation de la bibliothèque Spotify…"

        let profile: SpotifyProfileDTO = try await apiGet(
            SpotifyProfileDTO.self,
            url: try apiURL(path: "/v1/me")
        )
        accountName = profile.displayName ?? profile.id
        accountIdentifier = profile.id

        var pagination = SpotifyPaginationGuard(maximumPages: 100)
        var nextURL: URL? = try apiURL(
            path: "/v1/me/playlists",
            queryItems: [
                URLQueryItem(name: "limit", value: "50"),
                URLQueryItem(name: "offset", value: "0"),
            ]
        )
        var synchronizedPlaylists: [SpotifyLibraryPlaylist] = []

        while let candidate = nextURL {
            let pageURL: URL
            do {
                pageURL = try pagination.accept(candidate)
            } catch SpotifyNetworkSecurityError.paginationLoop {
                throw SpotifyBridgeError.paginationLoop
            } catch SpotifyNetworkSecurityError.pageLimitExceeded {
                throw SpotifyBridgeError.pageLimitExceeded
            } catch {
                throw SpotifyBridgeError.networkPolicy
            }
            let page: SpotifyPageDTO<SpotifyPlaylistDTO> = try await apiGet(
                SpotifyPageDTO<SpotifyPlaylistDTO>.self,
                url: pageURL
            )
            synchronizedPlaylists.append(contentsOf: page.items.map { dto in
                SpotifyLibraryPlaylist(
                    id: dto.id,
                    name: dto.name,
                    ownerName: dto.owner?.displayName ?? dto.owner?.id,
                    isCollaborative: dto.collaborative ?? false,
                    isPublic: dto.isPublic,
                    itemCount: dto.items?.total ?? dto.tracks?.total ?? 0,
                    spotifyURL: dto.externalURLs?.spotify,
                    isLikedSongs: false
                )
            })
            nextURL = try validatedNextURL(page.next)
        }

        let likedCount = try await likedSongsCount()
        synchronizedPlaylists.insert(
            SpotifyLibraryPlaylist(
                id: SpotifyLibraryPlaylist.likedSongsIdentifier,
                name: "Titres likés",
                ownerName: accountName,
                isPublic: false,
                itemCount: likedCount,
                isLikedSongs: true
            ),
            at: 0
        )

        playlists = deduplicatedPlaylists(synchronizedPlaylists)
        if selectedPlaylistID == nil || !playlists.contains(where: { $0.id == selectedPlaylistID }) {
            selectedPlaylistID = playlists.first?.id
        }
        if selectedPlaylistID != nil {
            try await synchronizeSelectedPlaylist()
        }
        lastSynchronizationAt = Date()
        connectionState = .connected
        statusMessage = "\(playlists.count) playlists Spotify synchronisées."
    }

    func selectPlaylist(_ playlistID: String) async {
        selectedPlaylistID = playlistID
        do {
            try await synchronizeSelectedPlaylist()
        } catch {
            present(error)
        }
    }

    func synchronizeSelectedPlaylist() async throws {
        guard let playlist = selectedPlaylist else {
            throw SpotifyBridgeError.noPlaylistSelected
        }
        statusMessage = "Synchronisation de « \(playlist.name) »…"
        selectedTracks = try await fetchTracks(for: playlist)
        statusMessage = "\(selectedTracks.count) titres synchronisés dans « \(playlist.name) »."
    }

    func automaticSelection(maximumCount: Int = 25) async throws -> SpotifyAutomaticSetSelection {
        guard selectedPlaylist != nil else {
            throw SpotifyBridgeError.noPlaylistSelected
        }
        if selectedTracks.isEmpty {
            try await synchronizeSelectedPlaylist()
        }
        var liked: [SpotifyLibraryTrack] = []
        if selectedTracks.filter(isUsableTrack).count < 2,
           selectedPlaylistID != SpotifyLibraryPlaylist.likedSongsIdentifier,
           let likedPlaylist = playlists.first(where: \.isLikedSongs) {
            liked = try await fetchTracks(for: likedPlaylist)
        }
        let selection = selector.select(
            primary: selectedTracks,
            likedSongs: liked,
            maximumCount: maximumCount
        )
        guard selection.tracks.count >= 2 else {
            throw SpotifyBridgeError.notEnoughPlayableTracks
        }
        return selection
    }

    func refreshRekordbox() {
        rekordboxStatus = rekordboxDetector.detect()
        if rekordboxStatus.isRunning {
            statusMessage = "Rekordbox \(rekordboxStatus.runningVersion ?? "") détecté."
        } else if rekordboxStatus.isInstalled {
            statusMessage = "Rekordbox est installé mais fermé."
        } else {
            statusMessage = RekordboxDetectionError.notInstalled.localizedDescription
        }
    }

    func openRekordbox() async {
        do {
            rekordboxStatus = try await rekordboxDetector.open()
            statusMessage = "Rekordbox est ouvert."
        } catch {
            present(error)
        }
    }

    func detectVisibleRekordboxPlaylist() async {
        rekordboxStatus = rekordboxDetector.detect()
        guard rekordboxStatus.isRunning else {
            statusMessage = "Ouvre Rekordbox, affiche Spotify et sélectionne une playlist."
            return
        }

        let collectedAt = Date()
        let window = accessibilityBridge.observe(backend: .rekordbox)
        let rows = accessibilityBridge.libraryRows(backend: .rekordbox, maxRows: 1_000)
        rekordboxWindowObservation = window
        visibleRows = rows

        if !window.visibleText.isEmpty {
            rekordboxLibrarySource = .visibleText(observedAt: collectedAt)
        } else if !rows.isEmpty {
            rekordboxLibrarySource = .freshOCR(observedAt: collectedAt)
        } else {
            rekordboxLibrarySource = nil
        }

        let associationKey = manualAssociationKey(window: window)
        let manualID = manualAssociations()[associationKey]
        var result = matcher.match(
            backend: .rekordbox,
            playlists: playlists,
            tracks: selectedTracks,
            visibleText: window.visibleText,
            rows: rows.map(\.fields),
            manualPlaylistID: manualID,
            observedAt: collectedAt
        )

        if let matchedID = result.matchedPlaylistID,
           matchedID != selectedPlaylistID,
           playlists.contains(where: { $0.id == matchedID }) {
            selectedPlaylistID = matchedID
            try? await synchronizeSelectedPlaylist()
            result = matcher.match(
                backend: .rekordbox,
                playlists: playlists,
                tracks: selectedTracks,
                visibleText: window.visibleText,
                rows: rows.map(\.fields),
                manualPlaylistID: manualID,
                observedAt: collectedAt
            )
        }

        playlistMatch = result
        switch result.confidence {
        case .exact:
            statusMessage = "Playlist Rekordbox associée exactement à « \(matchedPlaylist?.name ?? "Spotify") »."
        case .probable:
            statusMessage = "Association probable avec « \(matchedPlaylist?.name ?? "une playlist Spotify") ». Vérifie avant le Live."
        case .partial:
            statusMessage = "Playlist partiellement reconnue. Tu peux choisir l’association manuellement."
        case .manual:
            statusMessage = "Association manuelle active pour cette playlist Rekordbox."
        case .notRecognized:
            statusMessage = "La playlist visible n’a pas été reconnue automatiquement. Choisis-la manuellement."
        }
    }

    func associateVisiblePlaylistManually(with playlistID: String) async {
        guard playlists.contains(where: { $0.id == playlistID }) else { return }
        var associations = manualAssociations()
        associations[manualAssociationKey(window: rekordboxWindowObservation)] = playlistID
        saveManualAssociations(associations)
        selectedPlaylistID = playlistID
        try? await synchronizeSelectedPlaylist()
        await detectVisibleRekordboxPlaylist()
    }

    func removeManualAssociation() async {
        var associations = manualAssociations()
        associations.removeValue(forKey: manualAssociationKey(window: rekordboxWindowObservation))
        saveManualAssociations(associations)
        await detectVisibleRekordboxPlaylist()
    }

    func exportRekordboxDiagnostic() {
        let diagnostic = RekordboxSpotifyDiagnostic(
            generatedAt: Date(),
            mixPilotVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            rekordbox: rekordboxStatus,
            accessibilityGranted: rekordboxWindowObservation?.accessibilityGranted ?? false,
            screenCaptureGranted: CGPreflightScreenCaptureAccess(),
            windowTitle: rekordboxWindowObservation?.windowTitle,
            visibleTextCount: rekordboxWindowObservation?.visibleText.count ?? 0,
            visibleRowCount: visibleRows.count,
            source: sourceLabel(rekordboxLibrarySource),
            observedAt: rekordboxLibrarySource?.date,
            selectedSpotifyPlaylistID: selectedPlaylistID,
            matchedSpotifyPlaylistID: playlistMatch?.matchedPlaylistID,
            confidence: playlistMatch?.confidence.rawValue,
            confidenceScore: playlistMatch?.confidenceScore,
            recognizedTrackCount: playlistMatch?.matchedTrackIDs.count ?? 0,
            unrecognizedTrackCount: playlistMatch?.unmatchedTrackIDs.count ?? 0,
            statusMessage: statusMessage
        )
        guard let data = try? JSONEncoder.pretty.encode(diagnostic) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MixPilot-Rekordbox-Diagnostic.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url, options: Data.WritingOptions.atomic)
    }

    private func completeAuthorization(_ callbackURL: URL) async {
        defer {
            pendingVerifier = nil
            pendingState = nil
        }
        do {
            guard callbackURL.scheme == Self.callbackURL.scheme,
                  callbackURL.host == Self.callbackURL.host,
                  let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                throw SpotifyBridgeError.invalidCallback
            }
            let values = Dictionary(
                uniqueKeysWithValues: components.queryItems?.map { ($0.name, $0.value ?? "") } ?? []
            )
            guard values["state"] == pendingState else {
                throw SpotifyBridgeError.stateMismatch
            }
            guard let code = values["code"], !code.isEmpty,
                  let verifier = pendingVerifier else {
                throw SpotifyBridgeError.missingAuthorizationCode
            }
            let token = try await httpClient.token(form: [
                "client_id": clientID,
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": Self.callbackURL.absoluteString,
                "code_verifier": verifier,
            ])
            let stored = storedSession(from: token, preservingRefreshToken: nil)
            try tokenStore.save(stored, clientID: clientID)
            currentSession = stored
            connectionState = .connected
            statusMessage = "Spotify est connecté."
            try await synchronizeLibrary()
        } catch {
            present(error)
        }
    }

    private func fetchTracks(for playlist: SpotifyLibraryPlaylist) async throws -> [SpotifyLibraryTrack] {
        var pagination = SpotifyPaginationGuard(maximumPages: 200)
        var nextURL: URL?
        if playlist.isLikedSongs {
            nextURL = try apiURL(
                path: "/v1/me/tracks",
                queryItems: [URLQueryItem(name: "limit", value: "50")]
            )
        } else {
            nextURL = try apiURL(
                path: "/v1/playlists/\(playlist.id)/items",
                queryItems: [
                    URLQueryItem(name: "limit", value: "100"),
                    URLQueryItem(name: "additional_types", value: "track"),
                ]
            )
        }

        var tracks: [SpotifyLibraryTrack] = []
        var seen = Set<String>()
        while let candidate = nextURL {
            let pageURL: URL
            do {
                pageURL = try pagination.accept(candidate)
            } catch SpotifyNetworkSecurityError.paginationLoop {
                throw SpotifyBridgeError.paginationLoop
            } catch SpotifyNetworkSecurityError.pageLimitExceeded {
                throw SpotifyBridgeError.pageLimitExceeded
            } catch {
                throw SpotifyBridgeError.networkPolicy
            }
            let page: SpotifyPageDTO<SpotifyPlaylistItemDTO> = try await apiGet(
                SpotifyPageDTO<SpotifyPlaylistItemDTO>.self,
                url: pageURL
            )
            for item in page.items {
                guard let dto = item.resolvedTrack,
                      let track = libraryTrack(from: dto),
                      seen.insert(track.stableIdentityKey).inserted else {
                    continue
                }
                tracks.append(track)
            }
            nextURL = try validatedNextURL(page.next)
        }
        return tracks
    }

    private func likedSongsCount() async throws -> Int {
        let page: SpotifyPageDTO<SpotifyPlaylistItemDTO> = try await apiGet(
            SpotifyPageDTO<SpotifyPlaylistItemDTO>.self,
            url: try apiURL(
                path: "/v1/me/tracks",
                queryItems: [URLQueryItem(name: "limit", value: "1")]
            )
        )
        return page.total ?? 0
    }

    private func apiGet<T: Decodable & Sendable>(_ type: T.Type, url: URL) async throws -> T {
        let token = try await accessToken()
        do {
            return try await httpClient.get(type, url: url, accessToken: token)
        } catch SpotifyBridgeError.api(status: 401) {
            let refreshed = try await accessToken(forceRefresh: true)
            return try await httpClient.get(type, url: url, accessToken: refreshed)
        }
    }

    private func accessToken(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh,
           let currentSession,
           !currentSession.needsRefresh {
            return currentSession.accessToken
        }
        let refreshed = try await refreshSession()
        return refreshed.accessToken
    }

    private func refreshSession() async throws -> SpotifyStoredSession {
        if let refreshTask {
            return try await refreshTask.value
        }
        guard let current = currentSession ?? tokenStore.read(clientID: clientID),
              let refreshToken = current.refreshToken,
              !refreshToken.isEmpty else {
            throw SpotifyBridgeError.noRefreshToken
        }
        let task = Task<SpotifyStoredSession, Error> { [httpClient, tokenStore, clientID] in
            let token = try await httpClient.token(form: [
                "client_id": clientID,
                "grant_type": "refresh_token",
                "refresh_token": refreshToken,
            ])
            let stored = SpotifyStoredSession(
                accessToken: token.accessToken,
                refreshToken: token.refreshToken ?? refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(max(60, token.expiresIn))),
                scopes: token.scope ?? current.scopes
            )
            try tokenStore.save(stored, clientID: clientID)
            return stored
        }
        refreshTask = task
        defer { refreshTask = nil }
        let refreshed = try await task.value
        currentSession = refreshed
        connectionState = .connected
        return refreshed
    }

    private func storedSession(
        from token: SpotifyTokenResponse,
        preservingRefreshToken: String?
    ) -> SpotifyStoredSession {
        SpotifyStoredSession(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken ?? preservingRefreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(max(60, token.expiresIn))),
            scopes: token.scope
        )
    }

    private func apiURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = SpotifyNetworkPolicy.apiHost
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw SpotifyBridgeError.networkPolicy }
        return url
    }

    private func validatedNextURL(_ value: String?) throws -> URL? {
        guard let value, !value.isEmpty else { return nil }
        guard let url = URL(string: value) else { throw SpotifyBridgeError.networkPolicy }
        do {
            return try SpotifyNetworkPolicy().validatedAPIURL(url)
        } catch {
            throw SpotifyBridgeError.networkPolicy
        }
    }

    private func libraryTrack(from dto: SpotifyTrackDTO) -> SpotifyLibraryTrack? {
        guard let id = dto.id,
              let uri = dto.uri,
              !dto.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return SpotifyLibraryTrack(
            id: id,
            uri: uri,
            title: dto.name,
            artists: dto.artists.map(\.name),
            album: dto.album?.name,
            duration: TimeInterval(dto.durationMilliseconds ?? 0) / 1_000,
            explicit: dto.explicit ?? false,
            isPlayable: dto.isPlayable,
            isLocal: dto.isLocal ?? false,
            isrc: dto.externalIDs?.isrc,
            spotifyURL: dto.externalURLs?.spotify
        )
    }

    private func deduplicatedPlaylists(
        _ values: [SpotifyLibraryPlaylist]
    ) -> [SpotifyLibraryPlaylist] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.id).inserted }
    }

    private func isUsableTrack(_ track: SpotifyLibraryTrack) -> Bool {
        !track.isLocal && track.isPlayable != false && track.duration > 0
    }

    private func manualAssociationKey(window: DJWindowObservation?) -> String {
        let bundle = rekordboxStatus.bundleIdentifier ?? "rekordbox"
        let version = rekordboxStatus.runningVersion ?? rekordboxStatus.installedVersion ?? "unknown"
        let visibleName = playlistMatch?.visiblePlaylistName
            ?? window?.visibleText.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            ?? "visible-playlist"
        return [bundle, version, SpotifyPlaylistMatcher.normalize(visibleName)]
            .joined(separator: "|")
    }

    private func manualAssociations() -> [String: String] {
        UserDefaults.standard.dictionary(
            forKey: Self.manualAssociationsDefaultsKey
        ) as? [String: String] ?? [:]
    }

    private func saveManualAssociations(_ values: [String: String]) {
        UserDefaults.standard.set(values, forKey: Self.manualAssociationsDefaultsKey)
    }

    private func sourceLabel(_ source: MixPilotSystem.RekordboxLibrarySource?) -> String? {
        switch source {
        case .accessibility: "accessibility"
        case .visibleText: "visibleText"
        case .freshOCR: "freshOCR"
        case .cachedOCR: "cachedOCR"
        case .spotifyAPI: "spotifyAPI"
        case nil: nil
        }
    }

    private func present(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription
            ?? "Une erreur technique est survenue."
        connectionState = .failed(message)
        statusMessage = message
    }
}

private final class SpotifyAuthenticationPresentationContext: NSObject,
    ASWebAuthenticationPresentationContextProviding,
    @unchecked Sendable {
    private let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
        super.init()
    }

    func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        anchor
    }
}

private struct RekordboxSpotifyDiagnostic: Codable {
    var generatedAt: Date
    var mixPilotVersion: String?
    var macOSVersion: String
    var rekordbox: RekordboxEnvironmentStatus
    var accessibilityGranted: Bool
    var screenCaptureGranted: Bool
    var windowTitle: String?
    var visibleTextCount: Int
    var visibleRowCount: Int
    var source: String?
    var observedAt: Date?
    var selectedSpotifyPlaylistID: String?
    var matchedSpotifyPlaylistID: String?
    var confidence: String?
    var confidenceScore: Double?
    var recognizedTrackCount: Int
    var unrecognizedTrackCount: Int
    var statusMessage: String
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
#endif
