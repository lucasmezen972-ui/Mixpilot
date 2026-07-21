import Foundation

public extension SpotifyNetworkPolicy {
    static func validatedAPIURL(_ url: URL) throws -> URL {
        try SpotifyNetworkPolicy().validatedAPIURL(url)
    }
}

public extension SpotifyLibraryTrack {
    init(
        id: String?,
        uri: String,
        title: String,
        artists: [String],
        album: String? = nil,
        duration: TimeInterval,
        explicit: Bool = false,
        isPlayable: Bool? = nil,
        isLocal: Bool = false,
        isrc: String? = nil,
        spotifyURL: URL? = nil
    ) {
        let normalizedID = id?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            id: normalizedID.flatMap { $0.isEmpty ? nil : $0 } ?? uri,
            uri: uri,
            title: title,
            artists: artists,
            album: album,
            duration: duration,
            explicit: explicit,
            isPlayable: isPlayable,
            isLocal: isLocal,
            isrc: isrc,
            spotifyURL: spotifyURL
        )
    }
}
