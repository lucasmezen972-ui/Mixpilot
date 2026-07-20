#if os(macOS)
import AppKit
import Foundation

public struct RekordboxInstallation: Codable, Hashable, Sendable {
    public var applicationURL: URL
    public var bundleIdentifier: String?
    public var version: String?
    public var displayName: String

    public init(
        applicationURL: URL,
        bundleIdentifier: String?,
        version: String?,
        displayName: String
    ) {
        self.applicationURL = applicationURL.standardizedFileURL
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.displayName = displayName
    }
}

public struct RekordboxEnvironmentStatus: Codable, Hashable, Sendable {
    public var isInstalled: Bool
    public var isRunning: Bool
    public var processIdentifier: Int32?
    public var applicationName: String?
    public var bundleIdentifier: String?
    public var applicationURL: URL?
    public var installedVersion: String?
    public var runningVersion: String?
    public var installations: [RekordboxInstallation]

    public init(
        isRunning: Bool,
        processIdentifier: Int32?,
        applicationName: String?,
        bundleIdentifier: String?,
        isInstalled: Bool? = nil,
        applicationURL: URL? = nil,
        installedVersion: String? = nil,
        runningVersion: String? = nil,
        installations: [RekordboxInstallation] = []
    ) {
        self.isInstalled = isInstalled ?? (isRunning || applicationURL != nil || !installations.isEmpty)
        self.isRunning = isRunning
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.applicationURL = applicationURL?.standardizedFileURL
        self.installedVersion = installedVersion
        self.runningVersion = runningVersion
        self.installations = installations
    }
}

public enum RekordboxApplicationMatcher {
    public static let knownBundleIdentifiers = [
        "com.alphatheta.rekordbox",
        "com.pioneerdj.rekordbox",
        "com.pioneerdj.rekordboxdj",
    ]

    public static func matches(
        name: String?,
        bundleIdentifier: String? = nil,
        bundleURL: URL? = nil
    ) -> Bool {
        let normalizedName = normalized(name)
        let normalizedBundle = normalized(bundleIdentifier)
        let normalizedFileName = normalized(bundleURL?.deletingPathExtension().lastPathComponent)

        return normalizedName == "rekordbox" ||
            normalizedName.hasPrefix("rekordbox ") ||
            normalizedFileName == "rekordbox" ||
            normalizedFileName.hasPrefix("rekordbox ") ||
            normalizedBundle.contains("rekordbox")
    }

    public static func majorVersionHint(
        name: String?,
        version: String? = nil,
        bundleURL: URL? = nil
    ) -> Int? {
        if let version,
           let major = Int(version.split(separator: ".").first ?? ""),
           major > 0 {
            return major
        }
        let haystack = [name, bundleURL?.deletingPathExtension().lastPathComponent]
            .compactMap { $0 }
            .joined(separator: " ")
        let pattern = #"(?i)rekordbox\s*([0-9]+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: haystack,
                range: NSRange(haystack.startIndex..., in: haystack)
              ),
              let range = Range(match.range(at: 1), in: haystack) else {
            return nil
        }
        return Int(haystack[range])
    }

    private static func normalized(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }
}

public enum RekordboxInstallationLocator {
    public static func standardSearchRoots(homeDirectory: URL) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    public static func discoverApplicationURLs(
        searchRoots: [URL],
        fileManager: FileManager = .default,
        maximumDepth: Int = 4
    ) -> [URL] {
        var results = Set<URL>()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isApplicationKey]

        for root in searchRoots.map(\.standardizedFileURL) {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            if RekordboxApplicationMatcher.matches(name: nil, bundleURL: root),
               root.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
                results.insert(root)
                continue
            }

            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            for case let candidate as URL in enumerator {
                let depth = max(0, candidate.pathComponents.count - root.pathComponents.count)
                if depth > max(1, maximumDepth) {
                    enumerator.skipDescendants()
                    continue
                }
                guard candidate.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
                    continue
                }
                enumerator.skipDescendants()
                if RekordboxApplicationMatcher.matches(name: nil, bundleURL: candidate) {
                    results.insert(candidate.standardizedFileURL)
                }
            }
        }

        return results.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
}

public enum RekordboxDetectionError: Error, LocalizedError {
    case notInstalled

    public var errorDescription: String? {
        switch self {
        case .notInstalled:
            "Rekordbox 6 ou 7 n’a pas été trouvé. Installe-le ou choisis son application depuis les réglages MixPilot."
        }
    }
}

