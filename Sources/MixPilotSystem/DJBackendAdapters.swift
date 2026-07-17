#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotMIDI

public struct DJApplicationEnvironmentDetector: Sendable {
    public init() {}

    @MainActor
    public func detect(_ identifier: DJBackendIdentifier) -> DJBackendEnvironment {
        let runningApplication = NSWorkspace.shared.runningApplications.first {
            matches($0, identifier: identifier)
        }
        let bundleURL = runningApplication?.bundleURL ?? installedApplicationURL(identifier)
        let bundle = bundleURL.flatMap(Bundle.init(url:))
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        return DJBackendEnvironment(
            identifier: identifier,
            isInstalled: bundleURL != nil,
            isRunning: runningApplication != nil,
            softwareVersion: version,
            bundleIdentifier: runningApplication?.bundleIdentifier ?? bundle?.bundleIdentifier,
            processIdentifier: runningApplication?.processIdentifier
        )
    }

    @MainActor
    private func matches(_ application: NSRunningApplication, identifier: DJBackendIdentifier) -> Bool {
        let name = application.localizedName?.lowercased() ?? ""
        let bundle = application.bundleIdentifier?.lowercased() ?? ""
        switch identifier {
        case .serato:
            return name.contains("serato dj pro") || name == "serato dj" || bundle.contains("serato")
        case .djay:
            return DjayApplicationMatcher.matches(name: application.localizedName) || bundle.contains("algoriddim.djay")
        case .rekordbox:
            return RekordboxApplicationMatcher.matches(
                name: application.localizedName,
                bundleIdentifier: application.bundleIdentifier
            )
        }
    }

    @MainActor
    private func installedApplicationURL(_ identifier: DJBackendIdentifier) -> URL? {
        let names: [String]
        switch identifier {
        case .serato: names = ["Serato DJ Pro.app", "Serato DJ.app"]
        case .djay: names = ["djay Pro.app", "djay Pro AI.app", "djay.app"]
        case .rekordbox: names = ["rekordbox.app"]
        }

        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]
        for root in roots {
            for name in names {
                let candidate = root.appendingPathComponent(name, isDirectory: true)
                if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            }
        }
        return nil
    }
}

