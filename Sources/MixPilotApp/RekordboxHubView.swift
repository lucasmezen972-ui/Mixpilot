#if os(macOS)
import AppKit
import MixPilotCore
import MixPilotSystem
import SwiftUI
import UniformTypeIdentifiers

private actor RekordboxHubFileStore {
    func importLibrary(
        at url: URL,
        installedVersion: String?
    ) throws -> RekordboxLibraryImportResult {
        let data = try Data(contentsOf: url)
        return try RekordboxLibraryImporter().importData(
            data,
            fileExtension: url.pathExtension,
            installedVersion: installedVersion
        )
    }

    func writeAndVerify(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == data else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

@MainActor
final class RekordboxHubModel: ObservableObject {
    @Published private(set) var importResult: RekordboxLibraryImportResult?
    @Published private(set) var sourceFilename: String?
    @Published private(set) var status = "Prêt à connecter rekordbox"
    @Published private(set) var isWorking = false
    @Published private(set) var rekordboxRunning = false
    @Published private(set) var rekordboxVersion: String?
    @Published private(set) var lastPreset: RekordboxAdvancedMIDIPreset?
    @Published private(set) var presetURL: URL?

    private let fileStore = RekordboxHubFileStore()

    init() {
        refreshEnvironment()
    }

    func refreshEnvironment() {
        let application = NSWorkspace.shared.runningApplications.first { app in
            RekordboxApplicationMatcher.matches(
                name: app.localizedName,
                bundleIdentifier: app.bundleIdentifier
            )
        }
        rekordboxRunning = application != nil
        if let bundleURL = application?.bundleURL,
           let bundle = Bundle(url: bundleURL) {
            rekordboxVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        } else {
            rekordboxVersion = nil
        }
        status = rekordboxRunning
            ? "rekordbox \(rekordboxVersion.map { "v\($0)" } ?? "") détecté"
            : "rekordbox n’est pas lancé — l’import de fichiers reste disponible"
    }

    func chooseLibraryFile() {
        let panel = NSOpenPanel()
        panel.title = "Importer une bibliothèque rekordbox"
        panel.message = "Choisis un export XML officiel ou un JSON issu de rekordbox-connect, pyrekordbox/MCP ou OneLibrary."
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        var types: [UTType] = [.json]
        if let xml = UTType(filenameExtension: "xml") { types.append(xml) }
        panel.allowedContentTypes = types
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importLibrary(at: url)
    }

    func importLibrary(at url: URL) {
        guard !isWorking else { return }
        isWorking = true
        status = "Import de \(url.lastPathComponent)…"
        let installedVersion = rekordboxVersion

        let fileStore = self.fileStore
        Task { @MainActor [weak self, fileStore] in
            guard let self else { return }
            defer { isWorking = false }
            do {
                let result = try await fileStore.importLibrary(
                    at: url,
                    installedVersion: installedVersion
                )
                importResult = result
                sourceFilename = url.lastPathComponent
                status = "\(result.tracks.count) titre(s), \(result.playlists.count) playlist(s) • \(result.source.displayName)"
            } catch {
                importResult = nil
                sourceFilename = nil
                status = "Import refusé : \(error.localizedDescription)"
            }
        }
    }

    func generatePreset(profile: MIDIMappingProfile) {
        isWorking = true
        defer { isWorking = false }
        do {
            lastPreset = try RekordboxAdvancedMIDIPresetGenerator().generate(profile: profile)
            presetURL = nil
            status = "Preset avancé généré • \(lastPreset?.base.supportedActions.count ?? 0) commandes de base + \(lastPreset?.addedActions.count ?? 0) avancées"
        } catch {
            lastPreset = nil
            presetURL = nil
            status = "Génération impossible : \(error.localizedDescription)"
        }
    }

    func exportPreset(profile: MIDIMappingProfile) {
        guard !isWorking else { return }
        if lastPreset == nil { generatePreset(profile: profile) }
        guard let preset = lastPreset else { return }
        let panel = NSSavePanel()
        panel.title = "Exporter le mapping rekordbox avancé"
        panel.nameFieldStringValue = "MixPilot Virtual Controller Advanced.midi.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isWorking = true
        status = "Export et vérification de \(url.lastPathComponent)…"
        let data = Data(preset.csv.utf8)
        let fileStore = self.fileStore
        Task { @MainActor [weak self, fileStore] in
            guard let self else { return }
            defer { isWorking = false }
            do {
                try await fileStore.writeAndVerify(data, to: url)
                presetURL = url
                NSWorkspace.shared.activateFileViewerSelecting([url])
                status = "Preset exporté et vérifié : \(url.lastPathComponent)"
            } catch {
                status = "Échec de l’export : \(error.localizedDescription)"
            }
        }
    }

}

private enum RekordboxHubSection: String, CaseIterable, Identifiable {
    case overview = "Vue d’ensemble"
    case library = "Bibliothèque"
    case mapping = "Mapping"
    case compatibility = "Compatibilité"
    case control = "Contrôle"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: "sparkles.rectangle.stack"
        case .library: "music.note.list"
        case .mapping: "slider.horizontal.3"
        case .compatibility: "square.stack.3d.up"
        case .control: "play.square.stack"
        }
    }
}

