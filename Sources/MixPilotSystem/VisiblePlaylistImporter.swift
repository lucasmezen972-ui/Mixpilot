#if os(macOS)
import Foundation
import MixPilotCore

public struct PlaylistImportWarning: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var rowIndex: Int
    public var message: String

    public init(id: UUID = UUID(), rowIndex: Int, message: String) {
        self.id = id
        self.rowIndex = rowIndex
        self.message = message
    }
}

public struct PlaylistImportResult: Hashable, Sendable {
    public var tracks: [Track]
    public var warnings: [PlaylistImportWarning]
    public var sourceRowCount: Int

    public init(tracks: [Track], warnings: [PlaylistImportWarning], sourceRowCount: Int) {
        self.tracks = tracks
        self.warnings = warnings
        self.sourceRowCount = sourceRowCount
    }
}

public struct VisiblePlaylistImporter: Sendable {
    public init() {}

    public func importRows(
        _ rows: [DJLibraryRow],
        defaultProfile: MusicalProfile = .family
    ) -> PlaylistImportResult {
        var tracks: [Track] = []
        var warnings: [PlaylistImportWarning] = []

        for row in rows {
            let fields = row.fields
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !fields.isEmpty else { continue }

            let parsedDurations = fields.compactMap(parseDuration)
            let parsedBPMs = fields.compactMap(parseBPM)
            let duration = parsedDurations.first ?? 210
            let bpm = parsedBPMs.first ?? 100
            let metadataFields = fields.filter { field in
                parseDuration(field) == nil && parseBPM(field) == nil && !looksLikeKey(field)
            }

            guard let title = metadataFields.first else {
                warnings.append(PlaylistImportWarning(
                    rowIndex: row.index,
                    message: "Titre introuvable dans la ligne visible"
                ))
                continue
            }
            let artist = metadataFields.dropFirst().first ?? "Artiste inconnu"

            if parsedBPMs.isEmpty {
                warnings.append(PlaylistImportWarning(
                    rowIndex: row.index,
                    message: "BPM non exposé par l’interface DJ : valeur provisoire 100 BPM"
                ))
            }
            if parsedDurations.isEmpty {
                warnings.append(PlaylistImportWarning(
                    rowIndex: row.index,
                    message: "Durée non exposée par l’interface DJ : valeur provisoire 3 min 30"
                ))
            }

            let profile = inferredProfile(title: title, artist: artist, fallback: defaultProfile)
            tracks.append(Track(
                title: title,
                artist: artist,
                bpm: bpm,
                duration: duration,
                energy: estimatedEnergy(profile: profile, bpm: bpm),
                vocalDensity: estimatedVocalDensity(profile: profile),
                profile: profile
            ))
        }

        return PlaylistImportResult(
            tracks: deduplicated(tracks),
            warnings: warnings,
            sourceRowCount: rows.count
        )
    }

    private func parseBPM(_ value: String) -> Double? {
        let cleaned = value.replacingOccurrences(of: ",", with: ".")
        let pattern = #"(?<!\d)(\d{2,3}(?:\.\d)?)(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        for match in regex.matches(in: cleaned, range: range) {
            guard let swiftRange = Range(match.range(at: 1), in: cleaned),
                  let candidate = Double(cleaned[swiftRange]),
                  candidate >= 55,
                  candidate <= 220 else { continue }
            return candidate
        }
        return nil
    }

    private func parseDuration(_ value: String) -> TimeInterval? {
        let pattern = #"(?<!\d)(\d{1,2}):(\d{2})(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let minuteRange = Range(match.range(at: 1), in: value),
              let secondRange = Range(match.range(at: 2), in: value),
              let minutes = Double(value[minuteRange]),
              let seconds = Double(value[secondRange]),
              seconds < 60 else { return nil }
        return (minutes * 60) + seconds
    }

    private func looksLikeKey(_ value: String) -> Bool {
        let normalized = value.uppercased().replacingOccurrences(of: " ", with: "")
        let pattern = #"^(?:[A-G](?:#|B)?M?|\d{1,2}[AB])$"#
        return normalized.range(of: pattern, options: .regularExpression) != nil
    }

    private func inferredProfile(
        title: String,
        artist: String,
        fallback: MusicalProfile
    ) -> MusicalProfile {
        let text = "\(title) \(artist)".lowercased()
        let rules: [(MusicalProfile, [String])] = [
            (.shatta, ["shatta", "maureen", "keros-n", "keros n"]),
            (.bouyon, ["bouyon", "asa bantan", "triple kay"]),
            (.kompa, ["kompa", "compas", "carimi", "klass"]),
            (.zouk, ["zouk", "kassav", "fanny j", "patrick saint-éloi"]),
            (.amapiano, ["amapiano", "tyla", "kabza"]),
            (.dancehall, ["dancehall", "shenseea", "vybz", "popcaan"]),
            (.rap, ["rap", "gazo", "ninho", "leto", "tiakola", "meryl"]),
            (.afro, ["afro", "burna", "rema", "davido", "aya nakamura"]),
        ]
        for (profile, keywords) in rules where keywords.contains(where: text.contains) {
            return profile
        }
        return fallback
    }

    private func estimatedEnergy(profile: MusicalProfile, bpm: Double) -> Double {
        let profileBase: Double
        switch profile {
        case .family, .variety: profileBase = 0.58
        case .rap: profileBase = 0.65
        case .afro, .zouk, .kompa: profileBase = 0.68
        case .amapiano, .dancehall: profileBase = 0.76
        case .shatta, .bouyon: profileBase = 0.86
        case .safe: profileBase = 0.5
        }
        let tempoAdjustment = min(0.1, max(-0.08, (bpm - 100) / 500))
        return min(1, max(0, profileBase + tempoAdjustment))
    }

    private func estimatedVocalDensity(profile: MusicalProfile) -> Double {
        switch profile {
        case .rap: 0.88
        case .family, .variety: 0.7
        case .afro, .zouk, .kompa: 0.68
        case .amapiano: 0.5
        case .dancehall, .shatta, .bouyon: 0.72
        case .safe: 0.55
        }
    }

    private func deduplicated(_ tracks: [Track]) -> [Track] {
        var seen = Set<String>()
        return tracks.filter { track in
            let key = "\(track.title.lowercased())|\(track.artist.lowercased())|\(Int(track.duration))"
            return seen.insert(key).inserted
        }
    }
}

@available(*, deprecated, renamed: "VisiblePlaylistImporter")
public typealias SeratoPlaylistImporter = VisiblePlaylistImporter
#endif
