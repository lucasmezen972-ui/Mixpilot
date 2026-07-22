#if os(macOS)
import AppKit
import MixPilotCore
import MixPilotSystem
import SwiftUI

struct SpotifyLibraryView: View {
    @ObservedObject var spotify: SpotifyLibraryCoordinator
    @ObservedObject var model: AppModel

    @State private var manualPlaylistID = ""
    @State private var showsAdvancedDetails = false
    @State private var showsTracks = false

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    workflowOverview
                    controlGrid
                    matchSection
                    tracksSection
                    advancedSection

                    MixPilotNotice(
                        title: statusNoticeTitle,
                        message: spotify.statusMessage,
                        kind: statusNoticeKind
                    )
                }
                .padding(24)
                .padding(.bottom, 16)
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
        .animation(.snappy(duration: 0.24), value: spotify.connectionState)
        .animation(.snappy(duration: 0.24), value: spotify.playlistMatch?.confidence)
    }

    private var hero: some View {
        MixPilotSectionHero(
            eyebrow: "Bibliothèque DJ",
            title: "Préparer Spotify pour Rekordbox",
            subtitle: "Connecte ton compte, affiche la playlist dans Rekordbox, puis laisse MixPilot vérifier l’association avant de préparer le Live.",
            symbol: "music.note.tv.fill",
            accent: primaryAccent
        ) {
            Button {
                performPrimaryAction()
            } label: {
                Label(primaryActionTitle, systemImage: primaryActionSymbol)
            }
            .buttonStyle(MixPilotPrimaryButtonStyle(accent: primaryAccent))
            .disabled(primaryActionDisabled)

            if spotify.connectionState.isConnected {
                Button {
                    Task {
                        do {
                            try await spotify.synchronizeLibrary()
                        } catch {
                            spotify.statusMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Actualiser", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                .disabled(isBusy)
            }
        }
    }

    private var workflowOverview: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 250), spacing: 12)],
            spacing: 12
        ) {
            workflowStep(
                number: 1,
                title: "Compte Spotify",
                detail: spotify.connectionState.isConnected
                    ? (spotify.accountName ?? "Compte connecté")
                    : "Client ID et connexion sécurisée",
                completed: spotify.connectionState.isConnected,
                active: !spotify.connectionState.isConnected,
                warning: connectionFailed
            )

            workflowStep(
                number: 2,
                title: "Playlist dans Rekordbox",
                detail: spotify.rekordboxStatus.isRunning
                    ? "Rekordbox \(versionLabel) est prêt"
                    : (spotify.rekordboxStatus.isInstalled
                        ? "Rekordbox est installé mais fermé"
                        : "Rekordbox n’a pas encore été trouvé"),
                completed: spotify.rekordboxStatus.isRunning,
                active: spotify.connectionState.isConnected && !spotify.rekordboxStatus.isRunning,
                warning: spotify.connectionState.isConnected && !spotify.rekordboxStatus.isInstalled
            )

            workflowStep(
                number: 3,
                title: "Vérification Live",
                detail: matchStepDetail,
                completed: matchIsReady,
                active: spotify.rekordboxStatus.isRunning && !matchIsReady,
                warning: spotify.playlistMatch?.confidence == .notRecognized
            )
        }
    }

    private var controlGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 430), spacing: 16)],
            spacing: 16
        ) {
            spotifyControlCard
            rekordboxControlCard
        }
    }

    private var spotifyControlCard: some View {
        MixPilotGlassCard(accent: .green, elevation: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    MixPilotPanelTitle(
                        title: "Spotify",
                        symbol: "music.note",
                        subtitle: "Connexion officielle OAuth PKCE. Aucun mot de passe ni Client Secret n’est stocké par MixPilot.",
                        accent: .green
                    )
                    Spacer()
                    MixPilotStatusBadge(
                        title: connectionLabel,
                        symbol: connectionSymbol,
                        accent: connectionAccent
                    )
                }

                if !spotify.connectionState.isConnected {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Client ID de l’application Spotify")
                            .font(.caption.bold())
                            .foregroundStyle(MixPilotPalette.textSecondary)
                        TextField("Ex. 4f3…", text: $spotify.clientID)
                            .textFieldStyle(.roundedBorder)
                        Text("Le redirect URI à enregistrer dans Spotify est : mixpilot-spotify://callback")
                            .font(.caption)
                            .foregroundStyle(MixPilotPalette.textTertiary)
                            .textSelection(.enabled)
                    }

                    Button {
                        spotify.connect()
                    } label: {
                        Label("Connecter mon compte Spotify", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                    .disabled(spotify.clientID.isEmpty || isBusy)
                } else {
                    connectedSpotifyContent
                }
            }
        }
    }

    private var connectedSpotifyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.14))
                    Image(systemName: "person.fill.checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(spotify.accountName ?? "Compte Spotify")
                        .font(.headline)
                    Text("\(spotify.playlists.count) playlist(s) synchronisée(s)")
                        .font(.caption)
                        .foregroundStyle(MixPilotPalette.textTertiary)
                }
                Spacer()
                Button("Déconnecter") { spotify.disconnect() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
            }

            Divider().overlay(.white.opacity(0.08))

            Picker(
                "Playlist à préparer",
                selection: Binding(
                    get: { spotify.selectedPlaylistID ?? "" },
                    set: { value in
                        guard !value.isEmpty else { return }
                        Task { await spotify.selectPlaylist(value) }
                    }
                )
            ) {
                Text("Choisir une playlist").tag("")
                ForEach(spotify.playlists) { playlist in
                    Text("\(playlist.name) — \(playlist.itemCount) titres")
                        .tag(playlist.id)
                }
            }

            if let playlist = spotify.selectedPlaylist {
                HStack(spacing: 10) {
                    compactFact(
                        title: "Titres",
                        value: "\(playlist.itemCount)",
                        symbol: "music.note.list",
                        accent: .green
                    )
                    compactFact(
                        title: "Chargés",
                        value: "\(spotify.selectedTracks.count)",
                        symbol: "checkmark.circle",
                        accent: .cyan
                    )
                    compactFact(
                        title: "Type",
                        value: playlist.isLikedSongs ? "Likés" : (playlist.isCollaborative ? "Partagée" : "Playlist"),
                        symbol: playlist.isLikedSongs ? "heart.fill" : "rectangle.stack.fill",
                        accent: playlist.isLikedSongs ? .pink : .purple
                    )
                }

                Button {
                    Task {
                        do {
                            try await spotify.synchronizeSelectedPlaylist()
                        } catch {
                            spotify.statusMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Resynchroniser cette playlist", systemImage: "arrow.clockwise")
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                .disabled(isBusy)
            }
        }
    }

    private var rekordboxControlCard: some View {
        MixPilotGlassCard(accent: .cyan, elevation: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    MixPilotPanelTitle(
                        title: "Rekordbox",
                        symbol: "record.circle",
                        subtitle: "MixPilot observe uniquement la fenêtre visible pour reconnaître la playlist active et confirmer les titres.",
                        accent: .cyan
                    )
                    Spacer()
                    MixPilotStatusBadge(
                        title: rekordboxStatusLabel,
                        symbol: spotify.rekordboxStatus.isRunning ? "play.circle.fill" : "pause.circle",
                        accent: spotify.rekordboxStatus.isRunning ? .green : .orange
                    )
                }

                HStack(spacing: 10) {
                    permissionPill(
                        "Accessibilité",
                        granted: spotify.rekordboxWindowObservation?.accessibilityGranted == true
                    )
                    permissionPill(
                        "Capture",
                        granted: CGPreflightScreenCaptureAccess()
                    )
                    permissionPill(
                        "Fenêtre",
                        granted: spotify.rekordboxWindowObservation?.windowTitle != nil
                    )
                }

                if spotify.rekordboxStatus.isRunning {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(spotify.rekordboxWindowObservation?.windowTitle ?? "Rekordbox est ouvert")
                            .font(.headline)
                            .lineLimit(2)
                        Text("Version \(versionLabel) • \(spotify.visibleRows.count) ligne(s) visibles • source \(sourceLabel.lowercased())")
                            .font(.caption)
                            .foregroundStyle(MixPilotPalette.textTertiary)
                    }
                } else {
                    MixPilotNotice(
                        title: spotify.rekordboxStatus.isInstalled ? "Rekordbox est prêt à être ouvert" : "Rekordbox introuvable",
                        message: spotify.rekordboxStatus.isInstalled
                            ? "Ouvre Rekordbox, affiche la rubrique Spotify et sélectionne ta playlist."
                            : "Installe Rekordbox 6 ou 7, puis relance la détection.",
                        kind: .info
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await spotify.openRekordbox() }
                    } label: {
                        Label(
                            spotify.rekordboxStatus.isRunning ? "Revenir à Rekordbox" : "Ouvrir Rekordbox",
                            systemImage: "arrow.up.forward.app"
                        )
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .cyan))

                    Button {
                        spotify.refreshRekordbox()
                    } label: {
                        Label("Actualiser", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())

                    Button {
                        Task { await spotify.detectVisibleRekordboxPlaylist() }
                    } label: {
                        Label("Analyser", systemImage: "viewfinder")
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                    .disabled(!spotify.rekordboxStatus.isRunning || !spotify.connectionState.isConnected)
                }
            }
        }
    }

    private var matchSection: some View {
        MixPilotGlassCard(accent: confidenceAccent, elevation: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    MixPilotPanelTitle(
                        title: "Vérification avant Live",
                        symbol: "checkmark.shield.fill",
                        subtitle: "MixPilot ne considère jamais le simple mot “Spotify” comme une preuve. Le nom et les titres visibles doivent correspondre.",
                        accent: confidenceAccent
                    )
                    Spacer()
                    MixPilotStatusBadge(
                        title: confidenceLabel,
                        symbol: matchIsReady ? "checkmark.seal.fill" : "questionmark.diamond.fill",
                        accent: confidenceAccent
                    )
                }

                HStack(spacing: 12) {
                    matchIdentity(
                        eyebrow: "VISIBLE DANS REKORDBOX",
                        title: spotify.playlistMatch?.visiblePlaylistName ?? "Playlist non reconnue",
                        symbol: "eye.fill",
                        accent: .cyan
                    )

                    Image(systemName: "arrow.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(confidenceAccent)

                    matchIdentity(
                        eyebrow: "PLAYLIST SPOTIFY",
                        title: spotify.matchedPlaylist?.name
                            ?? spotify.selectedPlaylist?.name
                            ?? "Aucune playlist sélectionnée",
                        symbol: "music.note",
                        accent: .green
                    )
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Niveau de confiance")
                            .font(.caption.bold())
                            .foregroundStyle(MixPilotPalette.textSecondary)
                        Spacer()
                        Text("\(confidencePercent) %")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(confidenceAccent)
                    }
                    ProgressView(value: Double(confidencePercent), total: 100)
                        .tint(confidenceAccent)
                }

                if !matchIsReady {
                    HStack(alignment: .bottom, spacing: 10) {
                        Picker("Association manuelle", selection: $manualPlaylistID) {
                            Text("Choisir une playlist…").tag("")
                            ForEach(spotify.playlists) { playlist in
                                Text(playlist.name).tag(playlist.id)
                            }
                        }

                        Button("Associer") {
                            guard !manualPlaylistID.isEmpty else { return }
                            Task {
                                await spotify.associateVisiblePlaylistManually(
                                    with: manualPlaylistID
                                )
                            }
                        }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                        .disabled(manualPlaylistID.isEmpty)
                    }
                }

                HStack(spacing: 10) {
                    if spotify.playlistMatch != nil {
                        Button("Retirer l’association") {
                            Task { await spotify.removeManualAssociation() }
                        }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    }

                    Spacer()

                    Button {
                        Task { await prepareForLive() }
                    } label: {
                        Label("Préparer cette playlist pour le Live", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                    .disabled(spotify.selectedPlaylist == nil || spotify.selectedTracks.count < 2)
                }
            }
        }
    }

    private var tracksSection: some View {
        MixPilotGlassCard(accent: .purple, elevation: .flat) {
            DisclosureGroup(isExpanded: $showsTracks) {
                VStack(alignment: .leading, spacing: 4) {
                    if spotify.selectedTracks.isEmpty {
                        Text("Aucun titre n’est chargé pour le moment.")
                            .foregroundStyle(MixPilotPalette.textTertiary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(
                            Array(spotify.selectedTracks.prefix(40).enumerated()),
                            id: \.element.id
                        ) { index, track in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(MixPilotPalette.textTertiary)
                                    .frame(width: 32, alignment: .trailing)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.callout.bold())
                                        .lineLimit(1)
                                    Text(track.artistText)
                                        .font(.caption)
                                        .foregroundStyle(MixPilotPalette.textTertiary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(track.duration.formattedDuration)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(MixPilotPalette.textSecondary)
                            }
                            .padding(.vertical, 5)

                            if index < min(39, spotify.selectedTracks.count - 1) {
                                Divider().overlay(.white.opacity(0.05))
                            }
                        }

                        if spotify.selectedTracks.count > 40 {
                            Text("Et \(spotify.selectedTracks.count - 40) autre(s) titre(s)…")
                                .font(.caption)
                                .foregroundStyle(MixPilotPalette.textTertiary)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(.top, 14)
            } label: {
                HStack {
                    MixPilotPanelTitle(
                        title: "Titres synchronisés",
                        symbol: "list.number",
                        subtitle: "\(spotify.selectedTracks.count) titre(s) chargé(s). L’aperçu est limité à 40 titres pour garder l’interface fluide.",
                        accent: .purple
                    )
                    Spacer()
                }
            }
        }
    }

    private var advancedSection: some View {
        MixPilotGlassCard(accent: .gray, elevation: .flat) {
            DisclosureGroup(isExpanded: $showsAdvancedDetails) {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220), spacing: 10)],
                        spacing: 10
                    ) {
                        detailRow("Version Rekordbox", versionLabel)
                        detailRow("PID", spotify.rekordboxStatus.processIdentifier.map(String.init) ?? "—")
                        detailRow("Chemin", spotify.rekordboxStatus.applicationURL?.path ?? "—")
                        detailRow("Bundle ID", spotify.rekordboxStatus.bundleIdentifier ?? "—")
                        detailRow("Fenêtre", spotify.rekordboxWindowObservation?.windowTitle ?? "Non détectée")
                        detailRow("Source", sourceLabel)
                        detailRow("Fraîcheur", freshnessLabel)
                        detailRow("Lignes visibles", "\(spotify.visibleRows.count)")
                        detailRow("Titres reconnus", "\(spotify.playlistMatch?.matchedTrackIDs.count ?? 0)")
                        detailRow("Titres non reconnus", "\(spotify.playlistMatch?.unmatchedTrackIDs.count ?? 0)")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Client ID Spotify")
                            .font(.caption.bold())
                            .foregroundStyle(MixPilotPalette.textSecondary)
                        TextField("Client ID", text: $spotify.clientID)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 10) {
                        Button("Réglages des autorisations") { openPrivacySettings() }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                        Button("Exporter le diagnostic") { spotify.exportRekordboxDiagnostic() }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                    }
                }
                .padding(.top, 14)
            } label: {
                MixPilotPanelTitle(
                    title: "Détails avancés",
                    symbol: "wrench.and.screwdriver.fill",
                    subtitle: "Permissions, chemin de l’application, source d’observation et diagnostic exportable.",
                    accent: .gray
                )
            }
        }
    }

    private func workflowStep(
        number: Int,
        title: String,
        detail: String,
        completed: Bool,
        active: Bool,
        warning: Bool
    ) -> some View {
        let accent: Color = warning ? .orange : (completed ? .green : (active ? .cyan : .gray))
        let symbol = warning ? "exclamationmark.triangle.fill" : (completed ? "checkmark" : "\(number)")

        return MixPilotGlassCard(
            cornerRadius: 16,
            padding: 14,
            accent: accent,
            elevation: active ? .standard : .flat,
            interactive: true
        ) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.14))
                    if completed || warning {
                        Image(systemName: symbol)
                            .font(.system(size: 14, weight: .bold))
                    } else {
                        Text(symbol)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(accent)
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(MixPilotPalette.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        }
    }

    private func compactFact(
        title: String,
        value: String,
        symbol: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(MixPilotPalette.textTertiary)
                Text(value)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
    }

    private func permissionPill(_ title: String, granted: Bool) -> some View {
        Label(
            title,
            systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        )
        .font(.caption.bold())
        .foregroundStyle(granted ? Color.green : Color.orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            (granted ? Color.green : Color.orange).opacity(0.09),
            in: Capsule()
        )
    }

    private func matchIdentity(
        eyebrow: String,
        title: String,
        symbol: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(eyebrow, systemImage: symbol)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(accent)
            Text(title)
                .font(.headline)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(MixPilotPalette.textTertiary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        .padding(10)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private func performPrimaryAction() {
        switch spotify.connectionState {
        case .disconnected, .failed:
            spotify.connect()
        case .connecting, .synchronizing:
            break
        case .connected:
            if spotify.rekordboxStatus.isRunning {
                Task { await spotify.detectVisibleRekordboxPlaylist() }
            } else {
                Task { await spotify.openRekordbox() }
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
            spotify.statusMessage = "Playlist prête. MixPilot a conservé les avertissements utiles pour la vérification avant Live."
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

    private var isBusy: Bool {
        switch spotify.connectionState {
        case .connecting, .synchronizing: true
        case .disconnected, .connected, .failed: false
        }
    }

    private var connectionFailed: Bool {
        if case .failed = spotify.connectionState { return true }
        return false
    }

    private var primaryActionTitle: String {
        switch spotify.connectionState {
        case .disconnected, .failed:
            "Connecter Spotify"
        case .connecting:
            "Connexion…"
        case .synchronizing:
            "Synchronisation…"
        case .connected:
            spotify.rekordboxStatus.isRunning ? "Analyser la playlist" : "Ouvrir Rekordbox"
        }
    }

    private var primaryActionSymbol: String {
        switch spotify.connectionState {
        case .disconnected, .failed: "person.crop.circle.badge.plus"
        case .connecting, .synchronizing: "arrow.triangle.2.circlepath"
        case .connected:
            spotify.rekordboxStatus.isRunning ? "viewfinder" : "arrow.up.forward.app"
        }
    }

    private var primaryActionDisabled: Bool {
        isBusy || (!spotify.connectionState.isConnected && spotify.clientID.isEmpty)
    }

    private var primaryAccent: Color {
        if connectionFailed { return .orange }
        if spotify.connectionState.isConnected && spotify.rekordboxStatus.isRunning {
            return confidenceAccent
        }
        return spotify.connectionState.isConnected ? .cyan : .green
    }

    private var connectionLabel: String {
        switch spotify.connectionState {
        case .disconnected: "Non connecté"
        case .connecting: "Connexion"
        case .connected: "Connecté"
        case .synchronizing: "Synchronisation"
        case .failed: "À corriger"
        }
    }

    private var connectionSymbol: String {
        switch spotify.connectionState {
        case .disconnected: "person.crop.circle.badge.xmark"
        case .connecting, .synchronizing: "arrow.triangle.2.circlepath"
        case .connected: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var connectionAccent: Color {
        switch spotify.connectionState {
        case .connected: .green
        case .connecting, .synchronizing: .cyan
        case .disconnected: .gray
        case .failed: .orange
        }
    }

    private var rekordboxStatusLabel: String {
        if spotify.rekordboxStatus.isRunning { return "Ouvert" }
        if spotify.rekordboxStatus.isInstalled { return "Installé" }
        return "Introuvable"
    }

    private var versionLabel: String {
        spotify.rekordboxStatus.runningVersion
            ?? spotify.rekordboxStatus.installedVersion
            ?? "Inconnue"
    }

    private var confidenceLabel: String {
        switch spotify.playlistMatch?.confidence {
        case .exact: "Correspondance exacte"
        case .probable: "À confirmer"
        case .partial: "Partielle"
        case .manual: "Association manuelle"
        case .notRecognized: "Non reconnue"
        case nil: "Pas encore analysée"
        }
    }

    private var confidenceAccent: Color {
        switch spotify.playlistMatch?.confidence {
        case .exact, .manual: .green
        case .probable: .cyan
        case .partial: .orange
        case .notRecognized: .red
        case nil: .gray
        }
    }

    private var confidencePercent: Int {
        Int((spotify.playlistMatch?.confidenceScore ?? 0) * 100)
    }

    private var matchIsReady: Bool {
        switch spotify.playlistMatch?.confidence {
        case .exact, .manual: true
        case .probable, .partial, .notRecognized, nil: false
        }
    }

    private var matchStepDetail: String {
        if matchIsReady {
            return spotify.matchedPlaylist?.name ?? "Association confirmée"
        }
        if spotify.playlistMatch != nil {
            return "\(confidenceLabel) • \(confidencePercent) %"
        }
        return "Analyse de la playlist visible"
    }

    private var sourceLabel: String {
        switch spotify.rekordboxLibrarySource {
        case .accessibility: "Accessibilité"
        case .visibleText: "Texte visible"
        case .freshOCR: "OCR actuel"
        case .cachedOCR: "Cache OCR"
        case .spotifyAPI: "API Spotify"
        case nil: "Aucune"
        }
    }

    private var freshnessLabel: String {
        guard let source = spotify.rekordboxLibrarySource else {
            return "Aucune observation"
        }
        let seconds = max(0, Date().timeIntervalSince(source.date))
        return seconds < 2 ? "À l’instant" : "Il y a \(Int(seconds)) s"
    }

    private var statusNoticeTitle: String {
        connectionFailed ? "Action nécessaire" : "État actuel"
    }

    private var statusNoticeKind: MixPilotNotice.Kind {
        connectionFailed ? .warning : .info
    }
}

private extension TimeInterval {
    var formattedDuration: String {
        guard isFinite, self > 0 else { return "—" }
        let totalSeconds = Int(self.rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
#endif