private actor StandardDJBackendAdapter {
    nonisolated let identifier: DJBackendIdentifier
    nonisolated let displayName: String

    private let midi: MappedMIDIController
    private let validationStore: any DJCommandValidationStoring
    private let environmentDetector: DJApplicationEnvironmentDetector

    init(
        identifier: DJBackendIdentifier,
        midi: MappedMIDIController,
        validationStore: any DJCommandValidationStoring,
        environmentDetector: DJApplicationEnvironmentDetector
    ) {
        self.identifier = identifier
        self.displayName = identifier.displayName
        self.midi = midi
        self.validationStore = validationStore
        self.environmentDetector = environmentDetector
    }

    func detectEnvironment() async -> DJBackendEnvironment {
        await environmentDetector.detect(identifier)
    }

    func capabilities() async -> DJBackendCapabilities {
        let environment = await detectEnvironment()
        let profile = await midi.currentProfile()
        let records = await validationStore.validations(for: identifier)
        let currentMapping = profile.validationIdentifier
        let currentRecords = records.filter {
            $0.key.softwareVersion == environment.softwareVersion &&
                $0.key.controllerName == "MixPilot Virtual Controller" &&
                $0.key.mappingVersion == currentMapping
        }
        let validatedActions = Set(currentRecords.filter(\.permitsLiveControl).map { $0.key.action })

        var result = DJBackendCapabilities()
        result[.processDetection] = status(
            .available, .documented, .automatedSuccess, .visibleInterfaceObservation,
            environment: environment
        )
        result[.versionDetection] = status(
            environment.softwareVersion == nil ? .partiallyAvailable : .available,
            environment.softwareVersion == nil ? .unverified : .documented,
            environment.softwareVersion == nil ? .requiresBackendValidation : .automatedSuccess,
            .visibleInterfaceObservation,
            environment: environment,
            reason: environment.softwareVersion == nil ? "La version du logiciel n’a pas encore été détectée." : nil
        )

        configureLibraryCapabilities(&result, environment: environment)
        configureMappingCapabilities(&result, environment: environment)
        configureStateCapabilities(&result, environment: environment)

        for capability in commandCapabilities {
            let actions = DJControlAction.allCases.filter { $0.requiredCapability == capability }
            let mapped = actions.filter { profile[$0] != nil }
            let validated = actions.filter { validatedActions.contains($0) }
            let fullyMapped = !actions.isEmpty && mapped.count == actions.count
            let fullyValidated = !actions.isEmpty && validated.count == actions.count

            result[capability] = DJCapabilityStatus(
                availability: fullyMapped ? .available : mapped.isEmpty ? .unavailable : .partiallyAvailable,
                confidence: fullyValidated ? .validated : fullyMapped ? .observed : .unverified,
                validation: fullyValidated ? .automatedSuccess : fullyMapped ? .requiresDeviceValidation : .failed,
                method: fullyMapped ? .coreMIDI : .unavailable,
                lastValidatedAt: currentRecords.filter { actions.contains($0.key.action) }.map(\.validatedAt).max(),
                testedSoftwareVersion: environment.softwareVersion,
                mappingVersion: currentMapping,
                controllerName: "MixPilot Virtual Controller",
                reason: fullyMapped
                    ? fullyValidated ? nil : "Le mapping existe, mais la réaction réelle doit encore être confirmée."
                    : "Le mapping ne contient pas toutes les commandes nécessaires.",
                userAction: fullyValidated ? nil : DJUserAction(
                    title: "Tester les commandes",
                    instructions: "Ouvre une playlist de test et confirme chaque réaction avant le Live."
                )
            )
        }

        result[.masterAudioMonitoring] = status(
            .available, .validated, .automatedSuccess, .localAudioMonitoring,
            environment: environment,
            reason: "La surveillance audio appartient à MixPilot et reste indépendante du backend."
        )
        result[.remoteControl] = status(
            .available, .documented, .automatedSuccess, .guidedManualStep,
            environment: environment
        )
        result[.recovery] = status(
            .available, .documented, .automatedSuccess, .guidedManualStep,
            environment: environment
        )
        return result
    }

    func validateConfiguration() async -> DJBackendValidationReport {
        let environment = await detectEnvironment()
        let capabilities = await capabilities()
        var items: [DJBackendValidationItem] = [
            DJBackendValidationItem(
                id: "installed",
                title: "Logiciel installé",
                detail: environment.isInstalled
                    ? "\(displayName) est installé sur ce Mac."
                    : "Installe \(displayName) avant de continuer.",
                status: environment.isInstalled ? .automatedSuccess : .failed,
                userAction: environment.isInstalled ? nil : DJUserAction(
                    title: "Installer le logiciel",
                    instructions: "Installe le logiciel depuis sa source officielle, puis relance la vérification."
                )
            ),
            DJBackendValidationItem(
                id: "running",
                title: "Logiciel lancé",
                detail: environment.isRunning
                    ? "\(displayName) est ouvert."
                    : "Lance \(displayName) pour terminer le test de connexion.",
                status: environment.isRunning ? .automatedSuccess : .failed,
                capability: .processDetection
            ),
        ]

        for capability in criticalCapabilities {
            let value = capabilities[capability]
            items.append(DJBackendValidationItem(
                id: capability.rawValue,
                title: humanTitle(capability),
                detail: value.reason ?? "Cette fonction est prête.",
                status: value.validation,
                capability: capability,
                userAction: value.userAction
            ))
        }
        return DJBackendValidationReport(backend: identifier, items: items)
    }

    func readState() async throws -> DJBackendState {
        let observation = await observation()
        guard observation.isRunning else { throw DJBackendError.disconnected(identifier) }
        guard observation.accessibilityGranted else {
            throw DJBackendError.stateUnavailable(
                "MixPilot ne peut pas encore lire l’état de \(displayName). Autorise l’accès, puis relance le test."
            )
        }
        return DJBackendState(observedAt: observation.observedAt, isReliable: false)
    }

    func readDeckState(_ deck: DeckID) async throws -> DJDeckState {
        let observation = await observation()
        guard observation.isRunning else { throw DJBackendError.disconnected(identifier) }
        throw DJBackendError.stateUnavailable(
            "L’état détaillé du deck \(deck.rawValue) n’a pas encore été validé avec cette version de \(displayName)."
        )
    }

    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        let environment = await detectEnvironment()
        guard environment.isRunning else { throw DJBackendError.disconnected(identifier) }
        let profile = await midi.currentProfile()
        guard profile[command.action] != nil else {
            throw DJBackendError.capabilityUnavailable(
                command.action.requiredCapability,
                reason: "Cette commande n’est pas présente dans le mapping actif."
            )
        }
        let key = validationKey(command.action, environment: environment, profile: profile)
        guard await validationStore.validation(for: key)?.permitsLiveControl == true else {
            throw DJBackendError.commandRejected(
                "Cette commande n’a pas encore été confirmée avec \(displayName) et ce mapping précis. Teste-la avant le Live."
            )
        }

        if let value = command.normalizedValue {
            try await midi.set(command.action, value: value)
        } else {
            try await midi.trigger(command.action)
        }
        return DJCommandReceipt(
            commandID: command.id,
            status: .sent,
            detail: "Commande envoyée ; l’effet reste vérifié séparément."
        )
    }

    func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification {
        let observation = await observation()
        guard observation.isRunning else { throw DJBackendError.disconnected(identifier) }

        if case .loadedTrack(let track, _) = expectedEffect {
            let titleFound = track.title.map(observation.contains(text:)) ?? false
            let artistFound = track.artist.map(observation.contains(text:)) ?? true
            if titleFound && artistFound {
                return DJCommandVerification(
                    status: .verified,
                    confidence: .observed,
                    detail: "Le morceau attendu est visible dans \(displayName)."
                )
            }
        }

        return DJCommandVerification(
            status: .unknown,
            confidence: .unverified,
            detail: "La commande a été envoyée, mais son effet ne peut pas encore être confirmé de façon fiable."
        )
    }

    func takeManualControl() async {
        // The runtime stops future commands. No MIDI message is sent because
        // taking manual control must never change the current mix.
    }

    private func observation() async -> DJWindowObservation {
        let backend = identifier
        return await MainActor.run {
            DJAccessibilityBridge().observe(
                backend: backend,
                maxDepth: 6,
                maximumStrings: 400
            )
        }
    }

    private func configureLibraryCapabilities(
        _ result: inout DJBackendCapabilities,
        environment: DJBackendEnvironment
    ) {
        switch identifier {
        case .serato:
            result[.libraryReading] = observedPartial(
                "MixPilot lit actuellement les lignes visibles de la bibliothèque Serato.", environment
            )
            result[.visiblePlaylistReading] = observedPartial(
                "La disposition des colonnes doit être confirmée sur le Mac cible.", environment
            )
        case .djay:
            result[.libraryReading] = observedPartial(
                "La lecture repose sur la file Automix et les contrôles visibles exposés par djay.", environment
            )
            result[.visiblePlaylistReading] = observedPartial(
                "La file Automix doit être validée avec la version installée.", environment
            )
            result[.automix] = status(
                .partiallyAvailable, .observed, .requiresBackendValidation, .nativeAutomix,
                environment: environment,
                reason: "Automix est disponible dans djay, mais son pilotage doit encore être validé sur cette version.",
                action: DJUserAction(
                    title: "Tester Automix",
                    instructions: "Ouvre une file de test dans djay et termine le parcours de validation."
                )
            )
        case .rekordbox:
            result[.libraryReading] = status(
                .available, .validated, .automatedSuccess, .documentedLibraryImport,
                environment: environment,
                reason: "Les imports XML et JSON sont vérifiés automatiquement avant utilisation."
            )
            result[.visiblePlaylistReading] = observedPartial(
                "La lecture visible reste dépendante de la disposition de rekordbox.", environment
            )
        }
    }

    private func configureMappingCapabilities(
        _ result: inout DJBackendCapabilities,
        environment: DJBackendEnvironment
    ) {
        switch identifier {
        case .serato:
            result[.mappingImport] = validatedMapping(environment)
            result[.mappingAutoInstall] = validatedMapping(environment)
            result[.mappingRollback] = validatedMapping(environment)
        case .rekordbox:
            result[.mappingImport] = validatedMapping(environment)
            result[.mappingAutoInstall] = status(
                .partiallyAvailable, .validated, .requiresBackendValidation, .guidedManualStep,
                environment: environment,
                reason: "MixPilot prépare et vérifie le CSV. L’import reste confirmé dans la fenêtre MIDI officielle de rekordbox."
            )
            result[.mappingRollback] = validatedMapping(environment)
        case .djay:
            result[.mappingImport] = status(
                .partiallyAvailable, .unverified, .requiresBackendValidation, .guidedManualStep,
                environment: environment,
                reason: "Le profil MIDI djay doit encore être importé et validé sur le Mac cible."
            )
            result[.mappingAutoInstall] = status(
                .unavailable, .unverified, .blockedByPlatform, .unavailable,
                environment: environment,
                reason: "L’installation automatique n’est pas revendiquée pour djay."
            )
            result[.mappingRollback] = status(
                .partiallyAvailable, .unverified, .requiresBackendValidation, .guidedManualStep,
                environment: environment,
                reason: "La restauration du profil djay doit encore être validée."
            )
        }
    }

    private func configureStateCapabilities(
        _ result: inout DJBackendCapabilities,
        environment: DJBackendEnvironment
    ) {
        for capability in [DJCapability.deckStateReading, .trackStateReading] {
            result[capability] = observedPartial(
                "L’interface visible peut être observée, mais l’état complet des decks n’est pas encore garanti.",
                environment
            )
        }
        result[.waveformReading] = status(
            .unavailable, .unverified, .blockedByPlatform, .unavailable,
            environment: environment,
            reason: "MixPilot ne lit pas les formes d’onde internes du logiciel DJ."
        )
        if identifier != .djay {
            result[.automix] = status(
                .unavailable, .documented, .blockedByPlatform, .unavailable,
                environment: environment,
                reason: "Ce backend utilise le moteur de transitions MixPilot."
            )
        }
        result[.transitionTrigger] = status(
            .available, .observed, .requiresDeviceValidation, .coreMIDI,
            environment: environment,
            reason: "Le déclenchement dépend des commandes critiques réellement confirmées."
        )
    }

    private func status(
        _ availability: DJCapabilityAvailability,
        _ confidence: DJCapabilityConfidence,
        _ validation: DJValidationStatus,
        _ method: DJIntegrationMethod,
        environment: DJBackendEnvironment,
        reason: String? = nil,
        action: DJUserAction? = nil
    ) -> DJCapabilityStatus {
        DJCapabilityStatus(
            availability: availability,
            confidence: confidence,
            validation: validation,
            method: method,
            testedSoftwareVersion: environment.softwareVersion,
            reason: reason,
            userAction: action
        )
    }

    private func observedPartial(
        _ reason: String,
        _ environment: DJBackendEnvironment
    ) -> DJCapabilityStatus {
        status(
            .partiallyAvailable, .observed, .requiresDeviceValidation, .accessibility,
            environment: environment,
            reason: reason
        )
    }

    private func validatedMapping(_ environment: DJBackendEnvironment) -> DJCapabilityStatus {
        status(
            .available, .validated, .automatedSuccess, .importedMapping,
            environment: environment,
            reason: "Le fichier de mapping est géré et vérifié localement ; les réactions des commandes restent validées séparément."
        )
    }

    private func validationKey(
        _ action: DJControlAction,
        environment: DJBackendEnvironment,
        profile: MIDIMappingProfile
    ) -> DJCommandValidationKey {
        DJCommandValidationKey(
            backend: identifier,
            softwareVersion: environment.softwareVersion,
            controllerName: "MixPilot Virtual Controller",
            mappingVersion: profile.validationIdentifier,
            action: action
        )
    }

    private var commandCapabilities: [DJCapability] {
        [.trackLoading, .playPause, .cue, .sync, .tempo, .channelVolume,
         .eqLow, .eqMid, .eqHigh, .filter, .crossfader, .loop, .effects]
    }

    private var criticalCapabilities: [DJCapability] {
        [.trackLoading, .playPause, .channelVolume, .sync, .mappingImport, .deckStateReading]
    }

    private func humanTitle(_ capability: DJCapability) -> String {
        switch capability {
        case .trackLoading: "Chargement des morceaux"
        case .playPause: "Lecture et pause"
        case .channelVolume: "Volumes des decks"
        case .sync: "Synchronisation"
        case .mappingImport: "Mapping"
        case .deckStateReading: "Lecture de l’état des decks"
        default: capability.rawValue
        }
    }
}

