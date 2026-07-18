#if os(macOS)
import Foundation
import MixPilotCore

private enum SpotifyAutomaticPreferences {
    static let selectedPlaylistID = "MixPilotSpotifySelectedPlaylistID"
}

@MainActor
extension SpotifyLibraryCoordinator {
    func rememberSelectedPlaylist() {
        guard let selectedPlaylistID, !selectedPlaylistID.isEmpty else {
            UserDefaults.standard.removeObject(forKey: SpotifyAutomaticPreferences.selectedPlaylistID)
            return
        }
        UserDefaults.standard.set(
            selectedPlaylistID,
            forKey: SpotifyAutomaticPreferences.selectedPlaylistID
        )
    }

    func makeAutomaticSpotifyProject(
        backend: DJBackendIdentifier,
        maximumTrackCount: Int = 25
    ) async throws -> SetProject {
        restoreSession()
        guard isConnected else { throw SpotifyBridgeError.notConnected }

        try await synchronizeLibrary()

        let rememberedID = UserDefaults.standard.string(
            forKey: SpotifyAutomaticPreferences.selectedPlaylistID
        )
        let primaryID: String
        if let rememberedID,
           playlists.contains(where: { $0.id == rememberedID }) {
            primaryID = rememberedID
        } else if let selectedPlaylistID,
                  playlists.contains(where: { $0.id == selectedPlaylistID }) {
            primaryID = selectedPlaylistID
        } else {
            primaryID = SpotifyLibraryPlaylist.likedSongsIdentifier
        }

        selectedPlaylistID = primaryID
        rememberSelectedPlaylist()
        try await loadPlaylist(identifier: primaryID)

        let primaryPlaylist = playlists.first { $0.id == primaryID }
        let primaryTracks = tracks
        let selector = SpotifyAutomaticSetSelector()
        let primarySelection = selector.select(
            primary: primaryTracks,
            maximumCount: maximumTrackCount
        )

        var likedSongsTracks: [SpotifyLibraryTrack] = []
        if primarySelection.tracks.count < 2,
           primaryID != SpotifyLibraryPlaylist.likedSongsIdentifier {
            try await loadPlaylist(
                identifier: SpotifyLibraryPlaylist.likedSongsIdentifier
            )
            likedSongsTracks = tracks
        }

        let selection = selector.select(
            primary: primaryTracks,
            likedSongs: likedSongsTracks,
            maximumCount: maximumTrackCount
        )
        guard selection.tracks.count >= 2 else {
            throw SpotifyBridgeError.notEnoughPlayableTracks
        }

        let playlistName = primaryPlaylist?.name ?? "Titres likés"
        let sourceName = selection.usedLikedSongsFallback
            ? "Spotify — \(playlistName) + Titres likés"
            : "Spotify — \(playlistName)"
        let project = SetPreparationEngine().prepare(
            name: sourceName,
            tracks: selection.tracks.map { $0.asMixPilotTrack() },
            backend: backend
        )

        status = selection.usedLikedSongsFallback
            ? "Set automatique créé depuis \(playlistName), complété par les Titres likés • \(selection.tracks.count) titres"
            : "Set automatique créé depuis \(playlistName) • \(selection.tracks.count) titres"
        return project
    }
}
#endif
