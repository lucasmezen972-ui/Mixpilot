import Foundation

public enum PreflightSeverity: String, Codable, Comparable, Sendable {
    case information
    case warning
    case critical

    public static func < (lhs: PreflightSeverity, rhs: PreflightSeverity) -> Bool {
        let order: [PreflightSeverity] = [.information, .warning, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

public enum PreflightItemStatus: String, Codable, Sendable {
    case passed
    case warning
    case failed
    case notTested
}

public struct PreflightItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var detail: String
    public var status: PreflightItemStatus
    public var severity: PreflightSeverity

    public init(
        id: String,
        title: String,
        detail: String,
        status: PreflightItemStatus,
        severity: PreflightSeverity
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.severity = severity
    }
}

public struct PreflightInput: Codable, Hashable, Sendable {
    public var seratoRunning: Bool
    public var accessibilityGranted: Bool
    public var midiAvailable: Bool
    public var mappingCompletion: Double
    public var audioMonitorRunning: Bool
    public var internetAvailable: Bool
    public var connectedToPower: Bool
    public var batteryLevel: Double?
    public var emergencyAudioReady: Bool
    public var emergencyDuration: TimeInterval
    public var projectPrepared: Bool
    public var projectLocked: Bool
    public var trackCount: Int
    public var transitionCount: Int
    public var lowConfidenceTransitionCount: Int
    public var djSoftware: DJSoftware

    public init(
        seratoRunning: Bool,
        accessibilityGranted: Bool,
        midiAvailable: Bool,
        mappingCompletion: Double,
        audioMonitorRunning: Bool,
        internetAvailable: Bool,
        connectedToPower: Bool,
        batteryLevel: Double?,
        emergencyAudioReady: Bool,
        emergencyDuration: TimeInterval,
        projectPrepared: Bool,
        projectLocked: Bool,
        trackCount: Int,
        transitionCount: Int,
        lowConfidenceTransitionCount: Int,
        djSoftware: DJSoftware = .serato
    ) {
        self.seratoRunning = seratoRunning
        self.accessibilityGranted = accessibilityGranted
        self.midiAvailable = midiAvailable
        self.mappingCompletion = mappingCompletion.clamped(to: 0...1)
        self.audioMonitorRunning = audioMonitorRunning
        self.internetAvailable = internetAvailable
        self.connectedToPower = connectedToPower
        self.batteryLevel = batteryLevel?.clamped(to: 0...1)
        self.emergencyAudioReady = emergencyAudioReady
        self.emergencyDuration = max(0, emergencyDuration)
        self.projectPrepared = projectPrepared
        self.projectLocked = projectLocked
        self.trackCount = max(0, trackCount)
        self.transitionCount = max(0, transitionCount)
        self.lowConfidenceTransitionCount = max(0, lowConfidenceTransitionCount)
        self.djSoftware = djSoftware
    }
}

public struct PreflightReport: Codable, Hashable, Sendable {
    public var generatedAt: Date
    public var items: [PreflightItem]

    public init(generatedAt: Date = Date(), items: [PreflightItem]) {
        self.generatedAt = generatedAt
        self.items = items
    }

    public var canStartLive: Bool {
        !items.contains { $0.status == .failed && $0.severity == .critical }
    }

    public var failedItems: [PreflightItem] {
        items.filter { $0.status == .failed }
    }

    public var warningItems: [PreflightItem] {
        items.filter { $0.status == .warning }
    }
}

public struct PreflightEvaluator: Sendable {
    public init() {}

    public func evaluate(_ input: PreflightInput) -> PreflightReport {
        var items: [PreflightItem] = []
        items.append(booleanItem(
            id: "dj-software",
            title: input.djSoftware.displayName,
            passed: input.seratoRunning,
            success: "\(input.djSoftware.displayName) est lancé.",
            failure: "\(input.djSoftware.displayName) doit être lancé.",
            severity: .critical
        ))
        items.append(booleanItem(
            id: "accessibility",
            title: "Permission Accessibilité",
            passed: input.accessibilityGranted,
            success: "L'interface de \(input.djSoftware.shortName) peut être observée.",
            failure: "Autorise MixPilot dans Confidentialité et sécurité → Accessibilité.",
            severity: .critical
        ))

        let directDeckControl = input.djSoftware.capabilities.preferredExecutionMode == .directDeckControl
        items.append(capabilityItem(
            id: "midi",
            title: "Port MIDI",
            available: input.midiAvailable,
            required: directDeckControl,
            success: "MixPilot Virtual Controller est actif.",
            optional: "Optionnel avec la file Automix de djay.",
            failure: "Le port MIDI virtuel n'est pas disponible."
        ))

        let mappingPassed = input.mappingCompletion >= 0.95
        items.append(capabilityItem(
            id: "mapping",
            title: "Mapping MIDI",
            available: mappingPassed,
            required: directDeckControl,
            success: "Les commandes principales sont configurées.",
            optional: "Aucun mapping MIDI n’est requis pour démarrer un set djay Automix.",
            failure: "Seulement \(Int(input.mappingCompletion * 100)) % des commandes sont configurées."
        ))

        items.append(booleanItem(
            id: "audio",
            title: "Surveillance audio",
            passed: input.audioMonitorRunning,
            success: "Le watchdog audio est actif.",
            failure: "Démarre la surveillance audio avant la soirée.",
            severity: .critical
        ))
        items.append(booleanItem(
            id: "internet",
            title: "Connexion Internet",
            passed: input.internetAvailable,
            success: "Internet est disponible.",
            failure: "Spotify dépend d'une connexion Internet active.",
            severity: .critical
        ))

        items.append(PreflightItem(
            id: "power",
            title: "Alimentation",
            detail: input.connectedToPower
                ? "Le Mac est branché au secteur."
                : "Le Mac fonctionne sur batterie (\(Int((input.batteryLevel ?? 0) * 100)) %). Le branchement secteur reste recommandé pour un long set.",
            status: input.connectedToPower ? .passed : .warning,
            severity: input.connectedToPower ? .information : .warning
        ))

        let emergencyOK = input.emergencyAudioReady && input.emergencyDuration >= 1_800
        items.append(PreflightItem(
            id: "emergency",
            title: "Musique locale de secours",
            detail: emergencyOK
                ? "Au moins 30 minutes de secours sont disponibles."
                : "Optionnelle : aucun secours local n’est configuré. Une coupure Internet ne pourra pas être couverte automatiquement.",
            status: emergencyOK ? .passed : .warning,
            severity: emergencyOK ? .information : .warning
        ))

        let projectOK = input.projectPrepared && input.projectLocked && input.trackCount >= 2 &&
            input.transitionCount == input.trackCount - 1
        items.append(PreflightItem(
            id: "project",
            title: "Plan du set",
            detail: projectOK
                ? "\(input.trackCount) titres et \(input.transitionCount) transitions verrouillées."
                : "Le set doit contenir au moins deux titres, toutes les transitions et être verrouillé.",
            status: projectOK ? .passed : .failed,
            severity: .critical
        ))

        items.append(PreflightItem(
            id: "confidence",
            title: "Transitions à vérifier",
            detail: input.lowConfidenceTransitionCount == 0
                ? "Aucune transition à faible confiance."
                : "\(input.lowConfidenceTransitionCount) transition(s) restent sous le seuil de confiance.",
            status: input.lowConfidenceTransitionCount == 0 ? .passed : .warning,
            severity: .warning
        ))

        return PreflightReport(items: items)
    }

    private func capabilityItem(
        id: String,
        title: String,
        available: Bool,
        required: Bool,
        success: String,
        optional: String,
        failure: String
    ) -> PreflightItem {
        if available {
            return PreflightItem(
                id: id,
                title: title,
                detail: success,
                status: .passed,
                severity: required ? .critical : .information
            )
        }
        return PreflightItem(
            id: id,
            title: title,
            detail: required ? failure : optional,
            status: required ? .failed : .warning,
            severity: required ? .critical : .warning
        )
    }

    private func booleanItem(
        id: String,
        title: String,
        passed: Bool,
        success: String,
        failure: String,
        severity: PreflightSeverity
    ) -> PreflightItem {
        PreflightItem(
            id: id,
            title: title,
            detail: passed ? success : failure,
            status: passed ? .passed : .failed,
            severity: severity
        )
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