public struct SeratoBackend: DJBackend {
    public let identifier: DJBackendIdentifier = .serato
    public let displayName = "Serato DJ Pro"
    private let adapter: StandardDJBackendAdapter

    public init(
        midi: MappedMIDIController,
        validationStore: any DJCommandValidationStoring = UserDefaultsDJCommandValidationStore(),
        environmentDetector: DJApplicationEnvironmentDetector = DJApplicationEnvironmentDetector()
    ) {
        adapter = StandardDJBackendAdapter(
            identifier: .serato,
            midi: midi,
            validationStore: validationStore,
            environmentDetector: environmentDetector
        )
    }

    public func detectEnvironment() async -> DJBackendEnvironment { await adapter.detectEnvironment() }
    public func capabilities() async -> DJBackendCapabilities { await adapter.capabilities() }
    public func validateConfiguration() async -> DJBackendValidationReport { await adapter.validateConfiguration() }
    public func readState() async throws -> DJBackendState { try await adapter.readState() }
    public func readDeckState(_ deck: DeckID) async throws -> DJDeckState { try await adapter.readDeckState(deck) }
    public func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt { try await adapter.execute(command) }
    public func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification {
        try await adapter.verify(command: command, expectedEffect: expectedEffect)
    }
    public func takeManualControl() async { await adapter.takeManualControl() }
}

