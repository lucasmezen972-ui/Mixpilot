import Foundation

public struct DiagnosticEnvironment: Codable, Hashable, Sendable {
    public var seratoStatus: String
    public var midiStatus: String
    public var accessibilityStatus: String
    public var audioStatus: String
    public var libraryRowCount: Int
    public var emergencyStatus: String

    public init(
        seratoStatus: String,
        midiStatus: String,
        accessibilityStatus: String,
        audioStatus: String,
        libraryRowCount: Int,
        emergencyStatus: String
    ) {
        self.seratoStatus = seratoStatus
        self.midiStatus = midiStatus
        self.accessibilityStatus = accessibilityStatus
        self.audioStatus = audioStatus
        self.libraryRowCount = max(0, libraryRowCount)
        self.emergencyStatus = emergencyStatus
    }
}

public struct DiagnosticProjectSummary: Codable, Hashable, Sendable {
    public var name: String?
    public var trackCount: Int
    public var transitionCount: Int
    public var locked: Bool
    public var reviewTransitionCount: Int

    public init(project: SetProject?) {
        name = project?.name
        trackCount = project?.tracks.count ?? 0
        transitionCount = project?.transitions.count ?? 0
        locked = project?.locked ?? false
        reviewTransitionCount = project?.reviewTransitionCount ?? 0
    }
}

public struct DiagnosticReport: Codable, Hashable, Sendable {
    public var generatedAt: Date
    public var appVersion: String
    public var environment: DiagnosticEnvironment
    public var project: DiagnosticProjectSummary
    public var runtimeState: AutopilotState
    public var runtimeStatus: String
    public var recentEvents: [String]
    public var preflight: PreflightReport?
    public var validationLabels: [String: String]

    public init(
        generatedAt: Date = Date(),
        appVersion: String,
        environment: DiagnosticEnvironment,
        project: DiagnosticProjectSummary,
        runtimeState: AutopilotState,
        runtimeStatus: String,
        recentEvents: [String],
        preflight: PreflightReport?,
        validationLabels: [String: String]
    ) {
        self.generatedAt = generatedAt
        self.appVersion = appVersion
        self.environment = environment
        self.project = project
        self.runtimeState = runtimeState
        self.runtimeStatus = runtimeStatus
        self.recentEvents = Array(recentEvents.suffix(200))
        self.preflight = preflight
        self.validationLabels = validationLabels
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public func plainText() -> String {
        var lines = [
            "MixPilot Autopilot — Rapport de diagnostic",
            "Généré : \(generatedAt.formatted(date: .numeric, time: .standard))",
            "Version : \(appVersion)",
            "",
            "ENVIRONNEMENT",
            "Serato : \(environment.seratoStatus)",
            "MIDI : \(environment.midiStatus)",
            "Accessibilité : \(environment.accessibilityStatus)",
            "Audio : \(environment.audioStatus)",
            "Bibliothèque visible : \(environment.libraryRowCount) lignes",
            "Secours : \(environment.emergencyStatus)",
            "",
            "PROJET",
            "Nom : \(project.name ?? "Aucun")",
            "Titres : \(project.trackCount)",
            "Transitions : \(project.transitionCount)",
            "Verrouillé : \(project.locked ? "Oui" : "Non")",
            "Transitions à vérifier : \(project.reviewTransitionCount)",
            "",
            "RUNTIME",
            "État : \(runtimeState.rawValue)",
            "Statut : \(runtimeStatus)",
        ]

        if let preflight {
            lines.append("")
            lines.append("PREFLIGHT")
            lines.append("Live autorisé : \(preflight.canStartLive ? "Oui" : "Non")")
            for item in preflight.items {
                lines.append("[\(item.status.rawValue.uppercased())] \(item.title) — \(item.detail)")
            }
        }

        lines.append("")
        lines.append("VALIDATIONS")
        for key in validationLabels.keys.sorted() {
            lines.append("\(key) : \(validationLabels[key] ?? "Inconnu")")
        }

        lines.append("")
        lines.append("ÉVÉNEMENTS RÉCENTS")
        lines.append(contentsOf: recentEvents.isEmpty ? ["Aucun événement"] : recentEvents)
        return lines.joined(separator: "\n")
    }
}
