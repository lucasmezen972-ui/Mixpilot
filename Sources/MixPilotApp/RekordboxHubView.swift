#if os(macOS)
import AppKit
import MixPilotCore
import MixPilotSystem
import SwiftUI
import UniformTypeIdentifiers

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

    private let importer = RekordboxLibraryImporter()

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
        isWorking = true
        defer { isWorking = false }
        do {
            let data = try Data(contentsOf: url)
            let result = try importer.importData(
                data,
                fileExtension: url.pathExtension,
                installedVersion: rekordboxVersion
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
        if lastPreset == nil { generatePreset(profile: profile) }
        guard let preset = lastPreset else { return }
        let panel = NSSavePanel()
        panel.title = "Exporter le mapping rekordbox avancé"
        panel.nameFieldStringValue = "MixPilot Virtual Controller Advanced.midi.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = Data(preset.csv.utf8)
            try data.write(to: url, options: .atomic)
            guard try Data(contentsOf: url) == data else {
                throw CocoaError(.fileWriteUnknown)
            }
            presetURL = url
            NSWorkspace.shared.activateFileViewerSelecting([url])
            status = "Preset exporté et vérifié : \(url.lastPathComponent)"
        } catch {
            status = "Échec de l’export : \(error.localizedDescription)"
        }
    }

    var preparationPreview: SetProject? {
        guard let result = importResult, !result.tracks.isEmpty else { return nil }
        return SetPreparationEngine().prepare(
            name: sourceFilename ?? "Bibliothèque rekordbox",
            tracks: result.mixPilotTracks
        )
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
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.045, blue: 0.075),
                    Color(red: 0.07, green: 0.055, blue: 0.13),
                    Color(red: 0.035, green: 0.075, blue: 0.11),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                hero
                Divider().overlay(.white.opacity(0.12))
                HStack(spacing: 0) {
                    sidebar
                    Divider().overlay(.white.opacity(0.1))
                    detail
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1_180, minHeight: 790)
        .onAppear { hub.refreshEnvironment() }
    }

    private var hero: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.85), .blue.opacity(0.8), .cyan.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 66, height: 66)
            .shadow(color: .purple.opacity(0.3), radius: 20, y: 8)

            VStack(alignment: .leading, spacing: 5) {
                Text("REKORDBOX HUB")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.cyan)
                Text("Toute ta compatibilité, au même endroit")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Bibliothèque • Spotify • Mapping MIDI • Contrôle Live • Diagnostics")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            statusPill(
                title: hub.rekordboxRunning ? "REKORDBOX CONNECTÉ" : "REKORDBOX HORS LIGNE",
                symbol: hub.rekordboxRunning ? "checkmark.circle.fill" : "circle.dashed",
                positive: hub.rekordboxRunning
            )

            Button {
                hub.refreshEnvironment()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3.bold())
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .background(.white.opacity(0.09), in: Circle())
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial.opacity(0.55))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ESPACE REKORDBOX")
                .font(.caption2.bold())
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.42))
                .padding(.horizontal, 14)
                .padding(.top, 8)

            ForEach(RekordboxHubSection.allCases) { item in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { section = item }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.symbol)
                            .frame(width: 22)
                        Text(item.rawValue)
                            .fontWeight(section == item ? .semibold : .regular)
                        Spacer()
                        if section == item {
                            Circle().fill(.cyan).frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        section == item ? .white.opacity(0.11) : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("ÉTAT")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.4))
                Text(hub.status)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(4)
                if hub.isWorking { ProgressView().controlSize(.small) }
            }
            .padding(14)
            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(14)
        .frame(width: 225)
        .background(.black.opacity(0.16))
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
            .padding(26)
            .frame(maxWidth: 1_080, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionHeader(
                eyebrow: "CENTRE DE PILOTAGE",
                title: "Prêt pour rekordbox",
                subtitle: "MixPilot choisit automatiquement le meilleur chemin selon ce que ta version expose."
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 14)], spacing: 14) {
                metricCard(
                    title: "Version détectée",
                    value: hub.rekordboxVersion ?? "À détecter",
                    symbol: "app.badge.checkmark",
                    accent: .cyan
                )
                metricCard(
                    title: "Formats bibliothèque",
                    value: "XML + 4 JSON",
                    symbol: "doc.on.doc.fill",
                    accent: .purple
                )
                metricCard(
                    title: "Commandes répertoriées",
                    value: "\(RekordboxExtendedCommandCatalog.commands.count)",
                    symbol: "dial.medium.fill",
                    accent: .blue
                )
                metricCard(
                    title: "Couverture Runtime",
                    value: "\(Int(RekordboxExtendedCommandCatalog.runtimeCoverage * 100)) %",
                    symbol: "bolt.horizontal.circle.fill",
                    accent: .mint
                )
            }

            HStack(alignment: .top, spacing: 16) {
                glassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Parcours recommandé", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.title3.bold())
                        readinessStep(1, "Importer la bibliothèque", completed: hub.importResult != nil)
                        readinessStep(2, "Vérifier Spotify et la version", completed: hub.importResult?.spotifyCapability.isEligible == true)
                        readinessStep(3, "Exporter le preset MIDI", completed: hub.presetURL != nil)
                        readinessStep(4, "Tester Load / Play / Sync", completed: false)
                        readinessStep(5, "Valider une répétition complète", completed: false)
                    }
                }

                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Actions rapides", systemImage: "bolt.fill")
                            .font(.title3.bold())
                        primaryButton("Importer XML ou JSON", symbol: "square.and.arrow.down") {
                            hub.chooseLibraryFile()
                            section = .library
                        }
                        secondaryButton("Générer le mapping avancé", symbol: "slider.horizontal.3") {
                            hub.generatePreset(profile: appModel.mappingProfile)
                            section = .mapping
                        }
                        secondaryButton("Ouvrir le contrôle Live", symbol: "play.rectangle.on.rectangle") {
                            openWindow(id: "rekordbox-compatibility")
                        }
                    }
                }
            }

            if let result = hub.importResult {
                importSummary(result)
            }
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                eyebrow: "BIBLIOTHÈQUE UNIFIÉE",
                title: "Import rekordbox adaptatif",
                subtitle: "Les champs inconnus sont conservés dans le rapport au lieu de faire échouer l’import."
            )

            Button {
                hub.chooseLibraryFile()
            } label: {
                HStack(spacing: 18) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(hub.sourceFilename ?? "Choisir un XML ou un JSON rekordbox")
                            .font(.title3.bold())
                        Text("XML officiel • rekordbox-connect • MCP/pyrekordbox • OneLibrary • JSON futur")
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    Spacer()
                    Text("IMPORTER")
                        .font(.caption.bold())
                        .tracking(1.2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.cyan.opacity(0.16), in: Capsule())
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [7, 7]))
                )
            }
            .buttonStyle(.plain)

            if let result = hub.importResult {
                importSummary(result)

                HStack {
                    TextField("Rechercher un titre ou un artiste", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(11)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                    Text("\(filteredTracks(result).count) résultat(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                glassCard {
                    VStack(spacing: 0) {
                        HStack {
                            Text("TITRE").frame(maxWidth: .infinity, alignment: .leading)
                            Text("BPM").frame(width: 70, alignment: .trailing)
                            Text("KEY").frame(width: 70, alignment: .trailing)
                            Text("SOURCE").frame(width: 105, alignment: .trailing)
                        }
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.42))
                        .padding(.bottom, 10)

                        ForEach(Array(filteredTracks(result).prefix(200))) { track in
                            Divider().overlay(.white.opacity(0.08))
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(track.title).fontWeight(.semibold).lineLimit(1)
                                    Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(track.bpm > 0 ? String(format: "%.1f", track.bpm) : "—")
                                    .monospacedDigit()
                                    .frame(width: 70, alignment: .trailing)
                                Text(track.key ?? "—").frame(width: 70, alignment: .trailing)
                                Text(track.streamingService ?? "Local")
                                    .font(.caption.bold())
                                    .foregroundStyle(track.isStreaming ? .green : .white.opacity(0.55))
                                    .frame(width: 105, alignment: .trailing)
                            }
                            .padding(.vertical, 9)
                        }
                    }
                }

                if !result.playlists.isEmpty {
                    glassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Playlists détectées", systemImage: "folder.fill")
                                .font(.headline)
                            ForEach(result.playlists.prefix(30)) { playlist in
                                HStack {
                                    Image(systemName: "music.note.list")
                                    Text((playlist.folderPath + [playlist.name]).joined(separator: " / "))
                                    Spacer()
                                    Text("\(playlist.trackExternalIDs.count)")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Aucune bibliothèque importée",
                    systemImage: "music.note.list",
                    description: Text("Lance un import pour voir les pistes, playlists, cues, BPM, tonalités et sources de streaming.")
                )
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, minHeight: 260)
            }
        }
    }

    private var mapping: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                eyebrow: "MIDI LEARN",
                title: "Mapping rekordbox avancé",
                subtitle: "Un preset importable, versionné et validé avant écriture. Aucun fichier interne de rekordbox n’est remplacé."
            )

            HStack(alignment: .top, spacing: 16) {
                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Couverture du preset", systemImage: "gauge.with.dots.needle.67percent")
                            .font(.title3.bold())
                        let baseCount = hub.lastPreset?.base.supportedActions.count
                            ?? SeratoAction.allCases.filter { RekordboxMIDICommandRegistry.definition(for: $0) != nil }.count
                        Text("\(baseCount) commandes principales")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("+ focus de fenêtre et Color FX canal 1/2 dans le profil avancé")
                            .foregroundStyle(.secondary)
                        ProgressView(value: appModel.mappingProfile.completionRatio)
                            .tint(.cyan)
                    }
                }

                glassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.title3.bold())
                        primaryButton("Générer et exporter", symbol: "wand.and.stars") {
                            hub.exportPreset(profile: appModel.mappingProfile)
                        }
                        secondaryButton("Ouvrir l’assistant détaillé", symbol: "list.bullet.clipboard") {
                            openWindow(id: "automatic-rekordbox-mapping")
                        }
                        if let url = hub.presetURL {
                            Text(url.path)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.white.opacity(0.5))
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            glassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Commandes reconnues dans les catalogues rekordbox")
                        .font(.headline)
                    let groups = Dictionary(grouping: RekordboxExtendedCommandCatalog.commands, by: \.category)
                    ForEach(groups.keys.sorted(), id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.uppercased())
                                .font(.caption2.bold())
                                .tracking(1.4)
                                .foregroundStyle(.cyan.opacity(0.8))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], spacing: 10) {
                                ForEach(groups[category] ?? []) { command in
                                    HStack(spacing: 9) {
                                        Image(systemName: command.runtimeWired ? "checkmark.circle.fill" : "circle.dotted")
                                            .foregroundStyle(command.runtimeWired ? .green : .orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(command.title).font(.caption.bold())
                                            Text(command.csvName).font(.caption2.monospaced()).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                                    .help(command.warning ?? "Commande issue des catalogues rekordbox étudiés.")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var compatibility: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                eyebrow: "MATRICE DE COMPATIBILITÉ",
                title: "Le meilleur chemin selon ta version",
                subtitle: "Chaque capacité indique sa source, son niveau de confiance et si elle peut être utilisée pendant un Live."
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 14)], spacing: 14) {
                ForEach(RekordboxCompatibilityCatalog.features) { feature in
                    glassCard {
                        VStack(alignment: .leading, spacing: 11) {
                            HStack {
                                Image(systemName: featureSymbol(feature.route))
                                    .font(.title2)
                                    .foregroundStyle(featureAccent(feature.confidence))
                                Spacer()
                                Text(feature.confidence.displayName.uppercased())
                                    .font(.caption2.bold())
                                    .foregroundStyle(featureAccent(feature.confidence))
                            }
                            Text(feature.title).font(.headline)
                            Text(feature.detail)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Text(feature.route.displayName)
                                Spacer()
                                if let version = feature.minimumVersion { Text("≥ \(version)") }
                            }
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.45))
                            if !feature.safeDuringLive || feature.requiresRekordboxClosed {
                                Label(
                                    feature.requiresRekordboxClosed ? "rekordbox doit être fermé" : "hors Live uniquement",
                                    systemImage: "exclamationmark.shield"
                                )
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    private var control: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                eyebrow: "CONTRÔLE LIVE",
                title: "Tester avant d’automatiser",
                subtitle: "Les commandes sont désactivées jusqu’à l’armement manuel. Commence sur une playlist de copie, jamais en public."
            )

            HStack {
                Toggle("Armer les commandes", isOn: $controlsArmed)
                    .toggleStyle(.switch)
                Spacer()
                statusPill(
                    title: controlsArmed ? "COMMANDES ARMÉES" : "MODE SÉCURISÉ",
                    symbol: controlsArmed ? "bolt.fill" : "lock.shield.fill",
                    positive: !controlsArmed
                )
            }
            .padding(16)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))

            HStack(alignment: .top, spacing: 16) {
                deckPanel(title: "DECK A", play: .playA, cue: .cueA, sync: .syncA, load: .loadA)
                deckPanel(title: "DECK B", play: .playB, cue: .cueB, sync: .syncB, load: .loadB)
            }

            glassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Navigation et mixeur", systemImage: "slider.horizontal.below.square.filled.and.square")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: 10)], spacing: 10) {
                        controlButton("Fenêtre active", symbol: "rectangle.on.rectangle", action: .browserFocus)
                        controlButton("Titre précédent", symbol: "chevron.up", action: .browserUp)
                        controlButton("Titre suivant", symbol: "chevron.down", action: .browserDown)
                        controlButton("Crossfader centre", symbol: "arrow.left.and.right", action: .crossfader)
                        controlButton("Filtre A centre", symbol: "line.3.horizontal.decrease.circle", action: .filterA)
                        controlButton("Filtre B centre", symbol: "line.3.horizontal.decrease.circle", action: .filterB)
                    }
                    Text("Les boutons Filtre pilotent CFXParameterCH1/CH2 : sélectionne Filter comme Color FX dans rekordbox avant de les tester.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            HStack {
                secondaryButton("Inspecter les contrôles macOS", symbol: "cursorarrow.click.badge.clock") {
                    openWindow(id: "rekordbox-compatibility")
                }
                secondaryButton("Ouvrir le mapping", symbol: "slider.horizontal.3") {
                    openWindow(id: "automatic-rekordbox-mapping")
                }
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
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.caption.bold()).tracking(1.8).foregroundStyle(.cyan)
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
            appModel.testMapping(action)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption.bold())
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.white.opacity(controlsArmed ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!controlsArmed)
    }

    private func importSummary(_ result: RekordboxLibraryImportResult) -> some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.source.displayName).font(.headline)
                        Text([result.productName, result.productVersion].compactMap { $0 }.joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    statusPill(
                        title: result.spotifyCapability.displayName.uppercased(),
                        symbol: result.spotifyCapability.isEligible ? "checkmark.seal.fill" : "questionmark.circle.fill",
                        positive: result.spotifyCapability.isEligible
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    smallMetric("Titres", "\(result.tracks.count)")
                    smallMetric("Playlists", "\(result.playlists.count)")
                    smallMetric("Streaming", "\(result.streamingTrackCount)")
                    smallMetric("Local", "\(result.localTrackCount)")
                    smallMetric("Champs futurs", "\(result.unknownFieldNames.count)")
                    smallMetric("Transitions estimées", "\(hub.preparationPreview?.transitions.count ?? 0)")
                }

                ForEach(result.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
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

    private func sectionHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow).font(.caption2.bold()).tracking(2).foregroundStyle(.cyan)
            Text(title).font(.system(size: 29, weight: .bold, design: .rounded))
            Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.58))
        }
    }

    private func metricCard(title: String, value: String, symbol: String, accent: Color) -> some View {
        glassCard {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(accent)
                    .frame(width: 42, height: 42)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.title3.bold()).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func smallMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }

    private func readinessStep(_ number: Int, _ title: String, completed: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(completed ? .green.opacity(0.2) : .white.opacity(0.08))
                if completed {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.green)
                } else {
                    Text("\(number)").font(.caption.bold()).foregroundStyle(.white.opacity(0.65))
                }
            }
            .frame(width: 28, height: 28)
            Text(title).foregroundStyle(completed ? .white : .white.opacity(0.62))
            Spacer()
        }
    }

    private func statusPill(title: String, symbol: String, positive: Bool) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption2.bold())
            .tracking(0.6)
            .foregroundStyle(positive ? .green : .orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background((positive ? Color.green : Color.orange).opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke((positive ? Color.green : Color.orange).opacity(0.24)))
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(
            LinearGradient(colors: [.purple.opacity(0.9), .blue.opacity(0.85)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    private func secondaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08)))
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.09)))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 7)
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
