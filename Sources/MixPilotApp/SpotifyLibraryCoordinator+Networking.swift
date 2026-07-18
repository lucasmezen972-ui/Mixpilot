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
extension SpotifyLibraryCoordinator {
    func restoreSession() {
        storedSession = tokenStore.read(clientID: clientID)
        isConnected = storedSession != nil
        if isConnected {
            status = "Session Spotify trouvée dans le Trousseau"
        }
    }

    func validateCallback(_ callbackURL: URL?, expectedState: String) throws -> String {
        guard let callbackURL,
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw SpotifyBridgeError.invalidCallback
        }
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        if let message = values["error"], !message.isEmpty {
            throw SpotifyBridgeError.api(status: 400, message: message)
        }
        guard values["state"] == expectedState else { throw SpotifyBridgeError.stateMismatch }
        guard let code = values["code"], !code.isEmpty else { throw SpotifyBridgeError.missingAuthorizationCode }
        return code
    }

    func exchangeAuthorizationCode(_ code: String, verifier: String) async throws {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "client_id": clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "code_verifier": verifier,
        ])
        let response: SpotifyTokenResponse = try await send(request)
        let session = SpotifyStoredSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(max(60, response.expiresIn))),
            scopes: response.scope
        )
        try tokenStore.save(session, clientID: clientID)
        storedSession = session
        isConnected = true
        status = "Compte Spotify connecté"
    }

    func refreshAccessToken() async throws {
        guard let refreshToken = storedSession?.refreshToken, !refreshToken.isEmpty else {
            throw SpotifyBridgeError.noRefreshToken
        }
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ])
        let response: SpotifyTokenResponse = try await send(request)
        let session = SpotifyStoredSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(max(60, response.expiresIn))),
            scopes: response.scope ?? storedSession?.scopes
        )
        try tokenStore.save(session, clientID: clientID)
        storedSession = session
        isConnected = true
    }

    func accessToken() async throws -> String {
        guard storedSession != nil else { throw SpotifyBridgeError.authorizationCancelled }
        if storedSession?.needsRefresh == true {
            try await refreshAccessToken()
        }
        guard let token = storedSession?.accessToken else { throw SpotifyBridgeError.authorizationCancelled }
        return token
    }

    func get<T: Decodable>(_ absoluteURL: String, retryAfterRefresh: Bool = true) async throws -> T {
        guard let url = URL(string: absoluteURL) else { throw SpotifyBridgeError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        do {
            return try await send(request)
        } catch SpotifyBridgeError.api(let status, _) where status == 401 && retryAfterRefresh {
            try await refreshAccessToken()
            return try await get(absoluteURL, retryAfterRefresh: false)
        }
    }

    func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyBridgeError.invalidResponse }
        if http.statusCode == 429 {
            let retry = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "5") ?? 5
            throw SpotifyBridgeError.rateLimited(seconds: max(1, retry))
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw SpotifyBridgeError.api(status: http.statusCode, message: message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SpotifyBridgeError.api(
                status: http.statusCode,
                message: "Réponse impossible à décoder : \(error.localizedDescription)"
            )
        }
    }

    func fetchAllPlaylists() async throws -> [SpotifyLibraryPlaylist] {
        var next: String? = "https://api.spotify.com/v1/me/playlists?limit=50"
        var result: [SpotifyLibraryPlaylist] = []
        var seen = Set<String>()
        while let url = next {
            let page: SpotifyPageDTO<SpotifyPlaylistDTO> = try await get(url)
            for item in page.items where seen.insert(item.id).inserted {
                result.append(SpotifyLibraryPlaylist(
                    id: item.id,
                    name: item.name,
                    ownerName: item.owner?.displayName ?? item.owner?.id,
                    isCollaborative: item.collaborative ?? false,
                    isPublic: item.isPublic,
                    itemCount: item.items?.total ?? item.tracks?.total ?? 0,
                    spotifyURL: item.externalURLs?.spotify
                ))
            }
            next = page.next
        }
        return result
    }

    func fetchLikedSongsCount() async throws -> Int {
        let page: SpotifyPageDTO<SpotifyPlaylistItemDTO> = try await get(
            "https://api.spotify.com/v1/me/tracks?limit=1"
        )
        return page.total ?? page.items.count
    }

    func loadPlaylist(identifier: String) async throws {
        isWorking = true
        defer { isWorking = false }
        let loaded: [SpotifyLibraryTrack]
        if identifier == SpotifyLibraryPlaylist.likedSongsIdentifier {
            loaded = try await fetchTrackPages(
                firstURL: "https://api.spotify.com/v1/me/tracks?limit=50"
            )
        } else {
            do {
                loaded = try await fetchTrackPages(
                    firstURL: "https://api.spotify.com/v1/playlists/\(identifier)/items?limit=50"
                )
            } catch SpotifyBridgeError.api(let status, _) where status == 403 || status == 404 {
                loaded = try await fetchTrackPages(
                    firstURL: "https://api.spotify.com/v1/playlists/\(identifier)/tracks?limit=50"
                )
            }
        }
        tracks = loaded
        visibility = nil
        status = "\(loaded.count) morceau(x) chargé(s) depuis \(selectedPlaylist?.name ?? "Spotify")"
    }

    func fetchTrackPages(firstURL: String) async throws -> [SpotifyLibraryTrack] {
        var next: String? = firstURL
        var output: [SpotifyLibraryTrack] = []
        var seen = Set<String>()
        while let url = next {
            let page: SpotifyPageDTO<SpotifyPlaylistItemDTO> = try await get(url)
            for wrapper in page.items {
                guard let dto = wrapper.resolvedTrack,
                      let title = nonEmpty(dto.name),
                      let uri = nonEmpty(dto.uri) else { continue }
                let id = nonEmpty(dto.id) ?? uri
                guard seen.insert(id).inserted else { continue }
                output.append(SpotifyLibraryTrack(
                    id: id,
                    uri: uri,
                    title: title,
                    artists: dto.artists.map(\.name),
                    album: dto.album?.name,
                    duration: TimeInterval(dto.durationMilliseconds ?? 0) / 1_000,
                    explicit: dto.explicit ?? false,
                    isPlayable: dto.isPlayable,
                    isLocal: dto.isLocal ?? false,
                    isrc: dto.externalIDs?.isrc,
                    spotifyURL: dto.externalURLs?.spotify
                ))
            }
            next = page.next
        }
        return output
    }

    func formEncoded(_ values: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = values.sorted(by: { $0.key < $1.key }).map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        return Data((components.percentEncodedQuery ?? "").utf8)
    }

    func nonEmpty(_ value: String?) -> String? {
        let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cleaned.isEmpty ? nil : cleaned
    }
}
#endif
