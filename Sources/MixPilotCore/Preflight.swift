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
    public var backendIdentifier: DJBackendIdentifier?
    public var backendEnvironment: DJBackendEnvironment?
    public var backendCapabilities: DJBackendCapabilities
    public var backendValidation: DJBackendValidationReport?
    public var accessibilityGranted: Bool
    public var midiAvailable: Bool
    public var mappingCompletion: Double
    public var audioMonitorRunning: Bool
    public var internetAvailable: Bool
    public var internetRequiredForPreparedSet: Bool
    public var onlineServicesAvailable: Bool
    public var connectedToPower: Bool
    public var batteryLevel: Double?
    public var emergencyAudioReady: Bool
    public var emergencyDuration: TimeInterval
    public var projectPrepared: Bool
    public var projectLocked: Bool
    public var trackCount: Int
    public var transitionCount: Int
    public var lowConfidenceTransitionCount: Int
    public var fallbackTransitionCount: Int
    public var blockedTransitionCount: Int

    public init(
        backendIdentifier: DJBackendIdentifier?,
        backendEnvironment: DJBackendEnvironment?,
        backendCapabilities: DJBackendCapabilities,
        backendValidation: DJBackendValidationReport? = nil,
        accessibilityGranted: Bool,
        midiAvailable: Bool,
        mappingCompletion: Double,
        audioMonitorRunning: Bool,
        internetAvailable: Bool,
        internetRequiredForPreparedSet: Bool = false,
        onlineServicesAvailable: Bool = true,
        connectedToPower: Bool,
        batteryLevel: Double?,
        emergencyAudioReady: Bool,
        emergencyDuration: TimeInterval,
        projectPrepared: Bool,
        projectLocked: Bool,
        trackCount: Int,
        transitionCount: Int,
        lowConfidenceTransitionCount: Int,
        fallbackTransitionCount: Int = 0,
        blockedTransitionCount: Int = 0
    ) {
        self.backendIdentifier = backendIdentifier
        self.backendEnvironment = backendEnvironment
        self.backendCapabilities = backendCapabilities
        self.backendValidation = backendValidation
        self.accessibilityGranted = accessibilityGranted
        self.midiAvailable = midiAvailable
        self.mappingCompletion = mappingCompletion.clamped(to: 0...1)
        self.audioMonitorRunning = audioMonitorRunning
        self.internetAvailable = internetAvailable
        self.internetRequiredForPreparedSet = internetRequiredForPreparedSet
        self.onlineServicesAvailable = onlineServicesAvailable
        self.connectedToPower = connectedToPower
        self.batteryLevel = batteryLevel?.clamped(to: 0...1)
        self.emergencyAudioReady = emergencyAudioReady
        self.emergencyDuration = max(0, emergencyDuration)
        self.projectPrepared = projectPrepared
        self.projectLocked = projectLocked
        self.trackCount = max(0, trackCount)
        self.transitionCount = max(0, transitionCount)
        self.lowConfidenceTransitionCount = max(0, lowConfidenceTransitionCount)
        self.fallbackTransitionCount = max(0, fallbackTransitionCount)
        self.blockedTransitionCount = max(0, blockedTransitionCount)
    }

    /// Keeps old projects and tests readable while their call sites migrate to
    /// capability snapshots. It does not restore the old implicit Serato choice.
    @available(*, deprecated, message: "Use the backend capability initializer")
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
        djSoftware: DJSoftware = DJSoftwareSelectionStore.current
    ) {
        let identifier: DJBackendIdentifier = switch djSoftware {
        case .djay: .djay
        case .rekordbox: .rekordbox
        case .serato: .serato
        }
        let capabilities = Self.legacyCapabilities(
            identifier: identifier,
            midiAvailable: midiAvailable,
            mappingCompletion: mappingCompletion
        )
        self.init(
            backendIdentifier: identifier,
            backendEnvironment: DJBackendEnvironment(
                identifier: identifier,
                isInstalled: true,
                isRunning: seratoRunning
            ),
            backendCapabilities: capabilities,
            accessibilityGranted: accessibilityGranted,
            midiAvailable: midiAvailable,
            mappingCompletion: mappingCompletion,
            audioMonitorRunning: audioMonitorRunning,
            internetAvailable: internetAvailable,
            internetRequiredForPreparedSet: true,
            onlineServicesAvailable: internetAvailable,
            connectedToPower: connectedToPower,
            batteryLevel: batteryLevel,
            emergencyAudioReady: emergencyAudioReady,
            emergencyDuration: emergencyDuration,
            projectPrepared: projectPrepared,
            projectLocked: projectLocked,
            trackCount: trackCount,
            transitionCount: transitionCount,
            lowConfidenceTransitionCount: lowConfidenceTransitionCount
        )
    }

    private static func legacyCapabilities(
        identifier: DJBackendIdentifier,
        midiAvailable: Bool,
        mappingCompletion: Double
    ) -> DJBackendCapabilities {
        var result = DJBackendCapabilities()
        let ready = DJCapabilityStatus(
            availability: .available,
            confidence: .validated,
            validation: .automatedSuccess,
            method: .guidedManualStep
        )
        result[.processDetection] = ready
        result[.versionDetection] = ready
        result[.masterAudioMonitoring] = ready
        result[.remoteControl] = ready
        result[.recovery] = ready

        if identifier == .djay {
            result[.automix] = DJCapabilityStatus(
                availability: .available,
                confidence: .validated,
                validation: .automatedSuccess,
                method: .nativeAutomix
            )
            result[.trackStateReading] = ready
            result[.transitionTrigger] = ready
        } else {
            let directStatus = DJCapabilityStatus(
                availability: midiAvailable ? .available : .unavailable,
                confidence: mappingCompletion >= 0.95 ? .validated : .unverified,
                validation: midiAvailable && mappingCompletion >= 0.95 ? .automatedSuccess : .failed,
                method: midiAvailable ? .coreMIDI : .unavailable
            )
            for capability in [DJCapability.trackLoading, .playPause, .channelVolume, .sync] {
                result[capability] = directStatus
            }
            result[.mappingImport] = DJCapabilityStatus(
                availability: mappingCompletion >= 0.95 ? .available : .unavailable,
                confidence: mappingCompletion >= 0.95 ? .validated : .unverified,
                validation: mappingCompletion >= 0.95 ? .automatedSuccess : .failed,
                method: mappingCompletion >= 0.95 ? .importedMapping : .unavailable
            )
        }
        return result
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
        appendBackendSelection(to: &items, input: input)

        guard let backend = input.backendIdentifier else {
            appendLocalSafety(to: &items, input: input)
            appendProject(to: &items, input: input)
            return PreflightReport(items: items)
        }

        let usesValidatedAutomix = isVerifiedForLive(input.backendCapabilities[.automix]) &&
            isVerifiedForLive(input.backendCapabilities[.trackStateReading])
        let directCapabilities: [DJCapability] = [.trackLoading, .playPause, .channelVolume]
        let usesDirectControl = !usesValidatedAutomix

        items.append(environmentItem(input.backendEnvironment, backend: backend))
        appendBackendValidation(to: &items, input: input)

        let accessibilityRequired = usesAccessibility(input.backendCapabilities) &&
            (usesValidatedAutomix || input.backendCapabilities.supports(.trackStateReading))
        items.append(requirementItem(
            id: "accessibility",
            title: "Lecture de l’état du logiciel",
            available: input.accessibilityGranted,
            required: accessibilityRequired,
            success: "MixPilot peut observer l’état utile de \(backend.displayName).",
            optional: "Cette configuration peut fonctionner sans lire toute l’interface. Les confirmations seront plus limitées.",
            failure: "Autorise MixPilot dans Réglages Système → Confidentialité et sécurité → Accessibilité. Sans cette lecture, les commandes critiques ne peuvent pas être confirmées."
        ))

        let midiRequired = usesDirectControl && directCapabilities.contains {
            input.backendCapabilities[$0].method == .coreMIDI ||
                input.backendCapabilities[$0].availability != .unavailable
        }
        items.append(requirementItem(
            id: "midi",
            title: "Connexion au logiciel DJ",
            available: input.midiAvailable,
            required: midiRequired,
            success: "Le contrôleur virtuel MixPilot est disponible.",
            optional: "Le mode supervisé sélectionné ne dépend pas du contrôleur MIDI.",
            failure: "Le contrôleur virtuel n’est pas disponible. Relance MixPilot, puis vérifie les réglages MIDI de \(backend.displayName)."
        ))

        let mappingStatus = input.backendCapabilities[.mappingImport]
        let mappingRequired = usesDirectControl && mappingStatus.availability != .unavailable
        let mappingReady = input.mappingCompletion >= 0.95 &&
            mappingStatus.availability != .unavailable &&
            mappingStatus.validation != .failed &&
            mappingStatus.validation != .blockedByPlatform
        items.append(requirementItem(
            id: "mapping",
            title: "Commandes configurées",
            available: mappingReady,
            required: mappingRequired,
            success: "Les commandes nécessaires sont présentes. Leur réaction réelle reste suivie séparément.",
            optional: usesValidatedAutomix
                ? "Le mode Automix supervisé peut fonctionner sans mapping direct complet."
                : "Aucun mapping direct n’est utilisé dans cette configuration.",
            failure: "Seulement \(Int(input.mappingCompletion * 100)) % du mapping est prêt. Termine la configuration et teste les commandes critiques."
        ))

        if usesValidatedAutomix {
            items.append(capabilityItem(
                id: "automix",
                title: "Automix supervisé",
                capability: .automix,
                status: input.backendCapabilities[.automix],
                critical: true
            ))
        } else {
            for capability in directCapabilities {
                items.append(capabilityItem(
                    id: "capability-\(capability.rawValue)",
                    title: capabilityTitle(capability),
                    capability: capability,
                    status: input.backendCapabilities[capability],
                    critical: true
                ))
            }
            items.append(capabilityItem(
                id: "capability-sync",
                title: "Synchronisation",
                capability: .sync,
                status: input.backendCapabilities[.sync],
                critical: false
            ))
        }

        appendLocalSafety(to: &items, input: input)
        appendProject(to: &items, input: input)
        appendTransitionReadiness(to: &items, input: input)
        return PreflightReport(items: deduplicated(items))
    }

    private func appendBackendSelection(
        to items: inout [PreflightItem],
        input: PreflightInput
    ) {
        guard let backend = input.backendIdentifier else {
            items.append(PreflightItem(
                id: "dj-backend",
                title: "Logiciel DJ",
                detail: "Choisis djay Pro, rekordbox ou Serato DJ Pro. MixPilot ne choisit pas automatiquement à ta place.",
                status: .failed,
                severity: .critical
            ))
            return
        }
        items.append(PreflightItem(
            id: "dj-backend",
            title: backend.displayName,
            detail: "Ce logiciel sera utilisé pour le prochain Live.",
            status: .passed,
            severity: .information
        ))
        // Legacy identifier kept until older views and tests are migrated.
        items.append(PreflightItem(
            id: "dj-software",
            title: backend.displayName,
            detail: "Backend DJ sélectionné.",
            status: .passed,
            severity: .information
        ))
    }

    private func environmentItem(
        _ environment: DJBackendEnvironment?,
        backend: DJBackendIdentifier
    ) -> PreflightItem {
        guard let environment else {
            return PreflightItem(
                id: "backend-environment",
                title: "Connexion à \(backend.displayName)",
                detail: "L’environnement n’a pas encore été vérifié. Relance le test de connexion.",
                status: .notTested,
                severity: .critical
            )
        }
        if !environment.isInstalled {
            return PreflightItem(
                id: "backend-environment",
                title: "\(backend.displayName) non installé",
                detail: "Installe le logiciel depuis sa source officielle, puis relance la vérification.",
                status: .failed,
                severity: .critical
            )
        }
        if !environment.isRunning {
            return PreflightItem(
                id: "backend-environment",
                title: "\(backend.displayName) est fermé",
                detail: "Lance le logiciel et ouvre la playlist voulue avant le Live.",
                status: .failed,
                severity: .critical
            )
        }
        return PreflightItem(
            id: "backend-environment",
            title: "\(backend.displayName) connecté",
            detail: environment.softwareVersion.map { "Version \($0) détectée." } ?? "Le logiciel est lancé ; sa version reste à confirmer.",
            status: environment.softwareVersion == nil ? .warning : .passed,
            severity: environment.softwareVersion == nil ? .warning : .information
        )
    }

    private func appendBackendValidation(
        to items: inout [PreflightItem],
        input: PreflightInput
    ) {
        guard let validation = input.backendValidation else { return }
        for item in validation.items where item.id != "installed" && item.id != "running" {
            let convertedStatus: PreflightItemStatus
            let severity: PreflightSeverity
            switch item.status {
            case .automatedSuccess:
                convertedStatus = .passed
                severity = .information
            case .simulatedSuccess, .requiresBackendValidation, .requiresDeviceValidation, .unknown:
                convertedStatus = .warning
                severity = .warning
            case .blockedByPlatform, .failed:
                convertedStatus = .failed
                severity = item.capability.map(isCriticalCapability) == true ? .critical : .warning
            }
            items.append(PreflightItem(
                id: "backend-validation-\(item.id)",
                title: item.title,
                detail: humanValidationDetail(item),
                status: convertedStatus,
                severity: severity
            ))
        }
    }

    private func appendLocalSafety(
        to items: inout [PreflightItem],
        input: PreflightInput
    ) {
        items.append(requirementItem(
            id: "audio",
            title: "Surveillance audio",
            available: input.audioMonitorRunning,
            required: true,
            success: "MixPilot surveille le silence, la perte de source et la saturation.",
            optional: "",
            failure: "Démarre la surveillance audio. Sans elle, MixPilot ne peut pas détecter un silence inattendu ni déclencher le secours local."
        ))

        if input.internetRequiredForPreparedSet {
            items.append(requirementItem(
                id: "internet",
                title: "Connexion Internet",
                available: input.internetAvailable,
                required: true,
                success: "La connexion nécessaire aux morceaux en ligne est disponible.",
                optional: "",
                failure: "Certains morceaux du set dépendent d’Internet. Remplace-les par des fichiers locaux ou rétablis la connexion avant le Live."
            ))
        } else {
            items.append(PreflightItem(
                id: "internet",
                title: "Connexion Internet",
                detail: input.internetAvailable
                    ? "Internet est disponible. Le Live préparé reste toutefois local."
                    : "Internet est indisponible. Les diagnostics et mises à jour sont suspendus, mais le Live local peut continuer.",
                status: input.internetAvailable ? .passed : .warning,
                severity: input.internetAvailable ? .information : .warning
            ))
        }

        items.append(PreflightItem(
            id: "online-services",
            title: "Services en ligne",
            detail: input.onlineServicesAvailable
                ? "Les diagnostics en ligne et les mises à jour sont disponibles."
                : "Les services en ligne sont temporairement indisponibles. Cela ne coupe pas le Live local.",
            status: input.onlineServicesAvailable ? .passed : .warning,
            severity: input.onlineServicesAvailable ? .information : .warning
        ))

        items.append(PreflightItem(
            id: "power",
            title: "Alimentation",
            detail: input.connectedToPower
                ? "Le Mac est branché au secteur."
                : "Le Mac fonctionne sur batterie (\(Int((input.batteryLevel ?? 0) * 100)) %). Branche-le avant un long set.",
            status: input.connectedToPower ? .passed : .warning,
            severity: input.connectedToPower ? .information : .warning
        ))

        let emergencyOK = input.emergencyAudioReady && input.emergencyDuration >= 1_800
        items.append(PreflightItem(
            id: "emergency",
            title: "Musique de secours",
            detail: emergencyOK
                ? "Au moins 30 minutes de musique locale sont disponibles."
                : "Aucune réserve locale de 30 minutes n’est prête. Le Live reste possible, mais une perte de source ne pourra pas être couverte automatiquement.",
            status: emergencyOK ? .passed : .warning,
            severity: emergencyOK ? .information : .warning
        ))
    }

    private func appendProject(
        to items: inout [PreflightItem],
        input: PreflightInput
    ) {
        let projectOK = input.projectPrepared && input.projectLocked && input.trackCount >= 2 &&
            input.transitionCount == input.trackCount - 1
        items.append(PreflightItem(
            id: "project",
            title: "Plan du set",
            detail: projectOK
                ? "\(input.trackCount) morceaux et \(input.transitionCount) transitions sont verrouillés."
                : "Prépare au moins deux morceaux, vérifie toutes les transitions puis verrouille le plan.",
            status: projectOK ? .passed : .failed,
            severity: .critical
        ))

        items.append(PreflightItem(
            id: "confidence",
            title: "Transitions à revoir",
            detail: input.lowConfidenceTransitionCount == 0
                ? "Aucune transition n’est sous le seuil de confiance."
                : "\(input.lowConfidenceTransitionCount) transition(s) méritent une répétition avant le Live.",
            status: input.lowConfidenceTransitionCount == 0 ? .passed : .warning,
            severity: .warning
        ))
    }

    private func appendTransitionReadiness(
        to items: inout [PreflightItem],
        input: PreflightInput
    ) {
        if input.blockedTransitionCount > 0 {
            items.append(PreflightItem(
                id: "transition-capabilities",
                title: "Transitions non exécutables",
                detail: "\(input.blockedTransitionCount) transition(s) demandent une commande indisponible et aucune variante sûre n’a été trouvée. Modifie le plan avant le Live.",
                status: .failed,
                severity: .critical
            ))
        } else if input.fallbackTransitionCount > 0 {
            items.append(PreflightItem(
                id: "transition-capabilities",
                title: "Transitions adaptées",
                detail: "\(input.fallbackTransitionCount) transition(s) utiliseront une variante sûre compatible avec le backend actif.",
                status: .warning,
                severity: .warning
            ))
        } else {
            items.append(PreflightItem(
                id: "transition-capabilities",
                title: "Transitions compatibles",
                detail: "Toutes les transitions du plan disposent des commandes nécessaires.",
                status: .passed,
                severity: .information
            ))
        }
    }

    private func capabilityItem(
        id: String,
        title: String,
        capability: DJCapability,
        status: DJCapabilityStatus,
        critical: Bool
    ) -> PreflightItem {
        let verified = isVerifiedForLive(status)
        if verified {
            return PreflightItem(
                id: id,
                title: title,
                detail: status.reason ?? "Cette fonction est prête.",
                status: .passed,
                severity: critical ? .critical : .information
            )
        }

        let unavailable = status.availability == .unavailable ||
            status.validation == .blockedByPlatform || status.validation == .failed
        let detail = status.reason ?? defaultCapabilityProblem(capability)
        return PreflightItem(
            id: id,
            title: title,
            detail: critical
                ? "\(detail) Impact : l’Autopilote complet ne peut pas utiliser cette fonction. Termine le test ou choisis une configuration compatible."
                : "\(detail) MixPilot utilisera une variante compatible lorsque c’est possible.",
            status: critical || unavailable ? .failed : .warning,
            severity: critical ? .critical : .warning
        )
    }

    private func requirementItem(
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

    private func isVerifiedForLive(_ status: DJCapabilityStatus) -> Bool {
        guard status.availability == .available else { return false }
        switch status.validation {
        case .automatedSuccess:
            return status.confidence == .validated || status.confidence == .documented
        case .simulatedSuccess, .requiresBackendValidation, .requiresDeviceValidation,
             .blockedByPlatform, .failed, .unknown:
            return false
        }
    }

    private func usesAccessibility(_ capabilities: DJBackendCapabilities) -> Bool {
        [DJCapability.visiblePlaylistReading, .deckStateReading, .trackStateReading, .automix]
            .contains { capabilities[$0].method == .accessibility }
    }

    private func isCriticalCapability(_ capability: DJCapability) -> Bool {
        [.trackLoading, .playPause, .channelVolume, .automix, .trackStateReading]
            .contains(capability)
    }

    private func capabilityTitle(_ capability: DJCapability) -> String {
        switch capability {
        case .trackLoading: "Chargement des morceaux"
        case .playPause: "Lecture et pause"
        case .channelVolume: "Volumes des decks"
        case .sync: "Synchronisation du tempo"
        case .automix: "Automix supervisé"
        default: capability.rawValue
        }
    }

    private func defaultCapabilityProblem(_ capability: DJCapability) -> String {
        switch capability {
        case .trackLoading: "MixPilot ne peut pas encore charger un morceau de façon fiable."
        case .playPause: "La lecture et la pause n’ont pas encore été confirmées."
        case .channelVolume: "Les volumes des decks ne sont pas encore contrôlables de façon fiable."
        case .sync: "La synchronisation n’est pas encore validée."
        case .automix: "Le mode Automix n’a pas encore été validé sur cette version."
        default: "Cette fonction n’est pas prête dans la configuration actuelle."
        }
    }

    private func humanValidationDetail(_ item: DJBackendValidationItem) -> String {
        switch item.status {
        case .automatedSuccess:
            return item.detail
        case .simulatedSuccess:
            return "\(item.detail) Ce résultat vient d’une simulation et doit encore être confirmé sur le Mac cible."
        case .requiresBackendValidation:
            return "\(item.detail) Teste cette fonction une fois avec le logiciel DJ ouvert."
        case .requiresDeviceValidation:
            return "\(item.detail) Confirme la réaction réelle du logiciel et du contrôleur avant le Live."
        case .blockedByPlatform:
            return "\(item.detail) MixPilot utilisera une autre méthode lorsqu’une variante sûre existe."
        case .failed:
            return item.detail
        case .unknown:
            return "\(item.detail) Relance la vérification pour obtenir un état fiable."
        }
    }

    private func deduplicated(_ items: [PreflightItem]) -> [PreflightItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
