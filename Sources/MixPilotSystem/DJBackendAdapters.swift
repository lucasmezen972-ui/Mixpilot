#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotMIDI

@MainActor
public final class DJApplicationEnvironmentDetector {
    public init() {}

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
            bundleIdentifier: runningApplication?.bundleIdentifier
                ?? bundle?.bundleIdentifier,
            processIdentifier: runningApplication?.processIdentifier
        )
    }

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

    private func installedApplicationURL(_ identifier: DJBackendIdentifier) -> URL? {
        let names: [String]
        switch identifier {
        case .serato:
            names = ["Serato DJ Pro.app", "Serato DJ.app"]
        case .djay:
            names = ["djay Pro.app", "djay Pro AI.app", "djay.app"]
        case .rekordbox:
            names = ["rekordbox.app"]
        }

        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
        for root in roots {
            for name in names {
                let candidate = root.appendingPathComponent(name, isDirectory: true)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
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
        await MainActor.run { environmentDetector.detect(identifier) }
    }

    func capabilities() async -> DJBackendCapabilities {
        let environment = await detectEnvironment()
        let profile = await midi.currentProfile()
        let records = await validationStore.validations(for: identifier)
        let validatedActions = Set(
            records.filter(\.permitsLiveControl).map { $0.key.action }
        )

        var result = DJBackendCapabilities()
        result[.processDetection] = available(
            method: .visibleInterfaceObservation,
            validation: .automatedSuccess,
            confidence: .documented,
            environment: environment
        )
        result[.versionDetection] = DJCapabilityStatus(
            availability: environment.softwareVersion == nil ? .partiallyAvailable : .available,
            confidence: environment.softwareVersion == nil ? .unverified : .documented,
            validation: environment.softwareVersion == nil ? .requiresBackendValidation : .automatedSuccess,
            method: .visibleInterfaceObservation,
            testedSoftwareVersion: environment.softwareVersion,
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
                lastValidatedAt: records
                    .filter { actions.contains($0.key.action) }
                    .map(\.validatedAt)
                    .max(),
                testedSoftwareVersion: environment.softwareVersion,
                mappingVersion: "profile-\(profile.schemaVersion)",
                controllerName: "MixPilot Virtual Controller",
                reason: fullyMapped
                    ? fullyValidated ? nil : "Les messages sont configurés, mais leur réaction réelle doit encore être confirmée."
                    : "Le mapping ne contient pas toutes les commandes nécessaires.",
                userAction: fullyValidated ? nil : DJUserAction(
                    title: "Tester les commandes",
                    instructions: "Ouvre une playlist de test et confirme chaque réaction avant le Live."
                )
            )
        }

        result[.masterAudioMonitoring] = DJCapabilityStatus(
            availability: .available,
            confidence: .validated,
            validation: .automatedSuccess,
            method: .localAudioMonitoring,
            reason: "La surveillance audio appartient à MixPilot et reste indépendante du backend."
        )
        result[.remoteControl] = DJCapabilityStatus(
            availability: .available,
            confidence: .documented,
            validation: .automatedSuccess,
            method: .guidedManualStep
        )
        result[.recovery] = DJCapabilityStatus(
            availability: .available,
            confidence: .documented,
            validation: .automatedSuccess,
            method: .guidedManualStep
        )
        return result
    }

    func validateConfiguration() async -> DJBackendValidationReport {
        let environment = await detectEnvironment()
        let capabilities = await capabilities()
        var items: [DJBackendValidationItem] = []

        items.append(DJBackendValidationItem(
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
        ))
        items.append(DJBackendValidationItem(
            id: "running",
            title: "Logiciel lancé",
            detail: environment.isRunning
                ? "\(displayName) est ouvert."
                : "Lance \(displayName) pour terminer le test de connexion.",
            status: environment.isRunning ? .automatedSuccess : .failed,
            capability: .processDetection
        ))

        for capability in criticalCapabilities {
            let status = capabilities[capability]
            items.append(DJBackendValidationItem(
                id: capability.rawValue,
                title: humanTitle(capability),
                detail: status.reason ?? "Cette fonction est prête.",
                status: status.validation,
                capability: capability,
                userAction: status.userAction
            ))
        }

        return DJBackendValidationReport(backend: identifier, items: items)
    }

    func readState() async throws -> DJBackendState {
        let observation = await observation()
        guard observation.isRunning else { throw DJBackendError.disconnected(identifier) }
        guard observation.accessibilityGranted else {
            throw DJBackendError.stateUnavailable(
                "MixPilot ne peut pas encore lire l’état de \(displayName). Autorise l’accès dans Réglages Système, puis relance le test."
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
                reason: "Cette commande n’est pas présente dans le mapping actif. Configure-la avant de continuer."
            )
        }

        let key = validationKey(command.action, environment: environment, profile: profile)
        guard await validationStore.validation(for: key)?.permitsLiveControl == true else {
            throw DJBackendError.commandRejected(
                "Cette commande n’a pas encore été confirmée avec \(displayName). Teste-la une fois avant le Live."
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
            detail: "Commande envoyée au contrôleur MIDI ; vérification encore nécessaire."
        )
    }

    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        let observation = await observation()
        guard observation.isRunning else { throw DJBackendError.disconnected(identifier) }

        switch expectedEffect {
        case .loadedTrack(let track, _):
            let titleFound = track.title.map(observation.contains(text:)) ?? false
            let artistFound = track.artist.map(observation.contains(text:)) ?? true
            if titleFound && artistFound {
                return DJCommandVerification(
                    status: .verified,
                    confidence: .observed,
                    detail: "Le morceau attendu est visible dans \(displayName)."
                )
            }
            return DJCommandVerification(
                status: .unknown,
                confidence: .unverified,
                detail: "Le morceau attendu n’a pas pu être confirmé dans l’interface."
            )
        case .playback, .normalizedValue, .stateChanged:
            return DJCommandVerification(
                status: .unknown,
                confidence: .unverified,
                detail: "La commande a été envoyée, mais cette version ne permet pas encore d’en confirmer l’effet de façon fiable."
            )
        }
    }

    func takeManualControl() async {
        // Stopping future automatic commands is handled by the runtime. No MIDI
        // command is sent here because manual control must never alter the mix.
    }

    private func observation() async -> SeratoWindowObservation {
        let software = legacySoftware
        return await MainActor.run {
            SeratoAccessibilityBridge().observe(software: software, maxDepth: 6, maximumStrings: 400)
        }
    }

    private func configureLibraryCapabilities(
        _ result: inout DJBackendCapabilities,
        environment: DJBackendEnvironment
    ) {
        switch identifier {
        case .serato:
            result[.libraryReading] = partialObservation(
                reason: "MixPilot lit actuellement les lignes visibles de la bibliothèque Serato.",
                environment: environment
            )
            result[.visiblePlaylistReading] = partialObservation(
                reason: "La disposition des colonnes doit être confirmée sur le Mac cible.",
                environment: environment
            )
        case .djay:
            result[.libraryReading] = partialObservation(
                reason: "La lecture repose sur la file Automix et les contrôles visibles réellement exposés par djay.",
                environment: environment
            )
            result[.visiblePlaylistReading] = partialObservation(
                reason: "La file Automix doit être validée avec la version installée.",
                environment: environment
            )
            result[.automix] = DJCapabilityStatus(
                availability: .partiallyAvailable,
                confidence: .observed,
                validation: .requiresBackendValidation,
                method: .nativeAutomix,
                testedSoftwareVersion: environment.softwareVersion,
                reason: "Automix est disponible dans djay, mais son pilotage par MixPilot doit encore être validé sur cette version.",
                userAction: DJUserAction(
                    title: "Tester Automix",
                    instructions: "Ouvre une file de test dans djay et termine le parcours de validation."
                )
            )
        case .rekordbox:
            result[.libraryReading] = DJCapabilityStatus(
                availability: .available,
                confidence: .validated,
                validation: .automatedSuccess,
                method: .documentedLibraryImport,
                testedSoftwareVersion: environment.softwareVersion,
                reason: "Les imports XML et JSON sont vérifiés automatiquement avant utilisation."
            )
            result[.visiblePlaylistReading] = partialObservation(
                reason: "La lecture visible reste dépendante de la disposition de rekordbox.",
                environment: environment
            )
        }
    }

    private func configureMappingCapabilities(
        _ result: inout DJBackendCapabilities,
        environment: DJBackendEnvironment
    ) {
        switch identifier {
        case .serato:
            result[.mappingImport] = available(method: .importedMapping, validation: .automatedSuccess, confidence: .validated, environment: environment)
            result[.mappingAutoInstall] = available(method: .importedMapping, validation: .automatedSuccess, confidence: .validated, environment: environment)
            result[.mappingRollback] = available(method: .importedMapping, validation: .automatedSuccess, confidence: .validated, environment: environment)
        case .rekordbox:
            result[.mappingImport] = available(method: .importedMapping, validation: .automatedSuccess, confidence: .validated, environment: environment)
            result[.mappingAutoInstall] = DJCapabilityStatus(
                availability: .partiallyAvailable,
                confidence: .validated,
                validation: .requiresBackendValidation,
                method: .guidedManualStep,
                testedSoftwareVersion: environment.softwareVersion,
                reason: "MixPilot prépare et vérifie le CSV. L’import reste confirmé dans la fenêtre MIDI officielle de rekordbox."
            )
            result[.mappingRollback] = available(method: .importedMapping, validation: .automatedSuccess, confidence: .validated, environment: environment)
        case .djay:
            result[.mappingImport] = DJCapabilityStatus(
                availability: .partiallyAvailable,
                confidence: .unverified,
                validation: .requiresBackendValidation,
                method: .guidedManualStep,
                testedSoftwareVersion: environment.softwareVersion,
                reason: "Le profil MIDI djay doit encore être importé et validé sur le Mac cible."
            )
            result[.mappingAutoInstall] = DJCapabilityStatus(
                availability: .unavailable,
                confidence: .unverified,
                validation: .blockedByPlatform,
                method: .unavailable,
                reason: "L’installation automatique n’est pas revendiquée pour djay."
            )
            result[.mappingRollback] = DJCapabilityStatus(
                availability: .partiallyAvailable,
                confidence: .unverified,
                validation: .requiresBackendValidation,
                method: .guidedManualStep,
                reason: "La restauration du profil djay doit encore être validée."
            )
        }
    }

    private func configureStateCapabilities(
        _ result: inout DJBackendCapabilities,
        environment: DJBackendEnvironment
    ) {
        for capability in [DJCapability.deckStateReading, .trackStateReading] {
            result[capability] = DJCapabilityStatus(
                availability: .partiallyAvailable,
                confidence: .observed,
                validation: .requiresDeviceValidation,
                method: .accessibility,
                testedSoftwareVersion: environment.softwareVersion,
                reason: "L’interface visible peut être observée, mais l’état complet des decks n’est pas encore garanti."
            )
        }
        result[.waveformReading] = DJCapabilityStatus(
            availability: .unavailable,
            confidence: .unverified,
            validation: .blockedByPlatform,
            method: .unavailable,
            reason: "MixPilot ne lit pas les formes d’onde internes du logiciel DJ."
        )
        if identifier != .djay {
            result[.automix] = DJCapabilityStatus(
                availability: .unavailable,
                confidence: .documented,
                validation: .blockedByPlatform,
                method: .unavailable,
                reason: "Ce backend utilise le moteur de transitions MixPilot plutôt qu’un mode Automix natif."
            )
        }
        result[.transitionTrigger] = DJCapabilityStatus(
            availability: .available,
            confidence: .observed,
            validation: .requiresDeviceValidation,
            method: .coreMIDI,
            testedSoftwareVersion: environment.softwareVersion,
            reason: "Le déclenchement final dépend des commandes critiques réellement confirmées."
        )
    }

    private func available(
        method: DJIntegrationMethod,
        validation: DJValidationStatus,
        confidence: DJCapabilityConfidence,
        environment: DJBackendEnvironment
    ) -> DJCapabilityStatus {
        DJCapabilityStatus(
            availability: .available,
            confidence: confidence,
            validation: validation,
            method: method,
            testedSoftwareVersion: environment.softwareVersion
        )
    }

    private func partialObservation(
        reason: String,
        environment: DJBackendEnvironment
    ) -> DJCapabilityStatus {
        DJCapabilityStatus(
            availability: .partiallyAvailable,
            confidence: .observed,
            validation: .requiresDeviceValidation,
            method: .accessibility,
            testedSoftwareVersion: environment.softwareVersion,
            reason: reason
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
            mappingVersion: "profile-\(profile.schemaVersion)",
            action: action
        )
    }

    private var legacySoftware: DJSoftware {
        switch identifier {
        case .djay: .djay
        case .rekordbox: .rekordbox
        case .serato: .serato
        }
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
        adapter = StandardDJBackendAdapter(identifier: .serato, midi: midi, validationStore: validationStore, environmentDetector: environmentDetector)
    }

    public func detectEnvironment() async -> DJBackendEnvironment { await adapter.detectEnvironment() }
    public func capabilities() async -> DJBackendCapabilities { await adapter.capabilities() }
    public func validateConfiguration() async -> DJBackendValidationReport { await adapter.validateConfiguration() }
    public func readState() async throws -> DJBackendState { try await adapter.readState() }
    public func readDeckState(_ deck: DeckID) async throws -> DJDeckState { try await adapter.readDeckState(deck) }
    public func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt { try await adapter.execute(command) }
    public func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification { try await adapter.verify(command: command, expectedEffect: expectedEffect) }
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
        adapter = StandardDJBackendAdapter(identifier: .rekordbox, midi: midi, validationStore: validationStore, environmentDetector: environmentDetector)
    }

    public func detectEnvironment() async -> DJBackendEnvironment { await adapter.detectEnvironment() }
    public func capabilities() async -> DJBackendCapabilities { await adapter.capabilities() }
    public func validateConfiguration() async -> DJBackendValidationReport { await adapter.validateConfiguration() }
    public func readState() async throws -> DJBackendState { try await adapter.readState() }
    public func readDeckState(_ deck: DeckID) async throws -> DJDeckState { try await adapter.readDeckState(deck) }
    public func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt { try await adapter.execute(command) }
    public func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification { try await adapter.verify(command: command, expectedEffect: expectedEffect) }
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
        adapter = StandardDJBackendAdapter(identifier: .djay, midi: midi, validationStore: validationStore, environmentDetector: environmentDetector)
    }

    public func detectEnvironment() async -> DJBackendEnvironment { await adapter.detectEnvironment() }
    public func capabilities() async -> DJBackendCapabilities { await adapter.capabilities() }
    public func validateConfiguration() async -> DJBackendValidationReport { await adapter.validateConfiguration() }
    public func readState() async throws -> DJBackendState { try await adapter.readState() }
    public func readDeckState(_ deck: DeckID) async throws -> DJDeckState { try await adapter.readDeckState(deck) }
    public func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt { try await adapter.execute(command) }
    public func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification { try await adapter.verify(command: command, expectedEffect: expectedEffect) }
    public func takeManualControl() async { await adapter.takeManualControl() }
}
#endif
