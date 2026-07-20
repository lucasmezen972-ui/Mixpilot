#if os(macOS)
import AppKit
import MixPilotCore
import MixPilotSystem
import SwiftUI

struct SpotifyLibraryView: View {
    @ObservedObject var spotify: SpotifyLibraryCoordinator
    @ObservedObject var model: AppModel
    @State private var manualPlaylistID = ""

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MixPilotSectionHero(
                        eyebrow: "Bibliothèque Rekordbox / Spotify",
                        title: "Retrouver la playlist réellement visible",
                        subtitle: "MixPilot synchronise la bibliothèque Spotify officielle, observe Rekordbox 6 ou 7 et indique clairement la source et la confiance du rapprochement.",
                        symbol: "music.note.list",
                        accent: .green
                    ) {
                        Button("Connecter Spotify") { spotify.connect() }
                            .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                        Button("Synchroniser Spotify") {
                            Task {
                                do { try await spotify.synchronizeLibrary() }
                                catch { spotify.statusMessage = error.localizedDescription }
                            }
                        }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                        .disabled(!spotify.connectionState.isConnected)
                        Button("Détecter la playlist visible") {
                            Task { await spotify.detectVisibleRekordboxPlaylist() }
                        }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .cyan))
                    }

                    statusStrip
                    spotifySection
                    rekordboxSection
                    matchSection
                    tracksSection

                    MixPilotNotice(
                        title: "État actuel",
                        message: spotify.statusMessage,
                        kind: statusNoticeKind
                    )
                }
                .padding(24)
                .frame(maxWidth: 1_180, alignment: .topLeading)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            spotify.refreshRekordbox()
            await spotify.restoreSession()
            manualPlaylistID = spotify.selectedPlaylistID ?? ""
        }
        .onChange(of: spotify.selectedPlaylistID) { _, newValue in
            manualPlaylistID = newValue ?? ""
        }
    }

    private var statusStrip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
            statusCard(
                title: "Spotify",
                value: spotify.connectionState.isConnected ? "Connecté" : "Non connecté",
                detail: spotify.accountName ?? "Aucun compte",
                symbol: "person.crop.circle",
                accent: spotify.connectionState.isConnected ? .green : .orange
            )
            statusCard(
                title: "Dernière synchronisation",
                value: spotify.lastSynchronizationAt?.formatted(date: .abbreviated, time: .shortened) ?? "Jamais",
                detail: "\(spotify.playlists.count) playlist(s)",
                symbol: "arrow.triangle.2.circlepath",
                accent: .blue
            )
            statusCard(
                title: "Rekordbox",
                value: spotify.rekordboxStatus.isRunning ? "Lancé" : (spotify.rekordboxStatus.isInstalled ? "Installé" : "Introuvable"),
                detail: versionLabel,
                symbol: "record.circle",
                accent: spotify.rekordboxStatus.isRunning ? .green : .orange
            )
            statusCard(
                title: "Rapprochement",
                value: confidenceLabel,
                detail: spotify.playlistMatch.map { "Confiance \(Int($0.confidenceScore * 100)) %" } ?? "Pas encore analysé",
                symbol: "link",
                accent: confidenceAccent
            )
        }
    }

    private var spotifySection: some View {
        MixPilotGlassCard(accent: .green) {
            VStack(alignment: .leading, spacing: 14) {
                MixPilotPanelTitle(
                    title: "Bibliothèque Spotify officielle",
                    symbol: "music.note",
                    subtitle: "OAuth PKCE, aucun Client Secret dans l’application, jetons conservés dans le Trousseau macOS.",
                    accent: .green
                )

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Client ID Spotify").font(.caption.bold())
                        TextField("Client ID de l’application Spotify", text: $spotify.clientID)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(spotify.connectionState.isConnected ? "Déconnecter" : "Connecter Spotify") {
                        spotify.connectionState.isConnected ? spotify.disconnect() : spotify.connect()
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                }

                Picker("Playlist Spotify sélectionnée", selection: Binding(
                    get: { spotify.selectedPlaylistID ?? "" },
                    set: { value in Task { await spotify.selectPlaylist(value) } }
                )) {
                    Text("Choisir une playlist").tag("")
                    ForEach(spotify.playlists) { playlist in
                        Text("\(playlist.name) — \(playlist.itemCount) titres").tag(playlist.id)
                    }
                }

                if let playlist = spotify.selectedPlaylist {
                    HStack(spacing: 18) {
                        Label("\(playlist.itemCount) titres", systemImage: "number")
                        if playlist.isCollaborative {
                            Label("Collaborative", systemImage: "person.2.fill")
                        }
                        if playlist.isLikedSongs {
                            Label("Titres likés", systemImage: "heart.fill")
                        }
                        Spacer()
                        Button("Synchroniser cette playlist") {
                            Task {
                                do { try await spotify.synchronizeSelectedPlaylist() }
                                catch { spotify.statusMessage = error.localizedDescription }
                            }
                        }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    }
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
    }

    private var rekordboxSection: some View {
        MixPilotGlassCard(accent: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                MixPilotPanelTitle(
                    title: "Observation Rekordbox 6 / 7",
                    symbol: "eye.fill",
                    subtitle: "Détection unifiée par processus, bundle identifier, URL réelle et installations versionnées.",
                    accent: .cyan
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 12)], spacing: 12) {
                    detailRow("Installé", spotify.rekordboxStatus.isInstalled ? "Oui" : "Non")
                    detailRow("Lancé", spotify.rekordboxStatus.isRunning ? "Oui" : "Non")
                    detailRow("Version", versionLabel)
                    detailRow("PID", spotify.rekordboxStatus.processIdentifier.map(String.init) ?? "—")
                    detailRow("Chemin", spotify.rekordboxStatus.applicationURL?.path ?? "—")
                    detailRow("Bundle ID", spotify.rekordboxStatus.bundleIdentifier ?? "—")
                    detailRow("Accessibilité", spotify.rekordboxWindowObservation?.accessibilityGranted == true ? "Autorisée" : "Manquante")
                    detailRow("Capture d’écran", CGPreflightScreenCaptureAccess() ? "Autorisée" : "Manquante")
                    detailRow("Fenêtre", spotify.rekordboxWindowObservation?.windowTitle ?? "Non détectée")
                    detailRow("Source", sourceLabel)
                    detailRow("Fraîcheur", freshnessLabel)
                    detailRow("Lignes visibles", "\(spotify.visibleRows.count)")
                }

                HStack(spacing: 10) {
                    Button("Ouvrir Rekordbox") { Task { await spotify.openRekordbox() } }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .cyan))
                    Button("Actualiser Rekordbox") { spotify.refreshRekordbox() }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    Button("Ouvrir les réglages d’autorisation") { openPrivacySettings() }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    Button("Exporter le diagnostic Rekordbox") { spotify.exportRekordboxDiagnostic() }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                }
            }
        }
    }

    private var matchSection: some View {
        MixPilotGlassCard(accent: confidenceAccent) {
            VStack(alignment: .leading, spacing: 14) {
                MixPilotPanelTitle(
                    title: "Playlist Rekordbox ↔ Spotify",
                    symbol: "link.badge.plus",
                    subtitle: "Le mot Spotify seul n’est jamais considéré comme une preuve de sélection.",
                    accent: confidenceAccent
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    detailRow("Rubrique Spotify visible", spotify.playlistMatch?.spotifySectionVisible == true ? "Oui" : "Non")
                    detailRow("Playlist visible", spotify.playlistMatch?.visiblePlaylistName ?? "Non reconnue")
                    detailRow("Playlist correspondante", spotify.matchedPlaylist?.name ?? "Aucune")
                    detailRow("Confiance", confidenceLabel)
                    detailRow("Titres reconnus", "\(spotify.playlistMatch?.matchedTrackIDs.count ?? 0)")
                    detailRow("Titres non reconnus", "\(spotify.playlistMatch?.unmatchedTrackIDs.count ?? 0)")
                }

                HStack(alignment: .bottom, spacing: 10) {
                    Picker("Associer manuellement une playlist", selection: $manualPlaylistID) {
                        Text("Choisir…").tag("")
                        ForEach(spotify.playlists) { playlist in
                            Text(playlist.name).tag(playlist.id)
                        }
                    }
                    Button("Associer manuellement") {
                        guard !manualPlaylistID.isEmpty else { return }
                        Task { await spotify.associateVisiblePlaylistManually(with: manualPlaylistID) }
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                    .disabled(manualPlaylistID.isEmpty)
                    Button("Supprimer l’association") {
                        Task { await spotify.removeManualAssociation() }
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                }

                HStack {
                    Spacer()
                    Button("Utiliser cette playlist pour le Live") {
                        Task { await prepareForLive() }
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                    .disabled(spotify.selectedPlaylist == nil)
                }
            }
        }
    }

    private var tracksSection: some View {
        MixPilotGlassCard(accent: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                MixPilotPanelTitle(
                    title: "Titres et artistes",
                    symbol: "list.number",
                    subtitle: "\(spotify.selectedTracks.count) titre(s) chargés. Le BPM reste inconnu tant qu’il n’est pas observé ou analysé.",
                    accent: .purple
                )
                if spotify.selectedTracks.isEmpty {
                    Text("Aucun titre chargé pour cette playlist.")
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    ForEach(Array(spotify.selectedTracks.prefix(250).enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 34, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title).font(.callout.bold())
                                Text(track.artistText)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.52))
                            }
                            Spacer()
                            Text("BPM —")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func prepareForLive() async {
        do {
            let selection = try await spotify.automaticSelection(maximumCount: 250)
            try model.prepareSpotifyPlaylist(
                name: spotify.selectedPlaylist?.name ?? "Playlist Spotify",
                tracks: selection.tracks,
                usedLikedSongsFallback: selection.usedLikedSongsFallback
            )
            spotify.statusMessage = "Playlist Spotify préparée. Le Live reste accessible avec les avertissements visibles."
        } catch {
            spotify.statusMessage = error.localizedDescription
        }
    }

    private func openPrivacySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]
        if let url = urls.compactMap(URL.init(string:)).first {
            NSWorkspace.shared.open(url)
        }
    }

    private func statusCard(
        title: String,
        value: String,
        detail: String,
        symbol: String,
        accent: Color
    ) -> some View {
        MixPilotGlassCard(cornerRadius: 16, padding: 14, accent: accent) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol).foregroundStyle(accent)
                Text(title).font(.caption.bold()).foregroundStyle(.white.opacity(0.45))
                Text(value).font(.headline).lineLimit(2)
                Text(detail).font(.caption).foregroundStyle(.white.opacity(0.52)).lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold()).foregroundStyle(.white.opacity(0.42))
            Text(value).font(.callout).textSelection(.enabled).lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        .padding(10)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private var versionLabel: String {
        spotify.rekordboxStatus.runningVersion
            ?? spotify.rekordboxStatus.installedVersion
            ?? "Version inconnue"
    }

    private var confidenceLabel: String {
        switch spotify.playlistMatch?.confidence {
        case .exact: "Exacte"
        case .probable: "Probable"
        case .partial: "Partielle"
        case .manual: "Manuelle"
        case .notRecognized: "Non reconnue"
        case nil: "Non analysée"
        }
    }

    private var confidenceAccent: Color {
        switch spotify.playlistMatch?.confidence {
        case .exact, .manual: .green
        case .probable: .cyan
        case .partial: .orange
        case .notRecognized, nil: .gray
        }
    }

    private var sourceLabel: String {
        switch spotify.rekordboxLibrarySource {
        case .accessibility: "Accessibilité"
        case .visibleText: "Texte visible"
        case .freshOCR: "OCR actuel"
        case .cachedOCR: "Cache OCR informatif"
        case .spotifyAPI: "API Spotify"
        case nil: "Aucune"
        }
    }

    private var freshnessLabel: String {
        guard let source = spotify.rekordboxLibrarySource else { return "Aucune observation" }
        let seconds = max(0, Date().timeIntervalSince(source.date))
        return seconds < 2 ? "À l’instant" : "Il y a \(Int(seconds)) s"
    }

    private var statusNoticeKind: MixPilotNotice.Kind {
        if case .failed = spotify.connectionState { return .warning }
        return .info
    }
}
#endif
