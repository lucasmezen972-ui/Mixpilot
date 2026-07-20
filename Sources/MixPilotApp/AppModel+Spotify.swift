#if os(macOS)
import MixPilotCore

@MainActor
extension AppModel {
    func prepareSpotifyPlaylist(
        name: String,
        tracks spotifyTracks: [SpotifyLibraryTrack],
        usedLikedSongsFallback: Bool
    ) throws {
        guard let selectedBackend else {
            throw SpotifyBridgeError.backendNotSelected
        }
        let usable = spotifyTracks.filter {
            !$0.isLocal && $0.isPlayable != false && $0.duration > 0
        }
        guard usable.count >= 2 else {
            throw SpotifyBridgeError.notEnoughPlayableTracks
        }

        let tracks = usable.map { $0.asMixPilotTrack() }
        preparedProject = SetPreparationEngine().prepare(
            name: "Spotify — \(name)",
            tracks: tracks,
            backend: selectedBackend
        )
        optimizationReport = SetOptimizer().analyze(tracks: tracks)
        libraryRowCount = tracks.count
        playlistWarnings = [
            "BPM non analysé — transition prudente",
        ] + (usedLikedSongsFallback
            ? ["La playlist a été complétée avec les Titres likés pour atteindre deux morceaux exploitables."]
            : [])
        runtimeStatus = "\(tracks.count) titres Spotify préparés pour \(selectedBackend.displayName)."
        updateSnapshotForProject()
        evaluatePreflight()
        selectedSection = .preflight
    }
}
#endif
