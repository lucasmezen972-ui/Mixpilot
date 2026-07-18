#if os(macOS)
import AppKit
import AuthenticationServices
import CryptoKit
import Foundation
import MixPilotCore
import MixPilotSystem
import Security
import SwiftUI

@MainActor
final class SpotifyLibraryCoordinator: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let redirectURI = "mixpilot-spotify://callback"
    private static let clientIDDefaultsKey = "MixPilotSpotifyClientID"
    private static let scopes = [
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-library-read",
        "user-read-private",
    ].joined(separator: " ")

    @Published var clientID: String
    @Published var isConnected = false
    @Published var isWorking = false
    @Published var status = "Spotify n’est pas encore connecté"
    @Published var userDisplayName: String?
    @Published var playlists: [SpotifyLibraryPlaylist] = []
    @Published var tracks: [SpotifyLibraryTrack] = []
    @Published var selectedPlaylistID: String?
    @Published var visibility: SpotifyDJVisibilityResult?

    let tokenStore = SpotifyTokenStore()
    let matcher = SpotifyDJVisibilityMatcher()
    var storedSession: SpotifyStoredSession?
    var authenticationSession: ASWebAuthenticationSession?

    override init() {
        let environmentClientID = ProcessInfo.processInfo.environment["MIXPILOT_SPOTIFY_CLIENT_ID"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bundledClientID = (Bundle.main.object(forInfoDictionaryKey: "MixPilotSpotifyClientID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let savedClientID = UserDefaults.standard.string(forKey: Self.clientIDDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        clientID = environmentClientID.flatMap { $0.isEmpty ? nil : $0 }
            ?? bundledClientID.flatMap { $0.isEmpty ? nil : $0 }
            ?? savedClientID.flatMap { $0.isEmpty ? nil : $0 }
            ?? ""
        super.init()
        restoreSession()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    }

    func saveClientID() {
        clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(clientID, forKey: Self.clientIDDefaultsKey)
        restoreSession()
        status = clientID.isEmpty
            ? "Client ID Spotify manquant"
            : "Client ID enregistré. Tu peux connecter Spotify."
    }

    func connect() {
        do {
            saveClientID()
            guard !clientID.isEmpty else { throw SpotifyBridgeError.missingClientID }
            let verifier = try SpotifyPKCE.randomURLSafeString(byteCount: 64)
            let state = try SpotifyPKCE.randomURLSafeString(byteCount: 32)
            let challenge = SpotifyPKCE.challenge(for: verifier)

            var components = URLComponents(string: "https://accounts.spotify.com/authorize")
            components?.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "scope", value: Self.scopes),
                URLQueryItem(name: "show_dialog", value: "true"),
            ]
            guard let authorizationURL = components?.url else {
                throw SpotifyBridgeError.invalidAuthorizationURL
            }

            isWorking = true
            status = "Ouverture de la connexion Spotify…"
            let auth = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: "mixpilot-spotify"
            ) { [weak self] callbackURL, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.authenticationSession = nil
                    if let error = error as? ASWebAuthenticationSessionError,
                       error.code == .canceledLogin {
                        self.isWorking = false
                        self.status = SpotifyBridgeError.authorizationCancelled.localizedDescription
                        return
                    }
                    if let error {
                        self.isWorking = false
                        self.status = error.localizedDescription
                        return
                    }
                    do {
                        let code = try self.validateCallback(callbackURL, expectedState: state)
                        try await self.exchangeAuthorizationCode(code, verifier: verifier)
                        try await self.synchronizeLibrary()
                    } catch {
                        self.isWorking = false
                        self.status = error.localizedDescription
                    }
                }
            }
            auth.presentationContextProvider = self
            auth.prefersEphemeralWebBrowserSession = false
            authenticationSession = auth
            guard auth.start() else {
                authenticationSession = nil
                isWorking = false
                status = "La fenêtre de connexion Spotify n’a pas pu être ouverte."
                return
            }
        } catch {
            isWorking = false
            status = error.localizedDescription
        }
    }

    func disconnect() {
        do {
            try tokenStore.remove(clientID: clientID)
        } catch {
            status = error.localizedDescription
            return
        }
        storedSession = nil
        isConnected = false
        userDisplayName = nil
        playlists = []
        tracks = []
        selectedPlaylistID = nil
        visibility = nil
        status = "Compte Spotify déconnecté de MixPilot"
    }

    func report(_ error: Error) {
        isWorking = false
        status = error.localizedDescription
    }

    func restoreAndSynchronizeIfPossible() {
        restoreSession()
        guard isConnected else { return }
        Task {
            do {
                try await synchronizeLibrary()
            } catch {
                isWorking = false
                status = error.localizedDescription
            }
        }
    }

    func synchronizeLibrary() async throws {
        guard !clientID.isEmpty else { throw SpotifyBridgeError.missingClientID }
        isWorking = true
        defer { isWorking = false }

        async let profile: SpotifyProfileDTO = get("https://api.spotify.com/v1/me")
        async let remotePlaylists = fetchAllPlaylists()
        async let likedCount = fetchLikedSongsCount()

        let resolvedProfile = try await profile
        let resolvedPlaylists = try await remotePlaylists
        let resolvedLikedCount = try await likedCount

        userDisplayName = resolvedProfile.displayName ?? resolvedProfile.id
        let likedSongs = SpotifyLibraryPlaylist(
            id: SpotifyLibraryPlaylist.likedSongsIdentifier,
            name: "Titres likés",
            ownerName: userDisplayName,
            isPublic: false,
            itemCount: resolvedLikedCount,
            spotifyURL: URL(string: "https://open.spotify.com/collection/tracks"),
            isLikedSongs: true
        )
        playlists = [likedSongs] + resolvedPlaylists.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        isConnected = true
        status = "\(playlists.count) espace(s) Spotify synchronisé(s)"

        if selectedPlaylistID == nil || !playlists.contains(where: { $0.id == selectedPlaylistID }) {
            selectedPlaylistID = playlists.first?.id
        }
        if let selectedPlaylistID {
            try await loadPlaylist(identifier: selectedPlaylistID)
        }
    }

    func loadSelectedPlaylist() async {
        guard let selectedPlaylistID else { return }
        do {
            try await loadPlaylist(identifier: selectedPlaylistID)
        } catch {
            isWorking = false
            status = error.localizedDescription
        }
    }

    func scanSelectedDJSoftware(appModel: AppModel) {
        do {
            guard let backend = appModel.selectedBackend else {
                throw SpotifyBridgeError.backendNotSelected
            }
            let observation = appModel.accessibilityBridge.observe(
                backend: backend,
                maxDepth: 10,
                maximumStrings: 1_000
            )
            guard observation.isRunning else {
                status = "\(backend.displayName) n’est pas lancé."
                visibility = SpotifyDJVisibilityResult(
                    backend: backend,
                    spotifySectionVisible: false,
                    matchedPlaylistIDs: [],
                    matchedTrackIDs: [],
                    visibleRowCount: 0
                )
                return
            }
            guard observation.accessibilityGranted else {
                appModel.accessibilityBridge.requestAccessibilityPrompt()
                status = "Autorise MixPilot à lire l’interface de \(backend.displayName), puis relance la vérification."
                return
            }
            let rows = appModel.accessibilityBridge.libraryRows(backend: backend, maxRows: 1_000)
            let result = matcher.match(
                backend: backend,
                playlists: playlists,
                tracks: tracks,
                visibleText: observation.visibleText,
                rows: rows.map(\.fields)
            )
            visibility = result
            appModel.libraryRowCount = rows.count
            if result.spotifySectionVisible {
                status = "Spotify visible dans \(backend.displayName) • \(result.matchedTrackIDs.count) morceau(x) reconnu(s)"
            } else {
                status = "\(backend.displayName) est ouvert, mais sa rubrique Spotify n’est pas visible à l’écran."
            }
        } catch {
            status = error.localizedDescription
        }
    }

    func prepareSelectedPlaylist(appModel: AppModel) {
        guard let playlist = selectedPlaylist else {
            status = SpotifyBridgeError.noPlaylistSelected.localizedDescription
            return
        }
        let usableTracks = tracks.filter { !$0.isLocal && $0.duration > 0 }
        guard !usableTracks.isEmpty else {
            status = SpotifyBridgeError.emptyPlaylist.localizedDescription
            return
        }
        appModel.preparedProject = SetPreparationEngine().prepare(
            name: "Spotify — \(playlist.name)",
            tracks: usableTracks.map { $0.asMixPilotTrack() },
            backend: appModel.selectedBackend
        )
        appModel.playlistWarnings = []
        appModel.updateSnapshotForProject()
        appModel.evaluatePreflight()
        appModel.selectedSection = .studio
        status = "Playlist préparée dans MixPilot • charge ensuite le titre dans le logiciel DJ avant PLAY"
    }

    func activateSelectedBackend(appModel: AppModel) {
        guard let backend = appModel.selectedBackend else {
            status = SpotifyBridgeError.backendNotSelected.localizedDescription
            return
        }
        do {
            try appModel.accessibilityBridge.activate(backend)
            status = "\(backend.displayName) activé. Ouvre sa rubrique Spotify puis clique sur Vérifier."
        } catch {
            status = error.localizedDescription
        }
    }

    func copySearchQuery(for track: SpotifyLibraryTrack, appModel: AppModel) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(track.title) \(track.artistText)", forType: .string)
        activateSelectedBackend(appModel: appModel)
        status = "Recherche copiée : \(track.title) — colle-la dans la recherche, puis charge le titre sur un deck."
    }

    var selectedPlaylist: SpotifyLibraryPlaylist? {
        guard let selectedPlaylistID else { return nil }
        return playlists.first { $0.id == selectedPlaylistID }
    }
}
#endif
