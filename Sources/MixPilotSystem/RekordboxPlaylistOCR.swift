#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import Vision

public enum RekordboxLibrarySource: Sendable, Equatable {
    case accessibility(observedAt: Date)
    case visibleText(observedAt: Date)
    case freshOCR(observedAt: Date)
    case cachedOCR(observedAt: Date)
    case spotifyAPI(synchronizedAt: Date)

    public var date: Date {
        switch self {
        case .accessibility(let date),
             .visibleText(let date),
             .freshOCR(let date),
             .cachedOCR(let date),
             .spotifyAPI(let date):
            date
        }
    }

    public var isCurrentObservation: Bool {
        switch self {
        case .accessibility, .visibleText, .freshOCR:
            true
        case .cachedOCR, .spotifyAPI:
            false
        }
    }
}

public struct RekordboxLibraryObservation: Sendable, Equatable {
    public var rows: [DJLibraryRow]
    public var source: RekordboxLibrarySource
    public var collectedAt: Date
    public var durationSeconds: TimeInterval
    public var rekordboxVersion: String?
    public var windowIdentifier: String?
    public var fragmentCount: Int
    public var confidence: Double
    public var partialErrors: [String]

    public init(
        rows: [DJLibraryRow],
        source: RekordboxLibrarySource,
        collectedAt: Date = Date(),
        durationSeconds: TimeInterval = 0,
        rekordboxVersion: String? = nil,
        windowIdentifier: String? = nil,
        fragmentCount: Int = 0,
        confidence: Double = 0,
        partialErrors: [String] = []
    ) {
        self.rows = rows
        self.source = source
        self.collectedAt = collectedAt
        self.durationSeconds = durationSeconds
        self.rekordboxVersion = rekordboxVersion
        self.windowIdentifier = windowIdentifier
        self.fragmentCount = fragmentCount
        self.confidence = max(0, min(1, confidence))
        self.partialErrors = partialErrors
    }

    public var isCurrent: Bool { source.isCurrentObservation }

    public var cacheAge: TimeInterval? {
        guard case .cachedOCR(let generatedAt) = source else { return nil }
        return max(0, collectedAt.timeIntervalSince(generatedAt))
    }
}

struct RekordboxOCRFragment: Hashable, Sendable {
    var text: String
    var bounds: CGRect
}

struct RekordboxOCRParseResult: Sendable, Equatable {
    var rows: [DJLibraryRow]
    var confidence: Double
    var usedGeometricFallback: Bool
}

struct RekordboxPlaylistOCRParser: Sendable {
    private static let titleHeaders: Set<String> = [
        "titre du morceau",
        "titre",
        "track title",
        "title",
        "cancion",
        "titulo"
    ]
    private static let artistHeaders: Set<String> = [
        "artiste",
        "artist",
        "artista"
    ]

    func rows(from fragments: [RekordboxOCRFragment], maxRows: Int) -> [DJLibraryRow] {
        parse(fragments: fragments, maxRows: maxRows).rows
    }

    func parse(fragments: [RekordboxOCRFragment], maxRows: Int) -> RekordboxOCRParseResult {
        let normalized = fragments.compactMap { fragment -> RekordboxOCRFragment? in
            let text = cleaned(fragment.text)
            return text.isEmpty ? nil : RekordboxOCRFragment(text: text, bounds: fragment.bounds)
        }

        if let titleHeader = header(matching: Self.titleHeaders, in: normalized),
           let artistHeader = normalized
            .filter({
                Self.artistHeaders.contains(normalizedHeader($0.text)) &&
                    $0.bounds.minX > titleHeader.bounds.minX
            })
            .min(by: { $0.bounds.minX < $1.bounds.minX }) {
            return RekordboxOCRParseResult(
                rows: rowsUsingHeaders(
                    fragments: normalized,
                    titleHeader: titleHeader,
                    artistHeader: artistHeader,
                    maxRows: maxRows
                ),
                confidence: 0.94,
                usedGeometricFallback: false
            )
        }

        return RekordboxOCRParseResult(
            rows: geometricallyInferredRows(from: normalized, maxRows: maxRows),
            confidence: 0.62,
            usedGeometricFallback: true
        )
    }

