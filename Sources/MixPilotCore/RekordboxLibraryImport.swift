import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public enum RekordboxLibrarySource: String, Codable, CaseIterable, Sendable {
    case rekordboxXML
    case rekordboxConnect
    case rekordboxMCP
    case oneLibrary
    case genericJSON

    public var displayName: String {
        switch self {
        case .rekordboxXML: "XML rekordbox officiel"
        case .rekordboxConnect: "rekordbox-connect"
        case .rekordboxMCP: "Rekordbox MCP / pyrekordbox"
        case .oneLibrary: "OneLibrary / exportLibrary.db"
        case .genericJSON: "JSON rekordbox adaptatif"
        }
    }
}

public enum RekordboxSpotifyCapability: String, Codable, Sendable {
    case confirmedByContent
    case eligibleByVersion
    case unavailableByVersion
    case unknown

    public var isEligible: Bool {
        self == .confirmedByContent || self == .eligibleByVersion
    }

    public var displayName: String {
        switch self {
        case .confirmedByContent: "Spotify détecté dans les données"
        case .eligibleByVersion: "Version compatible Spotify"
        case .unavailableByVersion: "Version antérieure à Spotify"
        case .unknown: "Compatibilité Spotify à confirmer"
        }
    }
}

public struct RekordboxSemanticVersion: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = max(0, major)
        self.minor = max(0, minor)
        self.patch = max(0, patch)
    }

    public init?(_ text: String) {
        let parts = text
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        self.init(
            major: parts[0],
            minor: parts[1],
            patch: parts.count > 2 ? parts[2] : 0
        )
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static let spotifyDesktopMinimum = RekordboxSemanticVersion(major: 7, minor: 2, patch: 3)
}

public enum RekordboxCueKind: String, Codable, Sendable {
    case cue
    case fadeIn
    case fadeOut
    case load
    case loop
    case unknown
}

public struct RekordboxCueRecord: Codable, Hashable, Sendable {
    public var name: String?
    public var kind: RekordboxCueKind
    public var start: TimeInterval
    public var end: TimeInterval?
    public var number: Int?

    public init(name: String?, kind: RekordboxCueKind, start: TimeInterval, end: TimeInterval?, number: Int?) {
        self.name = name
        self.kind = kind
        self.start = max(0, start)
        self.end = end.map { max(0, $0) }
        self.number = number
    }
}

public struct RekordboxBeatGridRecord: Codable, Hashable, Sendable {
    public var start: TimeInterval
    public var bpm: Double
    public var meter: String?
    public var beatInBar: Int?

    public init(start: TimeInterval, bpm: Double, meter: String?, beatInBar: Int?) {
        self.start = max(0, start)
        self.bpm = max(0, bpm)
        self.meter = meter
        self.beatInBar = beatInBar
    }
}