@MainActor
public final class RekordboxApplicationDetector {
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    public init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    public func detect(additionalSearchRoots: [URL] = []) -> RekordboxEnvironmentStatus {
        let running = runningApplication()
        let installations = detectedInstallations(
            runningApplication: running,
            additionalSearchRoots: additionalSearchRoots
        )
        let runningURL = running?.bundleURL?.standardizedFileURL
        let preferred = installations.first { $0.applicationURL == runningURL }
            ?? installations.sorted(by: preferredInstallation).first
        let runningBundle = runningURL.flatMap(Bundle.init(url:))

        return RekordboxEnvironmentStatus(
            isRunning: running != nil,
            processIdentifier: running?.processIdentifier,
            applicationName: running?.localizedName ?? preferred?.displayName,
            bundleIdentifier: running?.bundleIdentifier ?? preferred?.bundleIdentifier,
            isInstalled: running != nil || !installations.isEmpty,
            applicationURL: runningURL ?? preferred?.applicationURL,
            installedVersion: preferred?.version,
            runningVersion: version(from: runningBundle),
            installations: installations
        )
    }

    public func runningApplication() -> NSRunningApplication? {
        workspace.runningApplications.first { application in
            RekordboxApplicationMatcher.matches(
                name: application.localizedName,
                bundleIdentifier: application.bundleIdentifier,
                bundleURL: application.bundleURL
            )
        }
    }

    @discardableResult
    public func open(additionalSearchRoots: [URL] = []) async throws -> RekordboxEnvironmentStatus {
        let current = detect(additionalSearchRoots: additionalSearchRoots)
        if let running = runningApplication() {
            _ = running.activate(options: [.activateAllWindows])
            return current
        }
        guard let applicationURL = current.applicationURL else {
            throw RekordboxDetectionError.notInstalled
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await workspace.openApplication(
            at: applicationURL,
            configuration: configuration
        )
        return detect(additionalSearchRoots: additionalSearchRoots)
    }

    private func detectedInstallations(
        runningApplication: NSRunningApplication?,
        additionalSearchRoots: [URL]
    ) -> [RekordboxInstallation] {
        var candidateURLs = Set<URL>()
        if let runningURL = runningApplication?.bundleURL?.standardizedFileURL {
            candidateURLs.insert(runningURL)
        }
        for identifier in RekordboxApplicationMatcher.knownBundleIdentifiers {
            if let url = workspace.urlForApplication(withBundleIdentifier: identifier) {
                candidateURLs.insert(url.standardizedFileURL)
            }
        }
        let roots = RekordboxInstallationLocator.standardSearchRoots(
            homeDirectory: fileManager.homeDirectoryForCurrentUser
        ) + additionalSearchRoots
        candidateURLs.formUnion(
            RekordboxInstallationLocator.discoverApplicationURLs(
                searchRoots: roots,
                fileManager: fileManager
            )
        )

        return candidateURLs.compactMap(installation).sorted(by: preferredInstallation)
    }

    private func installation(at url: URL) -> RekordboxInstallation? {
        let bundle = Bundle(url: url)
        let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let identifier = bundle?.bundleIdentifier
        guard RekordboxApplicationMatcher.matches(
            name: displayName,
            bundleIdentifier: identifier,
            bundleURL: url
        ) else {
            return nil
        }
        return RekordboxInstallation(
            applicationURL: url,
            bundleIdentifier: identifier,
            version: version(from: bundle),
            displayName: displayName
        )
    }

    private func version(from bundle: Bundle?) -> String? {
        (bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
    }

    private func preferredInstallation(
        _ lhs: RekordboxInstallation,
        _ rhs: RekordboxInstallation
    ) -> Bool {
        let lhsMajor = RekordboxApplicationMatcher.majorVersionHint(
            name: lhs.displayName,
            version: lhs.version,
            bundleURL: lhs.applicationURL
        ) ?? 0
        let rhsMajor = RekordboxApplicationMatcher.majorVersionHint(
            name: rhs.displayName,
            version: rhs.version,
            bundleURL: rhs.applicationURL
        ) ?? 0
        if lhsMajor != rhsMajor { return lhsMajor > rhsMajor }
        return lhs.applicationURL.path.localizedStandardCompare(rhs.applicationURL.path) == .orderedAscending
    }
}

@MainActor
public final class RekordboxEnvironmentProbe {
    private let detector: RekordboxApplicationDetector

    public init(detector: RekordboxApplicationDetector = RekordboxApplicationDetector()) {
        self.detector = detector
    }

    public func probe() -> RekordboxEnvironmentStatus {
        detector.detect()
    }
}
#endif
