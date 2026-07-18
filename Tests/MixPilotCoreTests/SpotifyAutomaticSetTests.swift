import Foundation
import Testing
@testable import MixPilotCore

@Suite("Spotify automatic set selection")
struct SpotifyAutomaticSetTests {
    @Test("A valid Spotify playlist is kept in order and capped")
    func keepsPrimaryOrderAndCap() {
        let primary = (0..<30).map { index in
            spotifyTrack(id: "p-\(index)", title: "Primary \(index)")
        }

        let selection = SpotifyAutomaticSetSelector().select(
            primary: primary,
            maximumCount: 25
        )

        #expect(selection.tracks.count == 25)
        #expect(selection.tracks.first?.title == "Primary 0")
        #expect(selection.tracks.last?.title == "Primary 24")
        #expect(!selection.usedLikedSongsFallback)
    }

    @Test("Liked songs complete a playlist containing fewer than two usable tracks")
    func completesFromLikedSongs() {
        let primary = [
            spotifyTrack(id: "primary", title: "Only Primary"),
            spotifyTrack(id: "local", title: "Local", isLocal: true),
        ]
        let liked = [
            spotifyTrack(id: "liked-1", title: "Liked One"),
            spotifyTrack(id: "liked-2", title: "Liked Two"),
        ]

        let selection = SpotifyAutomaticSetSelector().select(
            primary: primary,
            likedSongs: liked,
            maximumCount: 25
        )

        #expect(selection.tracks.map(\.title) == ["Only Primary", "Liked One", "Liked Two"])
        #expect(selection.usedLikedSongsFallback)
    }

    @Test("Local unavailable and duplicate Spotify tracks are excluded")
    func excludesInvalidAndDuplicates() {
        let duplicateA = spotifyTrack(id: "a", title: "Same", isrc: "FR-ABC-1")
        let duplicateB = spotifyTrack(id: "b", title: "Same Copy", isrc: "fr-abc-1")
        let unavailable = spotifyTrack(id: "x", title: "Unavailable", isPlayable: false)
        let local = spotifyTrack(id: "y", title: "Local", isLocal: true)

        let selection = SpotifyAutomaticSetSelector().select(
            primary: [duplicateA, duplicateB, unavailable, local],
            likedSongs: [spotifyTrack(id: "fallback", title: "Fallback")]
        )

        #expect(selection.tracks.map(\.title) == ["Same", "Fallback"])
        #expect(selection.usedLikedSongsFallback)
    }

    private func spotifyTrack(
        id: String,
        title: String,
        isPlayable: Bool? = true,
        isLocal: Bool = false,
        isrc: String? = nil
    ) -> SpotifyLibraryTrack {
        SpotifyLibraryTrack(
            id: id,
            uri: "spotify:track:\(id)",
            title: title,
            artists: ["Artist"],
            duration: 180,
            isPlayable: isPlayable,
            isLocal: isLocal,
            isrc: isrc
        )
    }
}
