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
                guard seen.insert(track.stableIdentityKey).inserted else { continue }
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
        !track.isLocal
            && track.duration > 0
            && track.isPlayable != false
            && !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