    private func rowsUsingHeaders(
        fragments: [RekordboxOCRFragment],
        titleHeader: RekordboxOCRFragment,
        artistHeader: RekordboxOCRFragment,
        maxRows: Int
    ) -> [DJLibraryRow] {
        let headerFloor = min(titleHeader.bounds.minY, artistHeader.bounds.minY)
        let titleMinimumX = max(0, titleHeader.bounds.minX - 0.035)
        let artistMinimumX = max(titleMinimumX + 0.02, artistHeader.bounds.minX - 0.035)
        let titleMaximumX = artistMinimumX - 0.004
        let artistMaximumX = min(0.92, artistHeader.bounds.maxX + 0.18)
        let titleFragments = fragments.filter {
            $0.bounds.midY < headerFloor &&
                $0.bounds.minX >= titleMinimumX &&
                $0.bounds.minX < titleMaximumX &&
                !isKnownHeader($0.text)
        }.sorted { $0.bounds.midY > $1.bounds.midY }
        let artistFragments = fragments.filter {
            $0.bounds.midY < headerFloor &&
                $0.bounds.minX >= artistMinimumX &&
                $0.bounds.minX < artistMaximumX &&
                !isKnownHeader($0.text)
        }

        var usedArtists = Set<Int>()
        var rows: [DJLibraryRow] = []
        for title in titleFragments where rows.count < max(1, maxRows) {
            let verticalTolerance = max(0.012, title.bounds.height * 0.7)
            let match = artistFragments.enumerated()
                .filter { !usedArtists.contains($0.offset) }
                .filter { abs($0.element.bounds.midY - title.bounds.midY) <= verticalTolerance }
                .min { lhs, rhs in
                    abs(lhs.element.bounds.midY - title.bounds.midY) <
                        abs(rhs.element.bounds.midY - title.bounds.midY)
                }
            var fields = [title.text]
            if let match {
                usedArtists.insert(match.offset)
                fields.append(match.element.text)
            }
            appendUnique(fields: fields, to: &rows, maxRows: maxRows)
        }
        return rows
    }

    private func geometricallyInferredRows(
        from fragments: [RekordboxOCRFragment],
        maxRows: Int
    ) -> [DJLibraryRow] {
        let candidates = fragments
            .filter { $0.bounds.minX >= 0.22 && $0.bounds.maxX <= 0.94 }
            .filter { !isKnownHeader($0.text) }
            .sorted {
                if abs($0.bounds.midY - $1.bounds.midY) > 0.008 {
                    return $0.bounds.midY > $1.bounds.midY
                }
                return $0.bounds.minX < $1.bounds.minX
            }

        var groups: [[RekordboxOCRFragment]] = []
        for fragment in candidates {
            if let index = groups.indices.last(where: { groupIndex in
                let averageY = groups[groupIndex].map(\.bounds.midY).reduce(0, +) /
                    CGFloat(groups[groupIndex].count)
                let tolerance = max(0.014, fragment.bounds.height * 0.8)
                return abs(averageY - fragment.bounds.midY) <= tolerance
            }) {
                groups[index].append(fragment)
            } else {
                groups.append([fragment])
            }
        }

        var rows: [DJLibraryRow] = []
        for group in groups where rows.count < max(1, maxRows) {
            let sorted = group.sorted { $0.bounds.minX < $1.bounds.minX }
            guard sorted.count >= 2 else { continue }

            var splitIndex = 1
            var largestGap: CGFloat = -.infinity
            for index in 1..<sorted.count {
                let gap = sorted[index].bounds.minX - sorted[index - 1].bounds.maxX
                if gap > largestGap {
                    largestGap = gap
                    splitIndex = index
                }
            }
            guard splitIndex > 0, splitIndex < sorted.count else { continue }

            let title = sorted[..<splitIndex].map(\.text).joined(separator: " ")
            let artist = sorted[splitIndex...].map(\.text).joined(separator: " ")
            guard title.count > 1, artist.count > 1 else { continue }
            appendUnique(fields: [cleaned(title), cleaned(artist)], to: &rows, maxRows: maxRows)
        }
        return rows
    }