public struct RekordboxBackend: DJBackend {
    public let identifier: DJBackendIdentifier = .rekordbox
    public let displayName = "rekordbox"
    private let adapter: StandardDJBackendAdapter

    public init(
        midi: MappedMIDIController,
        validationStore: any DJCommandValidationStoring = UserDefaultsDJCommandValidationStore(),
        environmentDetector: DJApplicationEnvironmentDetector = DJApplicationEnvironmentDetector()
    ) {
        adapter = StandardDJBackendAdapter(
            identifier: .rekordbox,
            midi: midi,
            validationStore: validationStore,
            environmentDetector: environmentDetector
        )
    }

    public func detectEnvironment() async -> DJBackendEnvironment { await adapter.detectEnvironment() }
    public func capabilities() async -> DJBackendCapabilities { await adapter.capabilities() }
    public func validateConfiguration() async -> DJBackendValidationReport { await adapter.validateConfiguration() }
    public func readState() async throws -> DJBackendState { try await adapter.readState() }
    public func readDeckState(_ deck: DeckID) async throws -> DJDeckState { try await adapter.readDeckState(deck) }
    public func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt { try await adapter.execute(command) }
    public func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification {
        try await adapter.verify(command: command, expectedEffect: expectedEffect)
    }
    public func takeManualControl() async { await adapter.takeManualControl() }
}