struct RekordboxHubView: View {
    @ObservedObject var appModel: AppModel
    @StateObject private var hub = RekordboxHubModel()
    @Environment(\.openWindow) private var openWindow
    @State private var section: RekordboxHubSection = .overview
    @State private var searchText = ""
    @State private var controlsArmed = false

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            VStack(spacing: 0) {
                hubHeader
                HStack(spacing: 0) {
                    sidebar
                    detail
                }
            }
        }
        .mixPilotWindowSurface(minWidth: 1_180, minHeight: 790)
        .onAppear { hub.refreshEnvironment() }
    }

    private var hubHeader: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.86), .indigo.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.20), lineWidth: 1)
                    }
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
            .shadow(color: .blue.opacity(0.20), radius: 16, y: 7)

            VStack(alignment: .leading, spacing: 4) {
                Text("REKORDBOX HUB")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(.cyan)
                Text("Compatibilité et préparation")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .tracking(-0.2)
                Text("Bibliothèque • Mapping MIDI • Contrôle réel • Diagnostics")
                    .font(.caption)
                    .foregroundStyle(MixPilotPalette.textTertiary)
            }

            Spacer(minLength: 16)

            MixPilotStatusBadge(
                title: hub.rekordboxRunning ? "rekordbox connecté" : "rekordbox hors ligne",
                symbol: hub.rekordboxRunning ? "checkmark.circle.fill" : "circle.dashed",
                accent: hub.rekordboxRunning ? .green : .orange
            )

            Button {
                hub.refreshEnvironment()
            } label: {
                Label("ACTUALISER", systemImage: "arrow.clockwise")
            }
            .buttonStyle(MixPilotSecondaryButtonStyle())
            .disabled(hub.isWorking)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.18), .black.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.blue.opacity(0.30), .cyan.opacity(0.12), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            MixPilotSidebarHeader(
                eyebrow: "Espace rekordbox",
                title: "Centre de contrôle",
                subtitle: hub.rekordboxVersion.map { "Version \($0) détectée" } ?? "Version à détecter",
                accent: .blue,
                symbol: "record.circle"
            )
            .padding(.horizontal, 8)
            .padding(.top, 8)

            VStack(spacing: 5) {
                ForEach(RekordboxHubSection.allCases) { item in
                    sidebarButton(item)
                }
            }

            Spacer(minLength: 12)

            MixPilotGlassCard(cornerRadius: 14, padding: 12, accent: hub.rekordboxRunning ? .green : .orange, elevation: .flat) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        MixPilotStatusBadge(
                            title: hub.isWorking ? "Traitement" : "État",
                            symbol: hub.isWorking ? "arrow.triangle.2.circlepath" : "waveform.path.ecg",
                            accent: hub.isWorking ? .cyan : (hub.rekordboxRunning ? .green : .orange)
                        )
                        Spacer()
                        if hub.isWorking {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.cyan)
                        }
                    }
                    Text(hub.status)
                        .font(.caption)
                        .foregroundStyle(MixPilotPalette.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(5)
                }
            }
            .padding(.bottom, 82)
        }
        .padding(14)
        .frame(width: 252)
        .mixPilotSidebarSurface()
    }

    private func sidebarButton(_ item: RekordboxHubSection) -> some View {
        let selected = section == item
        return Button {
            withAnimation(.snappy(duration: 0.24)) {
                section = item
            }
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selected ? .blue.opacity(0.16) : .white.opacity(0.035))
                    Image(systemName: item.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? .cyan : .white.opacity(0.52))
                }
                .frame(width: 32, height: 32)

                Text(item.rawValue)
                    .font(.system(size: 12, weight: selected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(selected ? .white : .white.opacity(0.64))
                Spacer()
                if selected {
                    Circle()
                        .fill(.cyan)
                        .frame(width: 6, height: 6)
                        .shadow(color: .cyan.opacity(0.60), radius: 6)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                selected ? .white.opacity(0.075) : .clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            Group {
                switch section {
                case .overview: overview
                case .library: library
                case .mapping: mapping
                case .compatibility: compatibility
                case .control: control
                }
            }
            .padding(28)
            .padding(.bottom, 100)
            .frame(maxWidth: 1_100, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.hidden)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            MixPilotSectionHero(
                eyebrow: "Centre de pilotage",
                title: "Prêt pour rekordbox",
                subtitle: "MixPilot choisit le chemin le plus sûr selon la version installée, les fichiers disponibles et les validations déjà réalisées.",
                symbol: "record.circle.fill",
                accent: .blue
            ) {
                Button("IMPORTER") {
                    hub.chooseLibraryFile()
                    section = .library
                }
                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .blue))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 14)], spacing: 14) {
                MixPilotMetricTile(
                    title: "Version détectée",
                    value: hub.rekordboxVersion ?? "À détecter",
                    symbol: "app.badge.checkmark",
                    accent: .cyan
                )
                MixPilotMetricTile(
                    title: "Formats bibliothèque",
                    value: "XML + 4 JSON",
                    symbol: "doc.on.doc.fill",
                    accent: .purple
                )
                MixPilotMetricTile(
                    title: "Commandes répertoriées",
                    value: "\(RekordboxExtendedCommandCatalog.commands.count)",
                    symbol: "dial.medium.fill",
                    accent: .blue
                )
                MixPilotMetricTile(
                    title: "Couverture Runtime",
                    value: "\(Int(RekordboxExtendedCommandCatalog.runtimeCoverage * 100)) %",
                    symbol: "bolt.horizontal.circle.fill",
                    accent: .mint
                )
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], spacing: 16) {
                MixPilotGlassCard(accent: .cyan) {
                    VStack(alignment: .leading, spacing: 14) {
                        MixPilotPanelTitle(
                            title: "Parcours recommandé",
                            symbol: "point.topleft.down.to.point.bottomright.curvepath",
                            subtitle: "Progression réelle avant le premier Live",
                            accent: .cyan
                        )
                        MixPilotSectionDivider(accent: .cyan)
                        readinessStep(1, "Importer la bibliothèque", completed: hub.importResult != nil)
                        readinessStep(2, "Vérifier Spotify et la version", completed: hub.importResult?.spotifyCapability.isEligible == true)
                        readinessStep(3, "Exporter le preset MIDI", completed: hub.presetURL != nil)
                        readinessStep(4, "Tester Load, Play et Sync", completed: false)
                        readinessStep(5, "Valider une répétition complète", completed: false)
                    }
                }

                MixPilotGlassCard(accent: .purple) {
                    VStack(alignment: .leading, spacing: 14) {
                        MixPilotPanelTitle(
                            title: "Actions rapides",
                            symbol: "bolt.fill",
                            subtitle: "Les opérations les plus utiles, sans navigation inutile",
                            accent: .purple
                        )
                        Button("IMPORTER XML OU JSON") {
                            hub.chooseLibraryFile()
                            section = .library
                        }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                        Button("GÉNÉRER LE MAPPING AVANCÉ") {
                            hub.generatePreset(profile: appModel.mappingProfile)
                            section = .mapping
                        }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                        Button("OUVRIR LE CONTRÔLE RÉEL") {
                            openWindow(id: "rekordbox-compatibility")
                        }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    }
                }
            }

            if let result = hub.importResult {
                importSummary(result)
            } else {
                MixPilotNotice(
                    title: "Bibliothèque non importée",
                    message: "L’import reste volontairement séparé de rekordbox : MixPilot lit un export XML ou JSON et n’écrit jamais dans la base de la bibliothèque pendant le Live.",
                    kind: .info
                )
            }
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 20) {
            MixPilotSectionHero(
                eyebrow: "Bibliothèque unifiée",
                title: "Import rekordbox adaptatif",
                subtitle: "Les champs inconnus sont conservés dans un rapport au lieu de faire échouer l’import. Les fichiers sources restent intacts.",
                symbol: "music.note.list",
                accent: .purple
            ) {
                Button("CHOISIR UN FICHIER") {
                    hub.chooseLibraryFile()
                }
                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
            }

            Button {
                hub.chooseLibraryFile()
            } label: {
                MixPilotGlassCard(cornerRadius: 20, padding: 20, accent: .cyan, elevation: .elevated, interactive: true) {
                    HStack(spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(.cyan.opacity(0.12))
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.cyan)
                        }
                        .frame(width: 58, height: 58)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(hub.sourceFilename ?? "Choisir un XML ou un JSON rekordbox")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("XML officiel • rekordbox-connect • MCP/pyrekordbox • OneLibrary • JSON adaptatif")
                                .font(.caption)
                                .foregroundStyle(MixPilotPalette.textTertiary)
                        }
                        Spacer()
                        MixPilotStatusBadge(title: "Importer", symbol: "arrow.right.circle.fill", accent: .cyan)
                    }
                }
            }
            .buttonStyle(.plain)

            if let result = hub.importResult {
                importSummary(result)

                HStack(spacing: 12) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.cyan)
                        TextField("Rechercher un titre, un artiste, un album ou un genre", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .mixPilotInputStyle()

                    MixPilotStatusBadge(
                        title: "\(filteredTracks(result).count) résultat(s)",
                        symbol: "list.number",
                        accent: .cyan
                    )
                }

                trackTable(result)

                if !result.playlists.isEmpty {
                    playlistList(result)
                }
            } else {
                MixPilotEmptyState(
                    title: "Aucune bibliothèque importée",
                    message: "Lance un import pour voir les pistes, playlists, cues, BPM, tonalités et sources de streaming.",
                    symbol: "music.note.list",
                    accent: .purple
                ) {
                    Button("IMPORTER UNE BIBLIOTHÈQUE") {
                        hub.chooseLibraryFile()
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                }
            }
        }
    }

    private func trackTable(_ result: RekordboxLibraryImportResult) -> some View {
        MixPilotGlassCard(accent: .blue) {
            VStack(spacing: 0) {
                HStack {
                    Text("TITRE").frame(maxWidth: .infinity, alignment: .leading)
                    Text("BPM").frame(width: 70, alignment: .trailing)
                    Text("KEY").frame(width: 70, alignment: .trailing)
                    Text("SOURCE").frame(width: 105, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(MixPilotPalette.textTertiary)
                .padding(.bottom, 10)

                ForEach(Array(filteredTracks(result).prefix(200))) { track in
                    MixPilotSectionDivider(accent: .blue)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.callout.weight(.semibold))
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundStyle(MixPilotPalette.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(track.bpm > 0 ? String(format: "%.1f", track.bpm) : "—")
                            .font(.callout.monospacedDigit())
                            .frame(width: 70, alignment: .trailing)
                        Text(track.key ?? "—")
                            .font(.callout.weight(.medium))
                            .frame(width: 70, alignment: .trailing)
                        Text(track.streamingService ?? "Local")
                            .font(.caption.bold())
                            .foregroundStyle(track.isStreaming ? .green : .white.opacity(0.55))
                            .frame(width: 105, alignment: .trailing)
                    }
                    .padding(.vertical, 9)
                }
            }
        }
    }

    private func playlistList(_ result: RekordboxLibraryImportResult) -> some View {
        MixPilotGlassCard(accent: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                MixPilotPanelTitle(
                    title: "Playlists détectées",
                    symbol: "folder.fill",
                    subtitle: "\(result.playlists.count) playlist(s) dans l’export",
                    accent: .purple
                )
                MixPilotSectionDivider(accent: .purple)
                ForEach(result.playlists.prefix(30)) { playlist in
                    HStack(spacing: 10) {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.purple)
                            .frame(width: 18)
                        Text((playlist.folderPath + [playlist.name]).joined(separator: " / "))
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Text("\(playlist.trackExternalIDs.count)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(MixPilotPalette.textTertiary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private var mapping: some View {
        VStack(alignment: .leading, spacing: 20) {
            MixPilotSectionHero(
                eyebrow: "MIDI Learn",
                title: "Mapping rekordbox avancé",
                subtitle: "Un preset importable, versionné et validé avant écriture. Aucun fichier interne de rekordbox n’est remplacé.",
                symbol: "slider.horizontal.3",
                accent: .blue
            ) {
                Button("ASSISTANT DÉTAILLÉ") {
                    openWindow(id: "automatic-rekordbox-mapping")
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], spacing: 16) {
                MixPilotGlassCard(accent: .cyan) {
                    VStack(alignment: .leading, spacing: 14) {
                        MixPilotPanelTitle(
                            title: "Couverture du preset",
                            symbol: "gauge.with.dots.needle.67percent",
                            subtitle: "Commandes réellement issues des catalogues étudiés",
                            accent: .cyan
                        )
                        let baseCount = hub.lastPreset?.base.supportedActions.count
                            ?? SeratoAction.allCases.filter { RekordboxMIDICommandRegistry.definition(for: $0) != nil }.count
                        Text("\(baseCount) commandes principales")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("Focus de fenêtre et Color FX canal 1/2 sont ajoutés dans le profil avancé.")
                            .font(.callout)
                            .foregroundStyle(MixPilotPalette.textSecondary)
                        ProgressView(value: appModel.mappingProfile.completionRatio)
                            .tint(.cyan)
                    }
                }

                MixPilotGlassCard(accent: .purple) {
                    VStack(alignment: .leading, spacing: 13) {
                        MixPilotPanelTitle(
                            title: "Générer et exporter",
                            symbol: "square.and.arrow.up",
                            subtitle: "Écriture atomique et relecture du fichier exporté",
                            accent: .purple
                        )
                        Button("GÉNÉRER ET EXPORTER") {
                            hub.exportPreset(profile: appModel.mappingProfile)
                        }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                        Button("OUVRIR L’ASSISTANT DÉTAILLÉ") {
                            openWindow(id: "automatic-rekordbox-mapping")
                        }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                        if let url = hub.presetURL {
                            MixPilotNotice(
                                title: "Preset exporté",
                                message: url.path,
                                kind: .success
                            )
                            .textSelection(.enabled)
                        }
                    }
                }
            }

            commandCatalog
        }
    }

    private var commandCatalog: some View {
        MixPilotGlassCard(accent: .blue) {
            VStack(alignment: .leading, spacing: 16) {
                MixPilotPanelTitle(
                    title: "Commandes reconnues",
                    symbol: "list.bullet.rectangle.portrait.fill",
                    subtitle: "Catalogue rekordbox classé par famille",
                    accent: .blue
                )
                let groups = Dictionary(grouping: RekordboxExtendedCommandCatalog.commands, by: \.category)
                ForEach(groups.keys.sorted(), id: \.self) { category in
                    VStack(alignment: .leading, spacing: 9) {
                        Text(category.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.cyan)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                            ForEach(groups[category] ?? []) { command in
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill((command.runtimeWired ? Color.green : Color.orange).opacity(0.12))
                                        Image(systemName: command.runtimeWired ? "checkmark" : "ellipsis")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(command.runtimeWired ? .green : .orange)
                                    }
                                    .frame(width: 26, height: 26)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(command.title)
                                            .font(.caption.bold())
                                        Text(command.csvName)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(MixPilotPalette.textTertiary)
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(.white.opacity(0.040), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                                }
                                .help(command.warning ?? "Commande issue des catalogues rekordbox étudiés.")
                            }
                        }
                    }
                }
            }
        }
    }

    private var compatibility: some View {
        VStack(alignment: .leading, spacing: 20) {
            MixPilotSectionHero(
                eyebrow: "Matrice de compatibilité",
                title: "Le meilleur chemin selon ta version",
                subtitle: "Chaque capacité indique sa source, son niveau de confiance et si elle peut être utilisée pendant un Live.",
                symbol: "square.stack.3d.up.fill",
                accent: .cyan
            ) {
                Button("ACTUALISER") { hub.refreshEnvironment() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 14)], spacing: 14) {
                ForEach(RekordboxCompatibilityCatalog.features) { feature in
                    compatibilityCard(feature)
                }
            }
        }
    }

    private func compatibilityCard(_ feature: RekordboxCompatibilityFeature) -> some View {
        let accent = featureAccent(feature.confidence)
        return MixPilotGlassCard(cornerRadius: 17, padding: 16, accent: accent, interactive: true) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(accent.opacity(0.12))
                        Image(systemName: featureSymbol(feature.route))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 42, height: 42)
                    Spacer()
                    MixPilotStatusBadge(
                        title: feature.confidence.displayName,
                        symbol: feature.confidence == .unavailable ? "xmark.circle.fill" : "checkmark.shield.fill",
                        accent: accent
                    )
                }
                Text(feature.title)
                    .font(.headline)
                Text(feature.detail)
                    .font(.caption)
                    .foregroundStyle(MixPilotPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.5)
                HStack {
                    Text(feature.route.displayName)
                    Spacer()
                    if let version = feature.minimumVersion {
                        Text("≥ \(version)")
                    }
                }
                .font(.caption2.bold())
                .foregroundStyle(MixPilotPalette.textTertiary)
                if !feature.safeDuringLive || feature.requiresRekordboxClosed {
                    MixPilotNotice(
                        title: feature.requiresRekordboxClosed ? "rekordbox doit être fermé" : "Hors Live uniquement",
                        message: "Cette route est protégée pour éviter toute modification risquée pendant une prestation.",
                        kind: .warning
                    )
                }
            }
        }
    }

    private var control: some View {
        VStack(alignment: .leading, spacing: 20) {
            MixPilotSectionHero(
                eyebrow: "Contrôle réel",
                title: "Tester avant d’automatiser",
                subtitle: "Les commandes sont désactivées jusqu’à l’armement manuel. Commence sur une playlist de copie, jamais en public.",
                symbol: "play.square.stack.fill",
                accent: controlsArmed ? .orange : .green
            ) {
                MixPilotStatusBadge(
                    title: controlsArmed ? "Commandes armées" : "Mode sécurisé",
                    symbol: controlsArmed ? "bolt.fill" : "lock.shield.fill",
                    accent: controlsArmed ? .orange : .green
                )
            }

            MixPilotGlassCard(accent: controlsArmed ? .orange : .green, elevation: .elevated) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill((controlsArmed ? Color.orange : Color.green).opacity(0.12))
                        Image(systemName: controlsArmed ? "bolt.fill" : "lock.shield.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(controlsArmed ? .orange : .green)
                    }
                    .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(controlsArmed ? "Commandes autorisées pour ce test" : "Aucune commande ne peut partir")
                            .font(.headline)
                        Text("L’armement est volontairement local et temporaire.")
                            .font(.caption)
                            .foregroundStyle(MixPilotPalette.textTertiary)
                    }
                    Spacer()
                    Toggle("Armer", isOn: $controlsArmed)
                        .toggleStyle(.switch)
                        .tint(.orange)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 410), spacing: 16)], spacing: 16) {
                deckPanel(title: "DECK A", play: .playA, cue: .cueA, sync: .syncA, load: .loadA)
                deckPanel(title: "DECK B", play: .playB, cue: .cueB, sync: .syncB, load: .loadB)
            }

            MixPilotGlassCard(accent: .blue) {
                VStack(alignment: .leading, spacing: 14) {
                    MixPilotPanelTitle(
                        title: "Navigation et mixeur",
                        symbol: "slider.horizontal.below.square.filled.and.square",
                        subtitle: "Commandes globales et Color FX",
                        accent: .blue
                    )
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: 10)], spacing: 10) {
                        controlButton("Fenêtre active", symbol: "rectangle.on.rectangle", action: .browserFocus)
                        controlButton("Titre précédent", symbol: "chevron.up", action: .browserUp)
                        controlButton("Titre suivant", symbol: "chevron.down", action: .browserDown)
                        controlButton("Crossfader centre", symbol: "arrow.left.and.right", action: .crossfader)
                        controlButton("Filtre A centre", symbol: "line.3.horizontal.decrease.circle", action: .filterA)
                        controlButton("Filtre B centre", symbol: "line.3.horizontal.decrease.circle", action: .filterB)
                    }
                    MixPilotNotice(
                        title: "Color FX requis",
                        message: "Les boutons Filtre pilotent CFXParameterCH1/CH2 : sélectionne Filter comme Color FX dans rekordbox avant de les tester.",
                        kind: .warning
                    )
                }
            }

            HStack(spacing: 10) {
                Button("INSPECTER LES CONTRÔLES MACOS") {
                    openWindow(id: "rekordbox-compatibility")
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                Button("OUVRIR LE MAPPING") {
                    openWindow(id: "automatic-rekordbox-mapping")
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                Spacer()
            }
        }
    }

    private func deckPanel(
        title: String,
        play: SeratoAction,
        cue: SeratoAction,
        sync: SeratoAction,
        load: SeratoAction
    ) -> some View {
        MixPilotGlassCard(accent: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                MixPilotPanelTitle(
                    title: title,
                    symbol: "record.circle",
                    subtitle: "Validation commande par commande",
                    accent: .cyan
                )
                HStack(spacing: 10) {
                    controlButton("LOAD", symbol: "arrow.down.to.line", action: load)
                    controlButton("PLAY", symbol: "play.fill", action: play)
                    controlButton("CUE", symbol: "flag.fill", action: cue)
                    controlButton("SYNC", symbol: "arrow.triangle.2.circlepath", action: sync)
                }
            }
        }
    }

    private func controlButton(_ title: String, symbol: String, action: SeratoAction) -> some View {
        Button {
            Task { @MainActor in
                _ = await appModel.testMapping(action)
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((controlsArmed ? Color.cyan : Color.white).opacity(controlsArmed ? 0.12 : 0.035))
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(controlsArmed ? .cyan : .white.opacity(0.30))
                }
                .frame(width: 38, height: 38)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(controlsArmed ? .white : .white.opacity(0.34))
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .background(.white.opacity(controlsArmed ? 0.055 : 0.025), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(controlsArmed ? 0.10 : 0.045), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!controlsArmed)
    }

    private func importSummary(_ result: RekordboxLibraryImportResult) -> some View {
        MixPilotGlassCard(accent: result.spotifyCapability.isEligible ? .green : .orange, elevation: .elevated) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    MixPilotPanelTitle(
                        title: result.source.displayName,
                        symbol: "checkmark.seal.fill",
                        subtitle: [result.productName, result.productVersion].compactMap { $0 }.joined(separator: " • "),
                        accent: result.spotifyCapability.isEligible ? .green : .orange
                    )
                    Spacer()
                    MixPilotStatusBadge(
                        title: result.spotifyCapability.displayName,
                        symbol: result.spotifyCapability.isEligible ? "checkmark.seal.fill" : "questionmark.circle.fill",
                        accent: result.spotifyCapability.isEligible ? .green : .orange
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                    summaryMetric("Titres", "\(result.tracks.count)", "music.note.list")
                    summaryMetric("Playlists", "\(result.playlists.count)", "folder.fill")
                    summaryMetric("Streaming", "\(result.streamingTrackCount)", "antenna.radiowaves.left.and.right")
                    summaryMetric("Local", "\(result.localTrackCount)", "externaldrive.fill")
                    summaryMetric("Champs futurs", "\(result.unknownFieldNames.count)", "sparkles")
                    summaryMetric("Transitions", "\(hub.preparationPreview?.transitions.count ?? 0)", "arrow.left.arrow.right")
                }

                ForEach(result.warnings, id: \.self) { warning in
                    MixPilotNotice(title: "Avertissement d’import", message: warning, kind: .warning)
                }
            }
        }
    }

    private func summaryMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.cyan)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.65)
                    .foregroundStyle(MixPilotPalette.textTertiary)
            }
            Spacer()
        }
        .padding(11)
        .background(.white.opacity(0.038), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(.white.opacity(0.065), lineWidth: 1)
        }
    }

    private func readinessStep(_ number: Int, _ title: String, completed: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((completed ? Color.green : Color.white).opacity(completed ? 0.13 : 0.055))
                Circle()
                    .strokeBorder((completed ? Color.green : Color.white).opacity(completed ? 0.22 : 0.08), lineWidth: 1)
                if completed {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .frame(width: 29, height: 29)
            Text(title)
                .font(.callout.weight(completed ? .semibold : .regular))
                .foregroundStyle(completed ? .white : MixPilotPalette.textSecondary)
            Spacer()
            if completed {
                Text("TERMINÉ")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.green)
            }
        }
    }

    private func filteredTracks(_ result: RekordboxLibraryImportResult) -> [RekordboxImportedTrack] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return result.tracks }
        return result.tracks.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.artist.localizedCaseInsensitiveContains(query)
                || ($0.album?.localizedCaseInsensitiveContains(query) == true)
                || ($0.genre?.localizedCaseInsensitiveContains(query) == true)
        }
    }

    private func featureSymbol(_ route: RekordboxCompatibilityRoute) -> String {
        switch route {
        case .officialXML: "doc.badge.gearshape"
        case .adaptiveJSON: "curlybraces.square"
        case .oneLibrary: "externaldrive.connected.to.line.below"
        case .encryptedDatabaseRead: "cylinder.split.1x2"
        case .midiLearn: "slider.horizontal.3"
        case .accessibility: "hand.tap.fill"
        case .proDJLink: "network"
        }
    }

    private func featureAccent(_ confidence: RekordboxCompatibilityConfidence) -> Color {
        switch confidence {
        case .documented: .green
        case .observedInOpenSource: .cyan
        case .requiresDeviceValidation: .orange
        case .unavailable: .red
        }
    }
}
#endif