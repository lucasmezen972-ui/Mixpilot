import Foundation

public enum DiagnosticValidationStatus: String, Codable, Sendable {
    case realSuccess
    case simulatedSuccess
    case requiresValidation
    case failed
    case unavailable
}

public struct DiagnosticValidation: Identifiable, Codable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var status: DiagnosticValidationStatus
    public var detail: String

    public init(name: String, status: DiagnosticValidationStatus, detail: String) {
        self.name = name
        self.status = status
        self.detail = detail
    }
}

public struct DiagnosticSnapshot: Codable, Hashable, Sendable {
    public var generatedAt: Date
    public var appVersion: String
    public var operatingSystem: String
    public var architecture: String
    public var seratoRunning: Bool
    public var accessibilityGranted: Bool
    public var midiMappingCompletion: Double
    public var audioMonitorRunning: Bool
    public var internetAvailable: Bool
    public var connectedToPower: Bool
    public var emergencyDuration: TimeInterval
    public var projectTrackCount: Int
    public var projectTransitionCount: Int
    public var projectLocked: Bool
    public var autopilotState: AutopilotState
    public var completedTransitions: Int
    public var validations: [DiagnosticValidation]
    public var recentEvents: [String]

    public init(
        generatedAt: Date = Date(),
        appVersion: String,
        operatingSystem: String,
        architecture: String,
        seratoRunning: Bool,
        accessibilityGranted: Bool,
        midiMappingCompletion: Double,
        audioMonitorRunning: Bool,
        internetAvailable: Bool,
        connectedToPower: Bool,
        emergencyDuration: TimeInterval,
        projectTrackCount: Int,
        projectTransitionCount: Int,
        projectLocked: Bool,
        autopilotState: AutopilotState,
        completedTransitions: Int,
        validations: [DiagnosticValidation],
        recentEvents: [String]
    ) {
        self.generatedAt = generatedAt
        self.appVersion = appVersion
        self.operatingSystem = operatingSystem
        self.architecture = architecture
        self.seratoRunning = seratoRunning
        self.accessibilityGranted = accessibilityGranted
        self.midiMappingCompletion = midiMappingCompletion.clamped(to: 0...1)
        self.audioMonitorRunning = audioMonitorRunning
        self.internetAvailable = internetAvailable
        self.connectedToPower = connectedToPower
        self.emergencyDuration = max(0, emergencyDuration)
        self.projectTrackCount = max(0, projectTrackCount)
        self.projectTransitionCount = max(0, projectTransitionCount)
        self.projectLocked = projectLocked
        self.autopilotState = autopilotState
        self.completedTransitions = max(0, completedTransitions)
        self.validations = validations
        self.recentEvents = recentEvents.map(DiagnosticRedactor.redact)
    }
}

public struct DiagnosticExportResult: Hashable, Sendable {
    public var jsonURL: URL
    public var markdownURL: URL

    public init(jsonURL: URL, markdownURL: URL) {
        self.jsonURL = jsonURL
        self.markdownURL = markdownURL
    }
}

public actor DiagnosticExporter {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func export(_ snapshot: DiagnosticSnapshot) throws -> DiagnosticExportResult {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = Self.fileStamp(snapshot.generatedAt)
        let jsonURL = directory.appendingPathComponent("MixPilot-Diagnostic-\(stamp).json")
        let markdownURL = directory.appendingPathComponent("MixPilot-Diagnostic-\(stamp).md")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: jsonURL, options: .atomic)
        try markdown(snapshot).write(to: markdownURL, atomically: true, encoding: .utf8)
        return DiagnosticExportResult(jsonURL: jsonURL, markdownURL: markdownURL)
    }

    private func markdown(_ snapshot: DiagnosticSnapshot) -> String {
        let validationLines = snapshot.validations.map {
            "- **\($0.name)** — `\($0.status.rawValue)` — \(DiagnosticRedactor.redact($0.detail))"
        }.joined(separator: "\n")
        let eventLines = snapshot.recentEvents.suffix(100).map { "- \($0)" }.joined(separator: "\n")
        return """
        # Diagnostic MixPilot Autopilot

        - Généré : \(snapshot.generatedAt.formatted(date: .numeric, time: .standard))
        - Version : \(snapshot.appVersion)
        - macOS : \(snapshot.operatingSystem)
        - Architecture : \(snapshot.architecture)
        - État Autopilot : \(snapshot.autopilotState.rawValue)
        - Transitions : \(snapshot.completedTransitions)/\(snapshot.projectTransitionCount)

        ## Environnement

        - Serato lancé : \(snapshot.seratoRunning ? "oui" : "non")
        - Accessibilité : \(snapshot.accessibilityGranted ? "oui" : "non")
        - Mapping MIDI : \(Int(snapshot.midiMappingCompletion * 100)) %
        - Surveillance audio : \(snapshot.audioMonitorRunning ? "oui" : "non")
        - Internet : \(snapshot.internetAvailable ? "oui" : "non")
        - Secteur : \(snapshot.connectedToPower ? "oui" : "non")
        - Secours local : \(Int(snapshot.emergencyDuration / 60)) min

        ## Validations

        \(validationLines)

        ## Événements récents

        \(eventLines.isEmpty ? "- Aucun événement" : eventLines)
        """
    }

    private static func fileStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}

public actor IncidentJournal {
    private let fileURL: URL
    private let maximumBytes: Int

    public init(fileURL: URL, maximumBytes: Int = 2_000_000) {
        self.fileURL = fileURL
        self.maximumBytes = max(50_000, maximumBytes)
    }

    public func append(_ incident: Incident) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try rotateIfNeeded()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(incident)
        data.append(0x0A)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }

    public func readRecent(limit: Int = 200) throws -> [Incident] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return data.split(separator: 0x0A)
            .suffix(max(0, limit))
            .compactMap { try? decoder.decode(Incident.self, from: Data($0)) }
    }

    private func rotateIfNeeded() throws {
        guard let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size >= maximumBytes else { return }
        let rotated = fileURL.deletingPathExtension().appendingPathExtension("previous.jsonl")
        try? FileManager.default.removeItem(at: rotated)
        try FileManager.default.moveItem(at: fileURL, to: rotated)
    }
}

public enum DiagnosticRedactor {
    public static func redact(_ value: String) -> String {
        var output = value
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if !home.isEmpty {
            output = output.replacingOccurrences(of: home, with: "~")
        }
        let patterns = [
            #"(?i)(token|secret|password|api[_-]?key)\s*[:=]\s*[^\s]+"#,
            #"[A-F0-9]{32,}"#,
            #"sk-[A-Za-z0-9_-]{12,}"#,
        ]
        for pattern in patterns {
            output = output.replacingOccurrences(
                of: pattern,
                with: "[REDACTED]",
                options: .regularExpression
            )
        }
        return output
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