    private func appendUnique(fields: [String], to rows: inout [DJLibraryRow], maxRows: Int) {
        let normalizedFields = fields.map(cleaned).filter { !$0.isEmpty }
        guard !normalizedFields.isEmpty,
              rows.count < max(1, maxRows),
              !rows.contains(where: { $0.fields == normalizedFields }) else {
            return
        }
        rows.append(DJLibraryRow(index: rows.count, fields: normalizedFields))
    }

    private func header(
        matching aliases: Set<String>,
        in fragments: [RekordboxOCRFragment]
    ) -> RekordboxOCRFragment? {
        fragments
            .filter { aliases.contains(normalizedHeader($0.text)) }
            .filter { $0.bounds.minX >= 0.20 && $0.bounds.minX < 0.82 }
            .min { $0.bounds.minX < $1.bounds.minX }
    }

    private func isKnownHeader(_ text: String) -> Bool {
        let normalized = normalizedHeader(text)
        return Self.titleHeaders.contains(normalized) || Self.artistHeaders.contains(normalized)
    }

    private func normalizedHeader(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func cleaned(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

actor RekordboxPlaylistOCRReader {
    private struct Cache: Codable {
        var generatedAt: Date
        var fields: [[String]]
        var confidence: Double
        var fragmentCount: Int
    }

    private struct RecognitionResult {
        var parseResult: RekordboxOCRParseResult
        var fragmentCount: Int
        var errors: [String]
    }

    private var activeProcessIdentifiers = Set<pid_t>()
    private var lastAttemptByProcessIdentifier: [pid_t: Date] = [:]
    private static let minimumRefreshInterval: TimeInterval = 0.75
    static let cacheLifetime: TimeInterval = 30 * 60

    func rows(processIdentifier: pid_t, maxRows: Int) -> [DJLibraryRow] {
        guard let observation = observe(
            processIdentifier: processIdentifier,
            maxRows: maxRows,
            allowCache: false
        ), observation.isCurrent else {
            return []
        }
        return observation.rows
    }

    func observe(
        processIdentifier: pid_t,
        maxRows: Int,
        allowCache: Bool = true
    ) -> RekordboxLibraryObservation? {
        let startedAt = Date()
        guard CGPreflightScreenCaptureAccess() else {
            return allowCache
                ? cachedObservation(maxRows: maxRows, errors: ["screenCapturePermissionMissing"])
                : nil
        }

        if activeProcessIdentifiers.contains(processIdentifier) {
            return allowCache
                ? cachedObservation(maxRows: maxRows, errors: ["ocrAlreadyRunning"])
                : nil
        }
        if let previousAttempt = lastAttemptByProcessIdentifier[processIdentifier],
           startedAt.timeIntervalSince(previousAttempt) < Self.minimumRefreshInterval {
            return allowCache
                ? cachedObservation(maxRows: maxRows, errors: ["ocrRefreshThrottled"])
                : nil
        }

        lastAttemptByProcessIdentifier[processIdentifier] = startedAt
        activeProcessIdentifiers.insert(processIdentifier)
        defer { activeProcessIdentifiers.remove(processIdentifier) }

        let images = windowImages(processIdentifier: processIdentifier)
        var bestResult: RecognitionResult?
        var partialErrors: [String] = images.isEmpty ? ["rekordboxWindowCaptureUnavailable"] : []

        for image in images {
            let result = recognize(in: image, maxRows: maxRows)
            partialErrors.append(contentsOf: result.errors)
            guard !result.parseResult.rows.isEmpty else { continue }
            if bestResult == nil ||
                result.parseResult.rows.count > bestResult?.parseResult.rows.count ?? 0 ||
                (result.parseResult.rows.count == bestResult?.parseResult.rows.count &&
                    result.parseResult.confidence > bestResult?.parseResult.confidence ?? 0) {
                bestResult = result
            }
        }

        if let bestResult {
            let observedAt = Date()
            if let cacheError = saveCache(
                bestResult.parseResult.rows,
                confidence: bestResult.parseResult.confidence,
                fragmentCount: bestResult.fragmentCount,
                generatedAt: observedAt
            ) {
                partialErrors.append(cacheError)
            }
            return RekordboxLibraryObservation(
                rows: bestResult.parseResult.rows,
                source: .freshOCR(observedAt: observedAt),
                collectedAt: observedAt,
                durationSeconds: observedAt.timeIntervalSince(startedAt),
                fragmentCount: bestResult.fragmentCount,
                confidence: bestResult.parseResult.confidence,
                partialErrors: Array(Set(partialErrors)).sorted()
            )
        }

        return allowCache
            ? cachedObservation(
                maxRows: maxRows,
                errors: Array(Set(partialErrors + ["freshOCRDidNotRecognizeRows"])).sorted()
            )
            : nil
    }

    func cachedObservation(
        maxRows: Int,
        now: Date = Date(),
        errors: [String] = []
    ) -> RekordboxLibraryObservation? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: cacheURL)
            let cache = try JSONDecoder().decode(Cache.self, from: data)
            guard now.timeIntervalSince(cache.generatedAt) <= Self.cacheLifetime else {
                try? FileManager.default.removeItem(at: cacheURL)
                return nil
            }
            let rows = cache.fields.prefix(max(1, maxRows)).enumerated().map {
                DJLibraryRow(index: $0.offset, fields: $0.element)
            }
            return RekordboxLibraryObservation(
                rows: rows,
                source: .cachedOCR(observedAt: cache.generatedAt),
                collectedAt: now,
                fragmentCount: cache.fragmentCount,
                confidence: cache.confidence,
                partialErrors: errors
            )
        } catch {
            quarantineCorruptedCache()
            return nil
        }
    }

