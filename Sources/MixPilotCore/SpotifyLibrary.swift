import Foundation

public struct SpotifyLibraryPlaylist: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var ownerName: String?
    public var isCollaborative: Bool
    public var isPublic: Bool?
    public var itemCount: Int
    public var spotifyURL: URL?
    public var isLikedSongs: Bool

    public init(
        id: String,
        name: String,
        ownerName: String? = nil,
        isCollaborative: Bool = false,
        isPublic: Bool? = nil,
        itemCount: Int = 0,
        spotifyURL: URL? = nil,
        isLikedSongs: Bool = false
    ) {
        self.id = id
        self.name = name
        self.ownerName = ownerName
        self.isCollaborative = isCollaborative
        self.isPublic = isPublic
        self.itemCount = max(0, itemCount)
        self.spotifyURL = spotifyURL
        self.isLikedSongs = isLikedSongs
    }

    public static let likedSongsIdentifier = "__mixpilot_spotify_liked_songs__"
}

public struct SpotifyLibraryTrack: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var uri: String
    public var title: String
    public var artists: [String]
    public var album: String?
    public var duration: TimeInterval
    public var explicit: Bool
    public var isPlayable: Bool?
    public var isLocal: Bool
    public var isrc: String?
    public var spotifyURL: URL?

    public init(
        id: String,
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
        self.id = id
        self.uri = uri
        self.title = title
        self.artists = artists.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.album = album
        self.duration = max(0, duration)
        self.explicit = explicit
        self.isPlayable = isPlayable
        self.isLocal = isLocal
        self.isrc = isrc
        self.spotifyURL = spotifyURL
    }

    public var artistText: String {
        artists.isEmpty ? "Artiste inconnu" : artists.joined(separator: ", ")
    }

    public func asMixPilotTrack() -> Track {
        let profile = Self.profile(title: title, artists: artists, album: album)
        let vocalDensity: Double
        switch profile {
        case .rap: vocalDensity = 0.88
        case .dancehall, .shatta, .bouyon: vocalDensity = 0.76
        case .zouk, .kompa, .variety, .family: vocalDensity = 0.68
        case .afro, .amapiano: vocalDensity = 0.58
        case .safe: vocalDensity = 0.45
        }
        return Track(
            title: title,
            artist: artistText,
            bpm: 0,
            duration: duration,
            energy: 0.50,
            vocalDensity: vocalDensity,
            profile: profile
        )
    }

    private static func profile(title: String, artists: [String], album: String?) -> MusicalProfile {
        let haystack = ([title] + artists + [album].compactMap { $0 })
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        if haystack.contains("amapiano") { return .amapiano }
        if haystack.contains("afro") || haystack.contains("afrobeats") { return .afro }
        if haystack.contains("shatta") { return .shatta }
        if haystack.contains("bouyon") { return .bouyon }
        if haystack.contains("dancehall") || haystack.contains("reggae") { return .dancehall }
        if haystack.contains("kompa") || haystack.contains("compas") { return .kompa }
        if haystack.contains("zouk") { return .zouk }
        if haystack.contains("rap") || haystack.contains("hip hop") || haystack.contains("hip-hop") { return .rap }
        if haystack.contains("clean") || haystack.contains("family") || haystack.contains("enfant") { return .family }
        return .variety
    }
}

public struct SpotifyDJVisibilityResult: Codable, Hashable, Sendable {
    public var backend: DJBackendIdentifier
    public var spotifySectionVisible: Bool
    public var matchedPlaylistIDs: [String]
    public var matchedTrackIDs: [String]
    public var visibleRowCount: Int
    public var observedAt: Date

    public init(
        backend: DJBackendIdentifier,
        spotifySectionVisible: Bool,
        matchedPlaylistIDs: [String],
        matchedTrackIDs: [String],
        visibleRowCount: Int,
        observedAt: Date = Date()
    ) {
        self.backend = backend
        self.spotifySectionVisible = spotifySectionVisible
        self.matchedPlaylistIDs = matchedPlaylistIDs
        self.matchedTrackIDs = matchedTrackIDs
        self.visibleRowCount = max(0, visibleRowCount)
        self.observedAt = observedAt
    }
}

public struct SpotifyDJVisibilityMatcher: Sendable {
    public init() {}

    public func match(
        backend: DJBackendIdentifier,
        playlists: [SpotifyLibraryPlaylist],
        tracks: [SpotifyLibraryTrack],
        visibleText: [String],
        rows: [[String]]
    ) -> SpotifyDJVisibilityResult {
        let normalizedVisible = visibleText.map(Self.normalize)
        let normalizedRows = rows.map { row in row.map(Self.normalize) }
        let combined = normalizedVisible.joined(separator: " | ")
        let spotifyVisible = combined.contains("spotify") || normalizedRows.contains { row in
            row.contains { $0.contains("spotify") }
        }

        let playlistIDs = playlists.compactMap { playlist -> String? in
            let needle = Self.normalize(playlist.name)
            guard needle.count >= 3 else { return nil }
            let found = combined.contains(needle) || normalizedRows.contains { row in
                row.contains { $0.contains(needle) }
            }
            return found ? playlist.id : nil
        }

        let trackIDs = tracks.compactMap { track -> String? in
            let title = Self.normalize(track.title)
            guard title.count >= 3 else { return nil }
            let artists = track.artists.map(Self.normalize).filter { $0.count >= 2 }
            let found = normalizedRows.contains { row in
                let rowText = row.joined(separator: " | ")
                guard rowText.contains(title) else { return false }
                return artists.isEmpty || artists.contains { rowText.contains($0) }
            } || (combined.contains(title) && (artists.isEmpty || artists.contains { combined.contains($0) }))
            return found ? track.id : nil
        }

        return SpotifyDJVisibilityResult(
            backend: backend,
            spotifySectionVisible: spotifyVisible,
            matchedPlaylistIDs: Array(playlistIDs.prefix(50)),
            matchedTrackIDs: Array(trackIDs.prefix(200)),
            visibleRowCount: rows.count
        )
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
