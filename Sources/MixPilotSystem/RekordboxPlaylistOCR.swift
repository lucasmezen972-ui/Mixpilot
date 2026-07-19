#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import Vision

struct RekordboxOCRFragment: Hashable, Sendable {
    var text: String
    var bounds: CGRect
}

struct RekordboxPlaylistOCRParser: Sendable {
    func rows(from fragments: [RekordboxOCRFragment], maxRows: Int) -> [DJLibraryRow] {
        let normalized = fragments.compactMap { fragment -> RekordboxOCRFragment? in
            let text = fragment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : RekordboxOCRFragment(text: text, bounds: fragment.bounds)
        }
        guard let titleHeader = header(named: "titre du morceau", in: normalized),
              let artistHeader = normalized
                .filter({ isHeader($0.text, named: "artiste") && $0.bounds.minX > titleHeader.bounds.minX })
                .min(by: { $0.bounds.minX < $1.bounds.minX }) else {
            return []
        }

        let headerFloor = min(titleHeader.bounds.minY, artistHeader.bounds.minY)
        let titleMinimumX = titleHeader.bounds.minX - 0.025
        let artistMinimumX = artistHeader.bounds.minX - 0.025
        let titleMaximumX = artistMinimumX - 0.005
        let artistMaximumX = min(0.68, artistHeader.bounds.maxX + 0.09)
        let titleFragments = normalized.filter {
            $0.bounds.midY < headerFloor &&
                $0.bounds.minX >= titleMinimumX &&
                $0.bounds.minX < titleMaximumX
        }.sorted { $0.bounds.midY > $1.bounds.midY }
        let artistFragments = normalized.filter {
            $0.bounds.midY < headerFloor &&
                $0.bounds.minX >= artistMinimumX &&
                $0.bounds.minX < artistMaximumX
        }

        var usedArtists = Set<Int>()
        var rows: [DJLibraryRow] = []
        for title in titleFragments where rows.count < max(1, maxRows) {
            let match = artistFragments.enumerated()
                .filter { !usedArtists.contains($0.offset) }
                .filter { abs($0.element.bounds.midY - title.bounds.midY) <= 0.012 }
                .min { lhs, rhs in
                    abs(lhs.element.bounds.midY - title.bounds.midY) <
                        abs(rhs.element.bounds.midY - title.bounds.midY)
                }
            var fields = [title.text]
            if let match {
                usedArtists.insert(match.offset)
                fields.append(match.element.text)
            }
            rows.append(DJLibraryRow(index: rows.count, fields: fields))
        }
        return rows
    }

    private func header(named name: String, in fragments: [RekordboxOCRFragment]) -> RekordboxOCRFragment? {
        fragments
            .filter { isHeader($0.text, named: name) }
            .filter { $0.bounds.minX >= 0.25 && $0.bounds.minX < 0.68 }
            .min { $0.bounds.minX < $1.bounds.minX }
    }

    private func isHeader(_ text: String, named name: String) -> Bool {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines) == name
    }
}

@MainActor
final class RekordboxPlaylistOCRReader {
    private struct Cache: Codable {
        var generatedAt: Date
        var fields: [[String]]
    }

    func rows(processIdentifier: pid_t, maxRows: Int) -> [DJLibraryRow] {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            return cachedRows(maxRows: maxRows)
        }
        for image in windowImages(processIdentifier: processIdentifier) {
            let rows = recognizedRows(in: image, maxRows: maxRows)
            if !rows.isEmpty {
                saveCache(rows)
                return rows
            }
        }
        return cachedRows(maxRows: maxRows)
    }

    private func recognizedRows(in image: CGImage, maxRows: Int) -> [DJLibraryRow] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["fr-FR", "en-US"]
        request.usesLanguageCorrection = true

        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            return []
        }
        let fragments = (request.results ?? []).compactMap { observation -> RekordboxOCRFragment? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return RekordboxOCRFragment(text: text, bounds: observation.boundingBox)
        }
        return RekordboxPlaylistOCRParser().rows(from: fragments, maxRows: maxRows)
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

    private func cachedRows(maxRows: Int) -> [DJLibraryRow] {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(Cache.self, from: data),
              Date().timeIntervalSince(cache.generatedAt) <= 6 * 60 * 60 else {
            return []
        }
        return cache.fields.prefix(max(1, maxRows)).enumerated().map {
            DJLibraryRow(index: $0.offset, fields: $0.element)
        }
    }

    private func saveCache(_ rows: [DJLibraryRow]) {
        let cache = Cache(generatedAt: Date(), fields: rows.map(\.fields))
        guard let data = try? JSONEncoder().encode(cache) else { return }
        let directory = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try? data.write(to: cacheURL, options: .atomic)
    }

    private var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MixPilot", isDirectory: true)
            .appendingPathComponent("rekordbox-visible-playlist.json")
    }
}
#endif