public struct RekordboxImportedTrack: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var externalID: String?
    public var title: String
    public var subtitle: String?
    public var artist: String
    public var album: String?
    public var genre: String?
    public var label: String?
    public var remixer: String?
    public var key: String?
    public var bpm: Double
    public var duration: TimeInterval
    public var rating: Int
    public var playCount: Int
    public var filePath: String?
    public var streamingService: String?
    public var isStreaming: Bool
    public var cues: [RekordboxCueRecord]
    public var beatGrid: [RekordboxBeatGridRecord]
    public var rawFieldNames: [String]

    public init(
        id: UUID = UUID(),
        externalID: String?,
        title: String,
        subtitle: String? = nil,
        artist: String,
        album: String? = nil,
        genre: String? = nil,
        label: String? = nil,
        remixer: String? = nil,
        key: String? = nil,
        bpm: Double,
        duration: TimeInterval,
        rating: Int = 0,
        playCount: Int = 0,
        filePath: String? = nil,
        streamingService: String? = nil,
        isStreaming: Bool = false,
        cues: [RekordboxCueRecord] = [],
        beatGrid: [RekordboxBeatGridRecord] = [],
        rawFieldNames: [String] = []
    ) {
        self.id = id
        self.externalID = externalID
        self.title = title
        self.subtitle = subtitle
        self.artist = artist
        self.album = album
        self.genre = genre
        self.label = label
        self.remixer = remixer
        self.key = key
        self.bpm = max(0, bpm)
        self.duration = max(0, duration)
        self.rating = min(5, max(0, rating))
        self.playCount = max(0, playCount)
        self.filePath = filePath
        self.streamingService = streamingService
        self.isStreaming = isStreaming
        self.cues = cues.sorted { $0.start < $1.start }
        self.beatGrid = beatGrid.sorted { $0.start < $1.start }
        self.rawFieldNames = rawFieldNames.sorted()
    }

    public func asMixPilotTrack() -> Track {
        let inferredProfile = Self.profile(genre: genre, title: title, artist: artist)
        let tempoEnergy = min(1, max(0, (bpm - 70) / 100))
        let ratingEnergy = Double(rating) / 5
        let energy = min(1, max(0.15, (tempoEnergy * 0.68) + (ratingEnergy * 0.32)))
        let vocalDensity: Double
        switch inferredProfile {
        case .rap: vocalDensity = 0.88
        case .dancehall, .shatta, .bouyon: vocalDensity = 0.76
        case .zouk, .kompa, .variety, .family: vocalDensity = 0.68
        case .afro, .amapiano: vocalDensity = 0.58
        case .safe: vocalDensity = 0.45
        }
        return Track(
            title: subtitle.map { "\(title) (\($0))" } ?? title,
            artist: artist,
            bpm: bpm,
            duration: duration,
            energy: energy,
            vocalDensity: vocalDensity,
            profile: inferredProfile
        )
    }

    private static func profile(genre: String?, title: String, artist: String) -> MusicalProfile {
        let haystack = [genre, title, artist]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        if haystack.contains("amapiano") { return .amapiano }
        if haystack.contains("afro") || haystack.contains("afrobeats") { return .afro }
        if haystack.contains("shatta") { return .shatta }
        if haystack.contains("bouyon") { return .bouyon }
        if haystack.contains("dancehall") || haystack.contains("reggae") { return .dancehall }
        if haystack.contains("kompa") || haystack.contains("compas") { return .kompa }
        if haystack.contains("zouk") { return .zouk }
        if haystack.contains("rap") || haystack.contains("hip hop") || haystack.contains("hip-hop") { return .rap }
        if haystack.contains("clean") || haystack.contains("family") || haystack.contains("enfant") { return .family }
        return .variety
    }
}

public struct RekordboxImportedPlaylist: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var externalID: String?
    public var name: String
    public var folderPath: [String]
    public var trackExternalIDs: [String]

    public init(
        id: UUID = UUID(),
        externalID: String? = nil,
        name: String,
        folderPath: [String] = [],
        trackExternalIDs: [String] = []
    ) {
        self.id = id
        self.externalID = externalID
        self.name = name
        self.folderPath = folderPath
        self.trackExternalIDs = trackExternalIDs
    }
}

public struct RekordboxLibraryImportResult: Codable, Hashable, Sendable {
    public var source: RekordboxLibrarySource
    public var productName: String?
    public var productVersion: String?
    public var spotifyCapability: RekordboxSpotifyCapability
    public var tracks: [RekordboxImportedTrack]
    public var playlists: [RekordboxImportedPlaylist]
    public var warnings: [String]
    public var unknownFieldNames: [String]

    public init(
        source: RekordboxLibrarySource,
        productName: String?,
        productVersion: String?,
        spotifyCapability: RekordboxSpotifyCapability,
        tracks: [RekordboxImportedTrack],
        playlists: [RekordboxImportedPlaylist],
        warnings: [String],
        unknownFieldNames: [String]
    ) {
        self.source = source
        self.productName = productName
        self.productVersion = productVersion
        self.spotifyCapability = spotifyCapability
        self.tracks = tracks
        self.playlists = playlists
        self.warnings = warnings
        self.unknownFieldNames = unknownFieldNames.sorted()
    }

    public var mixPilotTracks: [Track] { tracks.map { $0.asMixPilotTrack() } }
    public var streamingTrackCount: Int { tracks.filter(\.isStreaming).count }
    public var localTrackCount: Int { tracks.count - streamingTrackCount }
}

public enum RekordboxLibraryImportError: Error, LocalizedError, Equatable {
    case emptyData
    case unsupportedDocument
    case invalidJSON
    case invalidXML(String)
    case noTracks

