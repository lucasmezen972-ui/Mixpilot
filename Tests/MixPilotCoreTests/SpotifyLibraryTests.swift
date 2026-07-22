import Foundation
import Testing
@testable import MixPilotCore

@Test("Spotify playlist matching prefers an exact normalized name")
func spotifyPlaylistExactMatch() {
    let playlist = SpotifyLibraryPlaylist(id: "exact", name: "Fête Créole")
    let tracks = [makeSpotifyTrack(id: "1", title: "Mwen Lé", artist: "Kassav")]

    let result = SpotifyPlaylistMatcher().match(
        backend: .rekordbox,
        playlists: [playlist],
        tracks: tracks,
        visibleText: ["Spotify", "Fete Creole"],
        rows: [["Mwen Lé", "Kassav"]]
    )

    #expect(result.confidence == .exact)
    #expect(result.matchedPlaylistID == playlist.id)
    #expect(result.matchedTrackIDs == ["1"])
}

@Test("Spotify playlist matching can return probable without trusting Spotify alone")
func spotifyPlaylistProbableMatch() {
    let playlist = SpotifyLibraryPlaylist(id: "probable", name: "Soirée Antilles 2026")
    let tracks = [makeSpotifyTrack(id: "1", title: "Toujou La", artist: "Misié Sadik")]

    let result = SpotifyPlaylistMatcher().match(
        backend: .rekordbox,
        playlists: [playlist],
        tracks: tracks,
        visibleText: ["Spotify", "Soiree Antilles"],
        rows: [["Toujou La", "Misié Sadik"]]
    )

    #expect(result.confidence == .probable)
    #expect(result.matchedPlaylistID == playlist.id)
    #expect(result.confidenceScore >= 0.78)
}

@Test("Spotify word alone is never proof of the selected playlist")
func spotifyWordAloneDoesNotRecognizePlaylist() {
    let playlist = SpotifyLibraryPlaylist(id: "playlist", name: "Baptême")

    let result = SpotifyPlaylistMatcher().match(
        backend: .rekordbox,
        playlists: [playlist],
        tracks: [makeSpotifyTrack(id: "1", title: "Water", artist: "Tyla")],
        visibleText: ["Spotify"],
        rows: []
    )

    #expect(result.spotifySectionVisible)
    #expect(result.confidence == .notRecognized)
    #expect(result.matchedPlaylistID == nil)
}

@Test("Spotify playlist matching returns partial from title and artist overlap")
func spotifyPlaylistPartialMatch() {
    let tracks = [
        makeSpotifyTrack(id: "1", title: "Water", artist: "Tyla"),
        makeSpotifyTrack(id: "2", title: "Baddies", artist: "Aya Nakamura"),
        makeSpotifyTrack(id: "3", title: "One Track Mind", artist: "Naïka"),
        makeSpotifyTrack(id: "4", title: "Bébé", artist: "RnBoi"),
    ]

    let result = SpotifyPlaylistMatcher().match(
        backend: .rekordbox,
        playlists: [SpotifyLibraryPlaylist(id: "p", name: "Playlist privée")],
        tracks: tracks,
        visibleText: ["Bibliothèque"],
        rows: [
            ["Water", "Tyla"],
            ["Baddies", "Aya Nakamura"],
        ]
    )

    #expect(result.confidence == .partial)
    #expect(result.matchedTrackIDs == ["1", "2"])
    #expect(Set(result.unmatchedTrackIDs) == Set(["3", "4"]))
}

@Test("A manual Spotify association is explicit and editable by ID")
func spotifyPlaylistManualMatch() {
    let playlists = [
        SpotifyLibraryPlaylist(id: "a", name: "A"),
        SpotifyLibraryPlaylist(id: "b", name: "B"),
    ]

    let result = SpotifyPlaylistMatcher().match(
        backend: .rekordbox,
        playlists: playlists,
        tracks: [],
        visibleText: [],
        rows: [],
        manualPlaylistID: "b"
    )

    #expect(result.confidence == .manual)
    #expect(result.matchedPlaylistID == "b")
    #expect(result.visiblePlaylistName == "B")
}

@Test("Track matching requires the title and artist together")
func spotifyTrackMatchingUsesTitleAndArtist() {
    let track = makeSpotifyTrack(id: "1", title: "Water", artist: "Tyla")

    let wrongArtist = SpotifyPlaylistMatcher().match(
        backend: .rekordbox,
        playlists: [],
        tracks: [track],
        visibleText: [],
        rows: [["Water", "Other Artist"]]
    )
    let correctArtist = SpotifyPlaylistMatcher().match(
        backend: .rekordbox,
        playlists: [],
        tracks: [track],
        visibleText: [],
        rows: [["Water", "Tyla"]]
    )

    #expect(wrongArtist.matchedTrackIDs.isEmpty)
    #expect(correctArtist.matchedTrackIDs == ["1"])
}

@Test("Automatic Spotify selection deduplicates the same ISRC and preserves order")
func spotifyAutomaticSelectionDeduplicatesISRC() {
    let first = makeSpotifyTrack(id: "1", title: "First", artist: "Artist", isrc: "MQA1A2600001")
    let duplicate = makeSpotifyTrack(id: "2", title: "Duplicate", artist: "Artist", isrc: "mqa1a2600001")
    let second = makeSpotifyTrack(id: "3", title: "Second", artist: "Artist", isrc: "MQA1A2600002")

    let selection = SpotifyAutomaticSetSelector().select(
        primary: [first, duplicate, second],
        maximumCount: 25
    )

    #expect(selection.tracks.map(\.id) == ["1", "3"])
    #expect(!selection.usedLikedSongsFallback)
}

@Test("Automatic Spotify selection uses Liked Songs only below two usable tracks")
func spotifyAutomaticSelectionUsesLikedSongsFallback() {
    let unusable = makeSpotifyTrack(
        id: "local",
        title: "Local",
        artist: "Artist",
        isLocal: true
    )
    let primary = makeSpotifyTrack(id: "primary", title: "Primary", artist: "Artist")
    let liked = makeSpotifyTrack(id: "liked", title: "Liked", artist: "Artist")

    let selection = SpotifyAutomaticSetSelector().select(
        primary: [unusable, primary],
        likedSongs: [liked]
    )

    #expect(selection.tracks.map(\.id) == ["primary", "liked"])
    #expect(selection.usedLikedSongsFallback)
}

@Test("Spotify metadata never invents a BPM")
func spotifyTrackKeepsUnknownBPM() {
    let track = makeSpotifyTrack(id: "1", title: "Unknown BPM", artist: "Artist")
    #expect(track.asMixPilotTrack().bpm == 0)
}

private func makeSpotifyTrack(
    id: String,
    title: String,
    artist: String,
    isrc: String? = nil,
    isLocal: Bool = false
) -> SpotifyLibraryTrack {
    SpotifyLibraryTrack(
        id: id,
        uri: "spotify:track:\(id)",
        title: title,
        artists: [artist],
        album: "Album",
        duration: 180,
        isPlayable: true,
        isLocal: isLocal,
        isrc: isrc
    )
}
