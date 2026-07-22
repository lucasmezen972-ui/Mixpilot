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
        self.artists = artists.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
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

    public var stableIdentityKey: String {
        if let isrc = Self.normalizedIdentifier(isrc) {
            return "isrc:\(isrc)"
        }
        if let id = Self.normalizedIdentifier(id) {
            return "id:\(id)"
        }
        return "uri:\(uri.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
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

    private static func normalizedIdentifier(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalized.isEmpty ? nil : normalized
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

public enum PlaylistMatchConfidence: String, Codable, Hashable, Sendable {
    case exact
    case probable
    case partial
    case manual
    case notRecognized
}

public struct SpotifyPlaylistMatchResult: Codable, Hashable, Sendable {
    public var backend: DJBackendIdentifier
    public var spotifySectionVisible: Bool
    public var visiblePlaylistName: String?
    public var matchedPlaylistID: String?
    public var confidence: PlaylistMatchConfidence
    public var confidenceScore: Double
    public var matchedTrackIDs: [String]
    public var unmatchedTrackIDs: [String]
    public var visibleRowCount: Int
    public var observedAt: Date

    public init(
        backend: DJBackendIdentifier,
        spotifySectionVisible: Bool,
        visiblePlaylistName: String? = nil,
        matchedPlaylistID: String? = nil,
        confidence: PlaylistMatchConfidence,
        confidenceScore: Double,
        matchedTrackIDs: [String] = [],
        unmatchedTrackIDs: [String] = [],
        visibleRowCount: Int = 0,
        observedAt: Date = Date()
    ) {
        self.backend = backend
        self.spotifySectionVisible = spotifySectionVisible
        self.visiblePlaylistName = visiblePlaylistName
        self.matchedPlaylistID = matchedPlaylistID
        self.confidence = confidence
        self.confidenceScore = max(0, min(1, confidenceScore))
        self.matchedTrackIDs = matchedTrackIDs
        self.unmatchedTrackIDs = unmatchedTrackIDs
        self.visibleRowCount = max(0, visibleRowCount)
        self.observedAt = observedAt
    }
}

public struct SpotifyPlaylistMatcher: Sendable {
    public init() {}

    public func match(
        backend: DJBackendIdentifier,
        playlists: [SpotifyLibraryPlaylist],
        tracks: [SpotifyLibraryTrack],
        visibleText: [String],
        rows: [[String]],
        manualPlaylistID: String? = nil,
        observedAt: Date = Date()
    ) -> SpotifyPlaylistMatchResult {
        let normalizedText = visibleText.map(Self.normalize).filter { !$0.isEmpty }
        let normalizedRows = rows.map { $0.map(Self.normalize).filter { !$0.isEmpty } }
        let combinedText = normalizedText.joined(separator: " | ")
        let rowText = normalizedRows.map { $0.joined(separator: " | ") }
        let spotifySectionVisible = normalizedText.contains { $0 == "spotify" || $0.hasPrefix("spotify ") }
            || normalizedRows.contains { row in row.contains { $0 == "spotify" || $0.hasPrefix("spotify ") } }

        let trackMatches = matchedTracks(tracks, in: rowText, fallbackText: combinedText)
        let matchedIDs = trackMatches.map(\.id)
        let matchedSet = Set(matchedIDs)
        let unmatchedIDs = tracks.map(\.id).filter { !matchedSet.contains($0) }

        if let manualPlaylistID,
           let playlist = playlists.first(where: { $0.id == manualPlaylistID }) {
            return SpotifyPlaylistMatchResult(
                backend: backend,
                spotifySectionVisible: spotifySectionVisible,
                visiblePlaylistName: playlist.name,
                matchedPlaylistID: playlist.id,
                confidence: .manual,
                confidenceScore: 1,
                matchedTrackIDs: matchedIDs,
                unmatchedTrackIDs: unmatchedIDs,
                visibleRowCount: rows.count,
                observedAt: observedAt
            )
        }

        let playlistCandidates = playlists.compactMap { playlist -> PlaylistCandidate? in
            let normalizedName = Self.normalize(playlist.name)
            guard normalizedName.count >= 2 else { return nil }
            let exact = normalizedText.contains(normalizedName)
                || normalizedRows.contains { $0.contains(normalizedName) }
                || combinedText.contains("| \(normalizedName) |")
                || combinedText.hasPrefix("\(normalizedName) |")
                || combinedText.hasSuffix("| \(normalizedName)")
            let similarity = max(
                Self.bestSimilarity(of: normalizedName, in: normalizedText),
                Self.bestSimilarity(of: normalizedName, in: normalizedRows.flatMap { $0 })
            )
            return PlaylistCandidate(playlist: playlist, exactName: exact, nameSimilarity: similarity)
        }

        if let exact = playlistCandidates.first(where: { $0.exactName }) {
            return SpotifyPlaylistMatchResult(
                backend: backend,
                spotifySectionVisible: spotifySectionVisible,
                visiblePlaylistName: exact.playlist.name,
                matchedPlaylistID: exact.playlist.id,
                confidence: .exact,
                confidenceScore: max(0.92, exact.nameSimilarity),
                matchedTrackIDs: matchedIDs,
                unmatchedTrackIDs: unmatchedIDs,
                visibleRowCount: rows.count,
                observedAt: observedAt
            )
        }

        if let probable = playlistCandidates.max(by: { $0.nameSimilarity < $1.nameSimilarity }),
           probable.nameSimilarity >= 0.78,
           !matchedIDs.isEmpty {
            return SpotifyPlaylistMatchResult(
                backend: backend,
                spotifySectionVisible: spotifySectionVisible,
                visiblePlaylistName: probable.playlist.name,
                matchedPlaylistID: probable.playlist.id,
                confidence: .probable,
                confidenceScore: probable.nameSimilarity,
                matchedTrackIDs: matchedIDs,
                unmatchedTrackIDs: unmatchedIDs,
                visibleRowCount: rows.count,
                observedAt: observedAt
            )
        }

        let overlap = tracks.isEmpty ? 0 : Double(matchedIDs.count) / Double(tracks.count)
        if matchedIDs.count >= 2, overlap >= 0.25 {
            return SpotifyPlaylistMatchResult(
                backend: backend,
                spotifySectionVisible: spotifySectionVisible,
                visiblePlaylistName: nil,
                matchedPlaylistID: nil,
                confidence: .partial,
                confidenceScore: min(0.74, overlap),
                matchedTrackIDs: matchedIDs,
                unmatchedTrackIDs: unmatchedIDs,
                visibleRowCount: rows.count,
                observedAt: observedAt
            )
        }

        return SpotifyPlaylistMatchResult(
            backend: backend,
            spotifySectionVisible: spotifySectionVisible,
            confidence: .notRecognized,
            confidenceScore: 0,
            matchedTrackIDs: matchedIDs,
            unmatchedTrackIDs: unmatchedIDs,
            visibleRowCount: rows.count,
            observedAt: observedAt
        )
    }

    private func matchedTracks(
        _ tracks: [SpotifyLibraryTrack],
        in rows: [String],
        fallbackText: String
    ) -> [SpotifyLibraryTrack] {
        var seen = Set<String>()
        return tracks.filter { track in
            guard seen.insert(track.stableIdentityKey).inserted else { return false }
            let title = Self.normalize(track.title)
            guard title.count >= 2 else { return false }
            let artists = track.artists.map(Self.normalize).filter { $0.count >= 2 }
            let album = Self.normalize(track.album ?? "")
            let rowMatch = rows.contains { row in
                guard row.contains(title) else { return false }
                if artists.isEmpty { return true }
                if artists.contains(where: row.contains) { return true }
                return !album.isEmpty && row.contains(album)
            }
            if rowMatch { return true }
            guard fallbackText.contains(title) else { return false }
            return artists.isEmpty || artists.contains(where: fallbackText.contains)
        }
    }

    private struct PlaylistCandidate {
        var playlist: SpotifyLibraryPlaylist
        var exactName: Bool
        var nameSimilarity: Double
    }

    private static func bestSimilarity(of needle: String, in candidates: [String]) -> Double {
        candidates.map { similarity(needle, $0) }.max() ?? 0
    }

    private static func similarity(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 1 }
        let left = Set(lhs.split(separator: " ").map(String.init))
        let right = Set(rhs.split(separator: " ").map(String.init))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        let intersection = left.intersection(right).count
        let union = left.union(right).count
        let tokenScore = Double(intersection) / Double(max(1, union))
        let containmentScore: Double = lhs.contains(rhs) || rhs.contains(lhs) ? 0.82 : 0
        return max(tokenScore, containmentScore)
    }

    public static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
