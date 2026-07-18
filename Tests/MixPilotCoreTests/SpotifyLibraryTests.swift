import Foundation
import Testing
@testable import MixPilotCore

@Suite("Spotify multi-DJ visibility")
struct SpotifyLibraryTests {
    @Test("Spotify playlist and tracks are matched in visible DJ rows")
    func matchesVisibleSpotifyContent() {
        let playlist = SpotifyLibraryPlaylist(id: "party", name: "Baptême Lucas")
        let track = SpotifyLibraryTrack(
            id: "track-1",
            uri: "spotify:track:track-1",
            title: "Water",
            artists: ["Tyla"],
            duration: 200
        )

        let result = SpotifyDJVisibilityMatcher().match(
            backend: .rekordbox,
            playlists: [playlist],
            tracks: [track],
            visibleText: ["Spotify", "Your Library", "Baptême Lucas"],
            rows: [["Water", "Tyla", "03:20"]]
        )

        #expect(result.spotifySectionVisible)
        #expect(result.matchedPlaylistIDs == ["party"])
        #expect(result.matchedTrackIDs == ["track-1"])
        #expect(result.visibleRowCount == 1)
    }

    @Test("A title without the expected artist does not produce a row match")
    func rejectsAmbiguousTrack() {
        let track = SpotifyLibraryTrack(
            id: "track-2",
            uri: "spotify:track:track-2",
            title: "One More Time",
            artists: ["Daft Punk"],
            duration: 320
        )

        let result = SpotifyDJVisibilityMatcher().match(
            backend: .serato,
            playlists: [],
            tracks: [track],
            visibleText: ["Spotify"],
            rows: [["One More Time", "Unknown Artist"]]
        )

        #expect(result.spotifySectionVisible)
        #expect(result.matchedTrackIDs.isEmpty)
    }

    @Test("Spotify metadata creates a safe MixPilot track without pretending to know BPM")
    func convertsToMixPilotTrack() {
        let source = SpotifyLibraryTrack(
            id: "track-3",
            uri: "spotify:track:track-3",
            title: "Afrobeats Night",
            artists: ["Artist"],
            duration: 245
        )

        let track = source.asMixPilotTrack()
        #expect(track.bpm == 0)
        #expect(track.duration == 245)
        #expect(track.profile == .afro)
    }
}