    public var errorDescription: String? {
        switch self {
        case .emptyData: "Le fichier rekordbox est vide."
        case .unsupportedDocument: "Le format du fichier rekordbox n’est pas reconnu."
        case .invalidJSON: "Le JSON rekordbox est invalide."
        case .invalidXML(let reason): "Le XML rekordbox est invalide : \(reason)"
        case .noTracks: "Aucun titre exploitable n’a été trouvé dans le fichier."
        }
    }
}

public struct RekordboxLibraryImporter: Sendable {
    public init() {}

    public func importData(
        _ data: Data,
        fileExtension: String? = nil,
        installedVersion: String? = nil
    ) throws -> RekordboxLibraryImportResult {
        guard !data.isEmpty else { throw RekordboxLibraryImportError.emptyData }
        let prefix = String(decoding: data.prefix(128), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExtension = fileExtension?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))

        if normalizedExtension == "xml" || prefix.hasPrefix("<") {
            return try importXML(data, installedVersion: installedVersion)
        }
        if normalizedExtension == "json" || prefix.hasPrefix("{") || prefix.hasPrefix("[") {
            return try importJSON(data, installedVersion: installedVersion)
        }
        throw RekordboxLibraryImportError.unsupportedDocument
    }

    private func importJSON(_ data: Data, installedVersion: String?) throws -> RekordboxLibraryImportResult {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw RekordboxLibraryImportError.invalidJSON
        }

        let source = detectJSONSource(root)
        let productVersion = firstString(
            in: root,
            keys: ["rekordboxVersion", "rekordbox_version", "appVersion", "app_version", "productVersion", "product_version", "dbVersion", "version"]
        ) ?? installedVersion
        let productName = firstString(in: root, keys: ["productName", "product_name", "application", "software", "product"])

        var dictionaries: [[String: Any]] = []
        collectTrackDictionaries(from: root, into: &dictionaries)
        var tracks: [RekordboxImportedTrack] = []
        var warnings: [String] = []
        var allFields = Set<String>()
        var seen = Set<String>()

        for dictionary in dictionaries {
            guard let track = makeTrack(from: dictionary) else { continue }
            let identity = track.externalID
                ?? track.filePath
                ?? "\(track.title.lowercased())|\(track.artist.lowercased())|\(Int(track.duration))"
            guard seen.insert(identity).inserted else { continue }
            tracks.append(track)
            allFields.formUnion(dictionary.keys)
        }

        let playlists = collectJSONPlaylists(from: root)
        if tracks.isEmpty { throw RekordboxLibraryImportError.noTracks }
        if tracks.contains(where: { $0.bpm == 0 }) {
            warnings.append("Certains titres n’ont pas de BPM exploitable ; MixPilot utilisera une analyse ou un mode sécurisé.")
        }
        if tracks.contains(where: { $0.duration == 0 }) {
            warnings.append("Certains titres n’ont pas de durée exploitable.")
        }

        let known = Self.knownJSONFields
        let unknown = allFields.subtracting(known)
        let spotify = spotifyCapability(root: root, version: productVersion)
        if spotify == .unknown {
            warnings.append("Aucune preuve Spotify ni version suffisamment précise n’a été trouvée ; la lecture locale reste compatible, le streaming devra être confirmé dans rekordbox.")
        }

        return RekordboxLibraryImportResult(
            source: source,
            productName: productName,
            productVersion: productVersion,
            spotifyCapability: spotify,
            tracks: tracks,
            playlists: playlists,
            warnings: warnings,
            unknownFieldNames: Array(unknown)
        )
    }

    private func importXML(_ data: Data, installedVersion: String?) throws -> RekordboxLibraryImportResult {
        let delegate = RekordboxXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw RekordboxLibraryImportError.invalidXML(
                parser.parserError?.localizedDescription ?? "structure non reconnue"
            )
        }
        guard !delegate.tracks.isEmpty else { throw RekordboxLibraryImportError.noTracks }

        let version = delegate.productVersion ?? installedVersion
        let containsSpotify = delegate.tracks.contains {
            ($0.filePath ?? "").lowercased().contains("spotify") ||
                ($0.streamingService ?? "").lowercased().contains("spotify")
        }
        let capability = spotifyCapability(hasSpotifyEvidence: containsSpotify, version: version)
        var warnings: [String] = []
        if delegate.tracks.contains(where: { $0.filePath == nil || $0.filePath?.isEmpty == true }) {
            warnings.append("Le champ Location est absent pour certains titres ; les titres streamés restent visibles mais ne peuvent pas être ouverts comme fichiers locaux.")
        }
        if capability == .unknown {
            warnings.append("Le XML ne prouve pas la disponibilité de Spotify ; MixPilot vérifiera la version et l’interface au moment du préflight.")
        }
        return RekordboxLibraryImportResult(
            source: .rekordboxXML,
            productName: delegate.productName,
            productVersion: version,
            spotifyCapability: capability,
            tracks: delegate.tracks,
            playlists: delegate.playlists,
            warnings: warnings,
            unknownFieldNames: []
        )
    }

    private func detectJSONSource(_ root: Any) -> RekordboxLibrarySource {
        let keys = recursiveKeys(in: root)
        if keys.contains("dbPath") && keys.contains("rows") { return .rekordboxConnect }
        if keys.contains("database_path") || keys.contains("play_count") || keys.contains("track_count") {
            return .rekordboxMCP
        }
        if keys.contains("dbVersion") || keys.contains("content_id") || keys.contains("exportLibrary") || keys.contains("deviceName") {
            return .oneLibrary
        }
        return .genericJSON
    }

    private func collectTrackDictionaries(from value: Any, into output: inout [[String: Any]]) {
        if let dictionary = value as? [String: Any] {
            if looksLikeTrack(dictionary) { output.append(dictionary) }
            for child in dictionary.values {
                collectTrackDictionaries(from: child, into: &output)
            }
        } else if let array = value as? [Any] {
            for child in array { collectTrackDictionaries(from: child, into: &output) }
        }
    }

    private func looksLikeTrack(_ dictionary: [String: Any]) -> Bool {
        let normalized = Set(dictionary.keys.map { $0.lowercased() })
        let hasTitle = !normalized.isDisjoint(with: ["title", "tracktitle", "name"])
        let hasTrackSignal = !normalized.isDisjoint(with: [
            "artist", "artistname", "bpm", "tempo", "averagebpm", "length", "duration",
            "filepath", "file_path", "folderpath", "location", "contentid", "content_id", "trackid", "track_id", "isrc"
        ])
        let playlistOnly = normalized.contains("track_count") && !hasTrackSignal
        return hasTitle && hasTrackSignal && !playlistOnly
    }

    private func makeTrack(from dictionary: [String: Any]) -> RekordboxImportedTrack? {
        guard let title = scalarString(dictionary, aliases: ["title", "Title", "TrackTitle", "name", "Name"]),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let subtitle = scalarString(dictionary, aliases: ["subtitle", "subTitle", "SubTitle", "mix", "Mix"])
        let artist = nestedString(dictionary, aliases: ["artist", "Artist", "ArtistName"], nestedKey: "name") ?? "Artiste inconnu"
        let externalID = scalarString(dictionary, aliases: ["id", "ID", "TrackID", "trackId", "track_id", "ContentID", "contentId", "content_id", "UUID", "uuid"])
        let bpmRaw = scalarDouble(dictionary, aliases: ["bpm", "BPM", "tempo", "Tempo", "AverageBpm", "average_bpm"]) ?? 0
        let bpm = normalizeBPM(bpmRaw)
        let durationAlias = firstPresentAlias(dictionary, aliases: ["durationMs", "duration_ms", "duration", "Duration", "length", "Length", "TotalTime", "total_time"])
        let durationRaw = durationAlias.flatMap { scalarDouble(dictionary, aliases: [$0]) } ?? 0
        let duration = normalizeDuration(durationRaw, fieldName: durationAlias)
        let ratingRaw = scalarDouble(dictionary, aliases: ["rating", "Rating"]) ?? 0
        let rating = normalizeRating(ratingRaw)
        let playCount = Int(scalarDouble(dictionary, aliases: ["playCount", "PlayCount", "play_count"]) ?? 0)
        let filePath = scalarString(dictionary, aliases: ["filePath", "file_path", "FolderPath", "folderPath", "Location", "location", "path", "Path"])
        let service = nestedString(
            dictionary,
            aliases: ["streamingService", "streaming_service", "provider", "service", "source", "mediaSlot", "media_slot"],
            nestedKey: "name"
        ) ?? inferStreamingService(from: dictionary, filePath: filePath)
        let explicitStreaming = scalarBool(dictionary, aliases: ["isStreaming", "is_streaming", "streaming"]) ?? false
        let isStreaming = explicitStreaming || service != nil || Self.streamingTokens.contains { token in
            (filePath ?? "").lowercased().contains(token)
        }

        return RekordboxImportedTrack(
            externalID: externalID,
            title: title,
            subtitle: subtitle,
            artist: artist,
            album: nestedString(dictionary, aliases: ["album", "Album", "AlbumName"], nestedKey: "name"),
            genre: nestedString(dictionary, aliases: ["genre", "Genre", "GenreName"], nestedKey: "name"),
            label: nestedString(dictionary, aliases: ["label", "Label", "LabelName"], nestedKey: "name"),
            remixer: nestedString(dictionary, aliases: ["remixer", "Remixer", "RemixerName"], nestedKey: "name"),
            key: nestedString(dictionary, aliases: ["key", "Key", "KeyName", "Tonality", "tonality"], nestedKey: "name"),
            bpm: bpm,
            duration: duration,
            rating: rating,
            playCount: playCount,
            filePath: filePath,
            streamingService: service,
            isStreaming: isStreaming,
            cues: parseJSONCues(dictionary),
            beatGrid: parseJSONBeatGrid(dictionary),
            rawFieldNames: Array(dictionary.keys)
        )
    }

    private func parseJSONCues(_ dictionary: [String: Any]) -> [RekordboxCueRecord] {
        let value = valueForAlias(dictionary, aliases: ["cues", "cuePoints", "cue_points", "positionMarks", "position_marks", "markers"])
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { item in
            guard let cue = item as? [String: Any] else { return nil }
            let start = scalarDouble(cue, aliases: ["start", "Start", "offset", "position", "time"]) ?? 0
            let end = scalarDouble(cue, aliases: ["end", "End"])
            let rawKind = scalarString(cue, aliases: ["type", "Type", "kind"])?.lowercased() ?? ""
            let kind: RekordboxCueKind
            if rawKind.contains("loop") || rawKind == "4" { kind = .loop }
            else if rawKind.contains("fadein") || rawKind.contains("fade-in") || rawKind == "1" { kind = .fadeIn }
            else if rawKind.contains("fadeout") || rawKind.contains("fade-out") || rawKind == "2" { kind = .fadeOut }
            else if rawKind.contains("load") || rawKind == "3" { kind = .load }
            else if rawKind.contains("cue") || rawKind == "0" { kind = .cue }
            else { kind = .unknown }
            return RekordboxCueRecord(
                name: scalarString(cue, aliases: ["name", "Name", "label", "comment"]),
                kind: kind,
                start: normalizeDuration(start, fieldName: cue.keys.first { $0.lowercased().contains("offset") }),
                end: end,
                number: scalarDouble(cue, aliases: ["num", "Num", "number", "index", "button"]).map(Int.init)
            )
        }
    }

    private func parseJSONBeatGrid(_ dictionary: [String: Any]) -> [RekordboxBeatGridRecord] {
        let value = valueForAlias(dictionary, aliases: ["beatGrid", "beatgrid", "beat_grid", "tempoMarkers", "tempo_markers", "TEMPO"])
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { item in
            guard let marker = item as? [String: Any] else { return nil }
            let bpm = normalizeBPM(scalarDouble(marker, aliases: ["bpm", "Bpm", "tempo"]) ?? 0)
            guard bpm > 0 else { return nil }
            return RekordboxBeatGridRecord(
                start: scalarDouble(marker, aliases: ["start", "Inizio", "position", "time"]) ?? 0,
                bpm: bpm,
                meter: scalarString(marker, aliases: ["meter", "Metro", "timeSignature", "time_signature"]),
                beatInBar: scalarDouble(marker, aliases: ["beat", "Battito", "beatInBar", "beat_in_bar"]).map(Int.init)
            )
        }
    }

    private func collectJSONPlaylists(from root: Any) -> [RekordboxImportedPlaylist] {
        var output: [RekordboxImportedPlaylist] = []
        collectJSONPlaylists(from: root, path: [], output: &output)
        var seen = Set<String>()
        return output.filter { playlist in
            let identity = playlist.externalID ?? (playlist.folderPath + [playlist.name]).joined(separator: "/")
            return seen.insert(identity).inserted
        }
    }

    private func collectJSONPlaylists(from value: Any, path: [String], output: inout [RekordboxImportedPlaylist]) {
        if let dictionary = value as? [String: Any] {
            let name = scalarString(dictionary, aliases: ["playlistName", "playlist_name", "Name", "name"])
            let trackContainer = valueForAlias(dictionary, aliases: ["tracks", "items", "contents", "trackEntries", "track_entries"])
            if let name, let array = trackContainer as? [Any] {
                let ids = array.compactMap { item -> String? in
                    if let id = item as? String { return id }
                    guard let row = item as? [String: Any] else { return nil }
                    return scalarString(row, aliases: ["id", "ID", "TrackID", "track_id", "ContentID", "content_id", "Key"])
                }
                output.append(RekordboxImportedPlaylist(
                    externalID: scalarString(dictionary, aliases: ["id", "ID", "playlistId", "playlist_id"]),
                    name: name,
                    folderPath: path,
                    trackExternalIDs: ids
                ))
            }
            let nextPath = name.map { path + [$0] } ?? path
            for child in dictionary.values { collectJSONPlaylists(from: child, path: nextPath, output: &output) }
        } else if let array = value as? [Any] {
            for child in array { collectJSONPlaylists(from: child, path: path, output: &output) }
        }
    }

    private func spotifyCapability(root: Any, version: String?) -> RekordboxSpotifyCapability {
        spotifyCapability(hasSpotifyEvidence: containsSpotify(in: root), version: version)
    }

    private func spotifyCapability(hasSpotifyEvidence: Bool, version: String?) -> RekordboxSpotifyCapability {
        if hasSpotifyEvidence { return .confirmedByContent }
        guard let version, let parsed = RekordboxSemanticVersion(version) else { return .unknown }
        return parsed >= .spotifyDesktopMinimum ? .eligibleByVersion : .unavailableByVersion
    }

    private func containsSpotify(in value: Any) -> Bool {
        if let string = value as? String { return string.lowercased().contains("spotify") }
        if let dictionary = value as? [String: Any] {
            return dictionary.contains { key, child in
                key.lowercased().contains("spotify") || containsSpotify(in: child)
            }
        }
        if let array = value as? [Any] { return array.contains { containsSpotify(in: $0) } }
        return false
    }

    private func inferStreamingService(from dictionary: [String: Any], filePath: String?) -> String? {
        let combined = dictionary.map { "\($0.key)=\($0.value)" }.joined(separator: " ").lowercased() + " " + (filePath ?? "").lowercased()
        if combined.contains("spotify") { return "Spotify" }
        if combined.contains("apple music") || combined.contains("applemusic") { return "Apple Music" }
        if combined.contains("tidal") { return "TIDAL" }
        if combined.contains("beatport") { return "Beatport" }
        if combined.contains("soundcloud") { return "SoundCloud" }
        return nil
    }

    private func normalizeBPM(_ raw: Double) -> Double {
        guard raw.isFinite, raw > 0 else { return 0 }
        if raw > 1_000 { return raw / 100 }
        return raw
    }

    private func normalizeDuration(_ raw: Double, fieldName: String?) -> TimeInterval {
        guard raw.isFinite, raw > 0 else { return 0 }
        let field = fieldName?.lowercased() ?? ""
        if field.contains("ms") || raw > 36_000 { return raw / 1_000 }
        return raw
    }

    private func normalizeRating(_ raw: Double) -> Int {
        guard raw.isFinite, raw > 0 else { return 0 }
        if raw > 5 { return min(5, max(0, Int((raw / 51).rounded()))) }
        return min(5, max(0, Int(raw.rounded())))
    }

    private func recursiveKeys(in value: Any) -> Set<String> {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: Set(dictionary.keys)) { result, pair in
                result.formUnion(recursiveKeys(in: pair.value))
            }
        }
        if let array = value as? [Any] {
            return array.reduce(into: Set<String>()) { $0.formUnion(recursiveKeys(in: $1)) }
        }
        return []
    }

    private func firstString(in value: Any, keys: [String]) -> String? {
        if let dictionary = value as? [String: Any] {
            if let found = scalarString(dictionary, aliases: keys) { return found }
            for child in dictionary.values {
                if let found = firstString(in: child, keys: keys) { return found }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let found = firstString(in: child, keys: keys) { return found }
            }
        }
        return nil
    }

    private func valueForAlias(_ dictionary: [String: Any], aliases: [String]) -> Any? {
        for alias in aliases {
            if let direct = dictionary[alias] { return direct }
            if let match = dictionary.first(where: { $0.key.caseInsensitiveCompare(alias) == .orderedSame }) {
                return match.value
            }
        }
        return nil
    }

    private func firstPresentAlias(_ dictionary: [String: Any], aliases: [String]) -> String? {
        aliases.first { alias in
            dictionary.keys.contains { $0.caseInsensitiveCompare(alias) == .orderedSame }
        }
    }

    private func scalarString(_ dictionary: [String: Any], aliases: [String]) -> String? {
        guard let value = valueForAlias(dictionary, aliases: aliases) else { return nil }
        if let string = value as? String {
            let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func nestedString(_ dictionary: [String: Any], aliases: [String], nestedKey: String) -> String? {
        guard let value = valueForAlias(dictionary, aliases: aliases) else { return nil }
        if let string = value as? String { return string.isEmpty ? nil : string }
        if let nested = value as? [String: Any] {
            return scalarString(nested, aliases: [nestedKey, "Name", "title", "value"])
        }
        return nil
    }

    private func scalarDouble(_ dictionary: [String: Any], aliases: [String]) -> Double? {
        guard let value = valueForAlias(dictionary, aliases: aliases) else { return nil }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String {
            return Double(string.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    private func scalarBool(_ dictionary: [String: Any], aliases: [String]) -> Bool? {
        guard let value = valueForAlias(dictionary, aliases: aliases) else { return nil }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            switch string.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private static let streamingTokens = ["spotify", "tidal", "beatport", "soundcloud", "applemusic", "apple music"]

    private static let knownJSONFields: Set<String> = [
        "id", "ID", "TrackID", "trackId", "track_id", "ContentID", "contentId", "content_id", "UUID", "uuid",
        "title", "Title", "TrackTitle", "name", "Name", "subtitle", "subTitle", "SubTitle", "mix", "Mix",
        "artist", "Artist", "ArtistName", "album", "Album", "AlbumName", "genre", "Genre", "GenreName",
        "label", "Label", "LabelName", "remixer", "Remixer", "RemixerName", "key", "Key", "KeyName", "Tonality", "tonality",
        "bpm", "BPM", "tempo", "Tempo", "AverageBpm", "average_bpm", "duration", "Duration", "durationMs", "duration_ms",
        "length", "Length", "TotalTime", "total_time", "rating", "Rating", "playCount", "PlayCount", "play_count",
        "filePath", "file_path", "FolderPath", "folderPath", "Location", "location", "path", "Path", "isrc", "ISRC",
        "streamingService", "streaming_service", "provider", "service", "source", "mediaSlot", "media_slot", "isStreaming", "is_streaming", "streaming",
        "cues", "cuePoints", "cue_points", "positionMarks", "position_marks", "markers", "beatGrid", "beatgrid", "beat_grid",
        "tempoMarkers", "tempo_markers", "tracks", "items", "contents", "rows", "count", "dbPath", "database_path"
    ]
}

private final class RekordboxXMLDelegate: NSObject, XMLParserDelegate {
    private struct TrackBuilder {
        var attributes: [String: String]
        var cues: [RekordboxCueRecord] = []
        var beatGrid: [RekordboxBeatGridRecord] = []
    }

    private struct NodeBuilder {
        var type: Int
        var name: String
        var externalID: String?
        var trackKeys: [String] = []
    }

    var productName: String?
    var productVersion: String?
    private(set) var tracks: [RekordboxImportedTrack] = []
    private(set) var playlists: [RekordboxImportedPlaylist] = []

    private var currentTrack: TrackBuilder?
    private var inCollection = false
    private var inPlaylists = false
    private var nodes: [NodeBuilder] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName.uppercased() {
        case "PRODUCT":
            productName = attribute(attributeDict, "Name")
            productVersion = attribute(attributeDict, "Version")
        case "COLLECTION":
            inCollection = true
        case "PLAYLISTS":
            inPlaylists = true
        case "TRACK":
            if inCollection && !inPlaylists {
                currentTrack = TrackBuilder(attributes: attributeDict)
            } else if inPlaylists, !nodes.isEmpty,
                      let key = attribute(attributeDict, "Key") {
                nodes[nodes.count - 1].trackKeys.append(key)
            }
        case "TEMPO":
            guard currentTrack != nil else { return }
            let bpm = double(attributeDict, "Bpm") ?? 0
            currentTrack?.beatGrid.append(RekordboxBeatGridRecord(
                start: double(attributeDict, "Inizio") ?? 0,
                bpm: bpm,
                meter: attribute(attributeDict, "Metro"),
                beatInBar: int(attributeDict, "Battito")
            ))
        case "POSITION_MARK":
            guard currentTrack != nil else { return }
            let rawType = int(attributeDict, "Type") ?? -1
            let kind: RekordboxCueKind
            switch rawType {
            case 0: kind = .cue
            case 1: kind = .fadeIn
            case 2: kind = .fadeOut
            case 3: kind = .load
            case 4: kind = .loop
            default: kind = .unknown
            }
            currentTrack?.cues.append(RekordboxCueRecord(
                name: attribute(attributeDict, "Name"),
                kind: kind,
                start: double(attributeDict, "Start") ?? 0,
                end: double(attributeDict, "End"),
                number: int(attributeDict, "Num")
            ))
        case "NODE":
            guard inPlaylists else { return }
            nodes.append(NodeBuilder(
                type: int(attributeDict, "Type") ?? 0,
                name: attribute(attributeDict, "Name") ?? "Sans nom",
                externalID: attribute(attributeDict, "Id") ?? attribute(attributeDict, "ID")
            ))
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName.uppercased() {
        case "TRACK":
            if let builder = currentTrack {
                if let track = makeTrack(builder) { tracks.append(track) }
                currentTrack = nil
            }
        case "COLLECTION":
            inCollection = false
        case "NODE":
            guard let node = nodes.popLast() else { return }
            if node.type == 1 {
                let folderPath = nodes.map(\.name).filter { $0.uppercased() != "ROOT" }
                playlists.append(RekordboxImportedPlaylist(
                    externalID: node.externalID,
                    name: node.name,
                    folderPath: folderPath,
                    trackExternalIDs: node.trackKeys
                ))
            }
        case "PLAYLISTS":
            inPlaylists = false
            nodes.removeAll()
        default:
            break
        }
    }

    private func makeTrack(_ builder: TrackBuilder) -> RekordboxImportedTrack? {
        guard let title = attribute(builder.attributes, "Name"), !title.isEmpty else { return nil }
        let location = attribute(builder.attributes, "Location")
        let service: String?
        if location?.lowercased().contains("spotify") == true { service = "Spotify" }
        else if location?.lowercased().contains("tidal") == true { service = "TIDAL" }
        else if location?.lowercased().contains("beatport") == true { service = "Beatport" }
        else if location?.lowercased().contains("soundcloud") == true { service = "SoundCloud" }
        else { service = nil }
        let rawRating = double(builder.attributes, "Rating") ?? 0
        return RekordboxImportedTrack(
            externalID: attribute(builder.attributes, "TrackID") ?? location,
            title: title,
            subtitle: attribute(builder.attributes, "Mix"),
            artist: attribute(builder.attributes, "Artist") ?? "Artiste inconnu",
            album: attribute(builder.attributes, "Album"),
            genre: attribute(builder.attributes, "Genre"),
            label: attribute(builder.attributes, "Label"),
            remixer: attribute(builder.attributes, "Remixer"),
            key: attribute(builder.attributes, "Tonality"),
            bpm: double(builder.attributes, "AverageBpm") ?? builder.beatGrid.first?.bpm ?? 0,
            duration: double(builder.attributes, "TotalTime") ?? 0,
            rating: rawRating > 5 ? Int((rawRating / 51).rounded()) : Int(rawRating.rounded()),
            playCount: int(builder.attributes, "PlayCount") ?? 0,
            filePath: location,
            streamingService: service,
            isStreaming: service != nil,
            cues: builder.cues,
            beatGrid: builder.beatGrid,
            rawFieldNames: Array(builder.attributes.keys)
        )
    }

    private func attribute(_ dictionary: [String: String], _ name: String) -> String? {
        dictionary[name] ?? dictionary.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    private func double(_ dictionary: [String: String], _ name: String) -> Double? {
        attribute(dictionary, name).flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
    }

    private func int(_ dictionary: [String: String], _ name: String) -> Int? {
        attribute(dictionary, name).flatMap(Int.init)
    }
}