    private func recognize(in image: CGImage, maxRows: Int) -> RecognitionResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["fr-FR", "en-US", "es-ES"]
        request.usesLanguageCorrection = true

        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            return RecognitionResult(
                parseResult: RekordboxOCRParseResult(
                    rows: [],
                    confidence: 0,
                    usedGeometricFallback: false
                ),
                fragmentCount: 0,
                errors: ["visionRequestFailed:\(String(describing: type(of: error)))"]
            )
        }
        let fragments = (request.results ?? []).compactMap { observation -> RekordboxOCRFragment? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return RekordboxOCRFragment(text: text, bounds: observation.boundingBox)
        }
        let parsed = RekordboxPlaylistOCRParser().parse(
            fragments: fragments,
            maxRows: maxRows
        )
        return RecognitionResult(
            parseResult: parsed,
            fragmentCount: fragments.count,
            errors: parsed.usedGeometricFallback ? ["ocrHeadersNotRecognizedUsedGeometry"] : []
        )
    }

    private func windowImages(processIdentifier: pid_t) -> [CGImage] {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }
        let windowIDs = windows.compactMap { window -> CGWindowID? in
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == processIdentifier,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let identifier = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value else {
                return nil
            }
            return identifier
        }
        return windowIDs.compactMap { windowID in
            CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.boundsIgnoreFraming, .bestResolution]
            )
        }
    }

    private func saveCache(
        _ rows: [DJLibraryRow],
        confidence: Double,
        fragmentCount: Int,
        generatedAt: Date
    ) -> String? {
        let cache = Cache(
            generatedAt: generatedAt,
            fields: rows.map(\.fields),
            confidence: confidence,
            fragmentCount: fragmentCount
        )
        do {
            let data = try JSONEncoder().encode(cache)
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: cacheURL, options: .atomic)
            return nil
        } catch {
            return "ocrCacheWriteFailed:\(String(describing: type(of: error)))"
        }
    }

    private func quarantineCorruptedCache() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        let quarantineURL = cacheURL
            .deletingPathExtension()
            .appendingPathExtension("corrupt-\(UUID().uuidString).json")
        do {
            try FileManager.default.moveItem(at: cacheURL, to: quarantineURL)
        } catch {
            try? FileManager.default.removeItem(at: cacheURL)
        }
    }

    private var cacheURL: URL {
        let supportRoot = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return supportRoot
            .appendingPathComponent("MixPilot", isDirectory: true)
            .appendingPathComponent("rekordbox-visible-playlist.json")
    }
}
#endif