public struct DjayBackend: DJBackend {
    public let identifier: DJBackendIdentifier = .djay
    public let displayName = "djay Pro"
    private let adapter: StandardDJBackendAdapter

    public init(
        midi: MappedMIDIController,
        validationStore: any DJCommandValidationStoring = UserDefaultsDJCommandValidationStore(),
        environmentDetector: DJApplicationEnvironmentDetector = DJApplicationEnvironmentDetector()
    ) {
        adapter = StandardDJBackendAdapter(
            identifier: .djay,
            midi: midi,
            validationStore: validationStore,
            environmentDetector: environmentDetector
        )
    }

    public func detectEnvironment() async -> DJBackendEnvironment { await adapter.detectEnvironment() }
    public func capabilities() async -> DJBackendCapabilities { await adapter.capabilities() }
    public func validateConfiguration() async -> DJBackendValidationReport { await adapter.validateConfiguration() }
    public func readState() async throws -> DJBackendState { try await adapter.readState() }
    public func readDeckState(_ deck: DeckID) async throws -> DJDeckState { try await adapter.readDeckState(deck) }
    public func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt { try await adapter.execute(command) }
    public func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification {
        try await adapter.verify(command: command, expectedEffect: expectedEffect)
    }
    public func takeManualControl() async { await adapter.takeManualControl() }
}
#endif
