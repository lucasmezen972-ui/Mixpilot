import Foundation

public struct SpotifyAutomaticSetSelection: Hashable, Sendable {
    public var tracks: [SpotifyLibraryTrack]
    public var usedLikedSongsFallback: Bool

    public init(
        tracks: [SpotifyLibraryTrack],
        usedLikedSongsFallback: Bool
    ) {
        self.tracks = tracks
        self.usedLikedSongsFallback = usedLikedSongsFallback
    }
}

public struct SpotifyAutomaticSetSelector: Sendable {
    public init() {}

    public func select(
        primary: [SpotifyLibraryTrack],
        likedSongs: [SpotifyLibraryTrack] = [],
        maximumCount: Int = 25
    ) -> SpotifyAutomaticSetSelection {
        let limit = max(2, maximumCount)
        var selected: [SpotifyLibraryTrack] = []
        var seen = Set<String>()

        func append(_ candidates: [SpotifyLibraryTrack]) {
            for track in candidates where selected.count < limit {
                guard isUsable(track) else { continue }
                let key = identityKey(track)
                guard seen.insert(key).inserted else { continue }
                selected.append(track)
            }
        }

        append(primary)
        let needsFallback = selected.count < 2
        if needsFallback {
            append(likedSongs)
        }

        return SpotifyAutomaticSetSelection(
            tracks: selected,
            usedLikedSongsFallback: needsFallback && selected.count >= 2
        )
    }

    private func isUsable(_ track: SpotifyLibraryTrack) -> Bool {
        !track.isLocal &&
            track.duration > 0 &&
            track.isPlayable != false &&
            !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func identityKey(_ track: SpotifyLibraryTrack) -> String {
        if let isrc = track.isrc?.trimmingCharacters(in: .whitespacesAndNewlines),
           !isrc.isEmpty {
            return "isrc:\(isrc.lowercased())"
        }
        if !track.id.isEmpty {
            return "id:\(track.id.lowercased())"
        }
        return "uri:\(track.uri.lowercased())"
    }
}
