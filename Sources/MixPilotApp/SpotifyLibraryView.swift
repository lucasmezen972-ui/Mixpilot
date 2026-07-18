#if os(macOS)
import AppKit
import MixPilotCore
import SwiftUI

struct SpotifyLibraryView: View {
    @ObservedObject var appModel: AppModel
    @StateObject private var spotify = SpotifyLibraryCoordinator()
    @State private var filter = ""

    private var filteredTracks: [SpotifyLibraryTrack] {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return spotify.tracks }
        return spotify.tracks.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
                $0.artistText.localizedCaseInsensitiveContains(query) ||
                ($0.album?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        setupCard
                        if spotify.isConnected {
                            libraryWorkspace
                            visibilityCard
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { spotify.restoreAndSynchronizeIfPossible() }
        .onChange(of: spotify.selectedPlaylistID) { _, _ in
            Task { await spotify.loadSelectedPlaylist() }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.green.opacity(0.18))
                Image(systemName: "music.note.list")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.green)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text("SPOTIFY BRIDGE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(.green)
                Text("Une bibliothèque pour Rekordbox, Serato et djay")
                    .font(.title2.bold())
                Text("MixPilot lit les playlists via l’API officielle, puis reconnaît ce que le logiciel DJ affiche à l’écran.")
                    .font(.caption)
                    .foregroundStyle(MixPilotPalette.textTertiary)
            }
            Spacer()
            MixPilotStatusBadge(
                title: spotify.isConnected ? "Spotify connecté" : "À connecter",
                symbol: spotify.isConnected ? "checkmark.circle.fill" : "link.badge.plus",
                accent: spotify.isConnected ? .green : .orange
            )
            if spotify.isWorking { ProgressView().controlSize(.small).tint(.green) }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private var setupCard: some View {
        MixPilotGlassCard(accent: spotify.isConnected ? .green : .orange) {
            VStack(alignment: .leading, spacing: 14) {
                MixPilotPanelTitle(
                    title: spotify.isConnected ? "Compte Spotify" : "Connexion Spotify officielle",
                    symbol: "person.crop.circle.badge.checkmark",
                    subtitle: spotify.userDisplayName ?? spotify.status,
                    accent: spotify.isConnected ? .green : .orange
                )

                if !spotify.isConnected {
                    Text("Crée une application Spotify Developer nommée MixPilot, puis ajoute exactement cette Redirect URI :")
                        .font(.callout)
                        .foregroundStyle(MixPilotPalette.textSecondary)
                    HStack {
                        Text(SpotifyLibraryCoordinator.redirectURI)
                            .font(.system(.callout, design: .monospaced).weight(.semibold))
                            .textSelection(.enabled)
                        Spacer()
                        Button("Copier") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(SpotifyLibraryCoordinator.redirectURI, forType: .string)
                        }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    }

                    TextField("Spotify Client ID", text: $spotify.clientID)
                        .textFieldStyle(.roundedBorder)
                    Text("Le Client ID n’est pas un secret. MixPilot n’enregistre jamais de Client Secret et utilise OAuth PKCE.")
                        .font(.caption)
                        .foregroundStyle(MixPilotPalette.textTertiary)
                }

                HStack(spacing: 10) {
                    if spotify.isConnected {
                        Button("Synchroniser") {
                            Task {
                                do { try await spotify.synchronizeLibrary() }
                                catch { spotify.report(error) }
                            }
                        }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                        Button("Déconnecter", role: .destructive) { spotify.disconnect() }
                            .buttonStyle(MixPilotDangerButtonStyle())
                    } else {
                        Button("Enregistrer le Client ID") { spotify.saveClientID() }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                        Button("Connecter Spotify") { spotify.connect() }
                            .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                    }
                    Spacer()
                    Text(spotify.status)
                        .font(.caption)
                        .foregroundStyle(MixPilotPalette.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var libraryWorkspace: some View {
        HStack(alignment: .top, spacing: 16) {
            MixPilotGlassCard(accent: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    MixPilotPanelTitle(
                        title: "Playlists Spotify",
                        symbol: "rectangle.stack.fill",
                        subtitle: "\(spotify.playlists.count) playlist(s) et bibliothèque",
                        accent: .green
                    )
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(spotify.playlists) { playlist in
                                playlistButton(playlist)
                            }
                        }
                    }
                    .frame(minHeight: 420, maxHeight: 620)
                }
            }
            .frame(width: 320)

            MixPilotGlassCard(accent: .cyan) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        MixPilotPanelTitle(
                            title: spotify.selectedPlaylist?.name ?? "Morceaux",
                            symbol: "music.note",
                            subtitle: "\(spotify.tracks.count) élément(s) • métadonnées Spotify uniquement",
                            accent: .cyan
                        )
                        Spacer()
                        Button("Préparer dans MixPilot") {
                            spotify.prepareSelectedPlaylist(appModel: appModel)
                        }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .cyan))
                        .disabled(spotify.tracks.isEmpty)
                    }
                    TextField("Rechercher dans cette playlist", text: $filter)
                        .textFieldStyle(.roundedBorder)
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(filteredTracks) { track in
                                trackRow(track)
                            }
                        }
                    }
                    .frame(minHeight: 420, maxHeight: 620)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func playlistButton(_ playlist: SpotifyLibraryPlaylist) -> some View {
        let selected = spotify.selectedPlaylistID == playlist.id
        return Button {
            spotify.selectedPlaylistID = playlist.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: playlist.isLikedSongs ? "heart.fill" : "music.note.list")
                    .foregroundStyle(selected ? .green : .white.opacity(0.58))
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.system(size: 12, weight: selected ? .bold : .semibold, design: .rounded))
                        .lineLimit(1)
                    Text("\(playlist.itemCount) titre(s)" + (playlist.ownerName.map { " • \($0)" } ?? ""))
                        .font(.caption2)
                        .foregroundStyle(MixPilotPalette.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                if let url = playlist.spotifyURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(selected ? .green.opacity(0.12) : .white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func trackRow(_ track: SpotifyLibraryTrack) -> some View {
        HStack(spacing: 12) {
            Image(systemName: track.explicit ? "e.square.fill" : "music.note")
                .foregroundStyle(track.explicit ? .orange : .cyan)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).font(.callout.weight(.semibold)).lineLimit(1)
                Text(track.artistText + (track.album.map { " • \($0)" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(MixPilotPalette.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Text(duration(track.duration))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(MixPilotPalette.textTertiary)
            Button("Chercher dans le logiciel") {
                spotify.copySearchQuery(for: track, appModel: appModel)
            }
            .buttonStyle(MixPilotSecondaryButtonStyle())
            if let url = track.spotifyURL {
                Link(destination: url) { Image(systemName: "arrow.up.right.square") }
                    .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
    }

    private var visibilityCard: some View {
        MixPilotGlassCard(accent: .purple) {
            VStack(alignment: .leading, spacing: 14) {
                MixPilotPanelTitle(
                    title: "Visibilité dans le logiciel DJ",
                    symbol: "eye.fill",
                    subtitle: appModel.selectedBackend?.displayName ?? "Aucun logiciel sélectionné",
                    accent: .purple
                )
                HStack(spacing: 10) {
                    Button("Ouvrir le logiciel DJ") {
                        spotify.activateSelectedBackend(appModel: appModel)
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                    Button("Vérifier Spotify à l’écran") {
                        spotify.scanSelectedDJSoftware(appModel: appModel)
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                    Spacer()
                    if let result = spotify.visibility {
                        MixPilotStatusBadge(
                            title: result.spotifySectionVisible ? "Spotify visible" : "Spotify non visible",
                            symbol: result.spotifySectionVisible ? "eye.fill" : "eye.slash.fill",
                            accent: result.spotifySectionVisible ? .green : .orange
                        )
                    }
                }
                if let result = spotify.visibility {
                    Text("\(result.matchedPlaylistIDs.count) playlist(s), \(result.matchedTrackIDs.count) morceau(x) et \(result.visibleRowCount) ligne(s) visibles reconnus dans \(result.backend.displayName).")
                        .font(.callout)
                        .foregroundStyle(MixPilotPalette.textSecondary)
                } else {
                    Text("Ouvre la rubrique Spotify et la playlist dans Rekordbox, Serato ou djay. MixPilot compare ensuite les noms affichés avec ta bibliothèque officielle Spotify.")
                        .font(.callout)
                        .foregroundStyle(MixPilotPalette.textSecondary)
                }
                Text("MixPilot ne télécharge aucun fichier audio Spotify, ne contourne aucun DRM et ne récupère jamais les jetons privés des logiciels DJ.")
                    .font(.caption)
                    .foregroundStyle(MixPilotPalette.textTertiary)
            }
        }
    }

    private func duration(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
#endif
