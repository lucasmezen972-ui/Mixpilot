import Foundation

public struct MixPilotDiagnosticSnapshot: Codable, Hashable, Sendable {
    public var generatedAt: Date
    public var appVersion: String
    public var operatingSystem: String
    public var architecture: String
    public var backendIdentifier: DJBackendIdentifier?
    public var backendSoftwareVersion: String?
    public var backendRunning: Bool
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
        backendIdentifier: DJBackendIdentifier?,
        backendSoftwareVersion: String?,
        backendRunning: Bool,
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
        self.backendIdentifier = backendIdentifier
        self.backendSoftwareVersion = backendSoftwareVersion
        self.backendRunning = backendRunning
        self.accessibilityGranted = accessibilityGranted
        self.midiMappingCompletion = min(max(midiMappingCompletion, 0), 1)
        self.audioMonitorRunning = audioMonitorRunning
        self.internetAvailable = internetAvailable
        self.connectedToPower = connectedToPower
        self.emergencyDuration = max(0, emergencyDuration)
        self.projectTrackCount = max(0, projectTrackCount)
        self.projectTransitionCount = max(0, projectTransitionCount)
        self.projectLocked = projectLocked
        self.autopilotState = autopilotState
        self.completedTransitions = max(0, completedTransitions)
        self.validations = validations.map {
            DiagnosticValidation(
                name: DiagnosticRedactor.redact($0.name),
                status: $0.status,
                detail: DiagnosticRedactor.redact($0.detail)
            )
        }
        self.recentEvents = recentEvents.map(DiagnosticRedactor.redact)
    }
}

public actor MixPilotDiagnosticExporter {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func export(_ snapshot: MixPilotDiagnosticSnapshot) throws -> DiagnosticExportResult {
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

    private func markdown(_ snapshot: MixPilotDiagnosticSnapshot) -> String {
        let backend = snapshot.backendIdentifier?.displayName ?? "Non sélectionné"
        let version = snapshot.backendSoftwareVersion.map { " • version \($0)" } ?? ""
        let validationLines = snapshot.validations.map {
            "- **\($0.name)** — `\($0.status.rawValue)` — \($0.detail)"
        }.joined(separator: "\n")
        let eventLines = snapshot.recentEvents.suffix(100).map { "- \($0)" }.joined(separator: "\n")

        return """
        # Diagnostic MixPilot

        - Généré : \(snapshot.generatedAt.formatted(date: .numeric, time: .standard))
        - Version : \(snapshot.appVersion)
        - macOS : \(snapshot.operatingSystem)
        - Architecture : \(snapshot.architecture)
        - État Autopilote : \(snapshot.autopilotState.rawValue)
        - Transitions : \(snapshot.completedTransitions)/\(snapshot.projectTransitionCount)

        ## Environnement

        - Backend DJ : \(backend)\(version)
        - Logiciel lancé : \(snapshot.backendRunning ? "oui" : "non")
        - Accessibilité : \(snapshot.accessibilityGranted ? "oui" : "non")
        - Mapping MIDI : \(Int(snapshot.midiMappingCompletion * 100)) %
        - Surveillance audio : \(snapshot.audioMonitorRunning ? "oui" : "non")
        - Internet : \(snapshot.internetAvailable ? "oui" : "non")
        - Secteur : \(snapshot.connectedToPower ? "oui" : "non")
        - Musique de secours : \(Int(snapshot.emergencyDuration / 60)) min

        ## Validations

        \(validationLines)

        ## Événements récents anonymisés

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
