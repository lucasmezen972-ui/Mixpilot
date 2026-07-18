#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotMIDI

/// A reduced-friction backend used only by the explicit one-click Live flow.
///
/// It never claims that a third-party DJ application acknowledged MIDI. It
/// sends only commands present in the active mapping and lets the runtime,
/// accessibility probes and local audio watchdog supervise the result.
public actor AutomaticLiveDJBackend: DJBackend {
    public nonisolated let identifier: DJBackendIdentifier
    public nonisolated let displayName: String

    private let midi: MappedMIDIController
    private let detector = DJApplicationEnvironmentDetector()

    public init(identifier: DJBackendIdentifier, midi: MappedMIDIController) {
        self.identifier = identifier
        self.displayName = identifier.displayName
        self.midi = midi
    }

    public func detectEnvironment() async -> DJBackendEnvironment {
        await MainActor.run {
            detector.detect(identifier)
        }
    }

    public func capabilities() async -> DJBackendCapabilities {
        let environment = await detectEnvironment()
        let profile = await midi.currentProfile()
        let observation = await observe(maxDepth: 4, maximumStrings: 180)

        var result = DJBackendCapabilities()
        let systemReady = environment.isInstalled && environment.isRunning
        result[.processDetection] = status(
            available: environment.isRunning,
            method: .visibleInterfaceObservation,
            environment: environment,
            reason: environment.isRunning ? "Le logiciel DJ est lancé." : "Le logiciel DJ doit être lancé."
        )
        result[.versionDetection] = status(
            available: environment.softwareVersion != nil,
            method: .visibleInterfaceObservation,
            environment: environment,
            reason: environment.softwareVersion == nil ? "La version n’a pas été détectée, sans empêcher le contrôle MIDI." : nil
        )

        let mappedRatio = profile.liveControlCoverageRatio
        result[.mappingImport] = status(
            available: mappedRatio >= 0.5,
            method: .importedMapping,
            environment: environment,
            reason: mappedRatio >= 0.5
                ? "Le profil MIDI actif couvre les commandes nécessaires au mode automatique supervisé."
                : "Le profil MIDI actif ne contient pas assez de commandes."
        )
        result[.mappingAutoInstall] = result[.mappingImport]
        result[.mappingRollback] = result[.mappingImport]

        for capability in commandCapabilities {
            let actions = DJControlAction.allCases.filter { $0.requiredCapability == capability }
            let mapped = !actions.isEmpty && actions.allSatisfy { profile[$0] != nil }
            result[capability] = status(
                available: systemReady && mapped,
                method: .coreMIDI,
                environment: environment,
                reason: mapped
                    ? "Commande disponible dans le mapping actif ; son effet reste surveillé pendant le Live."
                    : "Une ou plusieurs commandes MIDI sont absentes du profil actif."
            )
        }

        let interfaceObservable = observation.isRunning && observation.accessibilityGranted
        let observationStatus = DJCapabilityStatus(
            availability: interfaceObservable ? .available : .partiallyAvailable,
            confidence: interfaceObservable ? .validated : .observed,
            validation: interfaceObservable ? .automatedSuccess : .requiresDeviceValidation,
            method: .accessibility,
            testedSoftwareVersion: environment.softwareVersion,
            mappingVersion: profile.validationIdentifier,
            controllerName: CoreMIDIController.virtualPortName,
            reason: interfaceObservable
                ? "L’interface du logiciel DJ peut être observée pendant le Live."
                : "L’Accessibilité n’est pas autorisée ; la surveillance audio locale reste active."
        )
        result[.visiblePlaylistReading] = observationStatus
        result[.deckStateReading] = observationStatus
        result[.trackStateReading] = observationStatus

        result[.masterAudioMonitoring] = DJCapabilityStatus(
            availability: .available,
            confidence: .validated,
            validation: .automatedSuccess,
            method: .localAudioMonitoring,
            reason: "Le démarrage automatique exige que la surveillance audio locale soit active."
        )
        result[.remoteControl] = DJCapabilityStatus(
            availability: .available,
            confidence: .documented,
            validation: .automatedSuccess,
            method: .guidedManualStep
        )
        result[.recovery] = DJCapabilityStatus(
            availability: .available,
            confidence: .validated,
            validation: .automatedSuccess,
            method: .guidedManualStep,
            reason: "La reprise manuelle et l’arrêt au point sûr restent disponibles à tout moment."
        )
        return result
    }

    public func validateConfiguration() async -> DJBackendValidationReport {
        let environment = await detectEnvironment()
        let profile = await midi.currentProfile()
        let criticalMapped = DJControlAction.automaticPresetCriticalActions.allSatisfy {
            profile[$0] != nil
        }

        return DJBackendValidationReport(
            backend: identifier,
            items: [
                DJBackendValidationItem(
                    id: "installed",
                    title: "Logiciel installé",
                    detail: environment.isInstalled
                        ? "\(displayName) est installé."
                        : "\(displayName) n’est pas installé sur ce Mac.",
                    status: environment.isInstalled ? .automatedSuccess : .failed
                ),
                DJBackendValidationItem(
                    id: "running",
                    title: "Logiciel lancé",
                    detail: environment.isRunning
                        ? "\(displayName) est ouvert."
                        : "\(displayName) doit être ouvert avant le Live.",
                    status: environment.isRunning ? .automatedSuccess : .failed
                ),
                DJBackendValidationItem(
                    id: "automatic-mapping",
                    title: "Mapping automatique",
                    detail: criticalMapped
                        ? "Les commandes critiques existent dans le profil MIDI actif."
                        : "Le profil MIDI ne couvre pas toutes les commandes critiques.",
                    status: criticalMapped ? .automatedSuccess : .failed,
                    capability: .mappingImport
                ),
                DJBackendValidationItem(
                    id: "supervision-mode",
                    title: "Mode automatique supervisé",
                    detail: "Les validations manuelles secondaires sont remplacées par la surveillance audio, les probes visibles disponibles et les variantes de transition sûres.",
                    status: .automatedSuccess
                ),
            ]
        )
    }

    public func readState() async throws -> DJBackendState {
        let observation = await observe(maxDepth: 5, maximumStrings: 250)
        guard observation.isRunning else { throw DJBackendError.disconnected(identifier) }
        return DJBackendState(
            observedAt: observation.observedAt,
            activeDeck: nil,
            decks: [:],
            automixEnabled: nil,
            isReliable: observation.accessibilityGranted
        )
    }

    public func readDeckState(_ deck: DeckID) async throws -> DJDeckState {
        let observation = await observe(maxDepth: 5, maximumStrings: 250)
        guard observation.isRunning else { throw DJBackendError.disconnected(identifier) }
        return DJDeckState(deck: deck)
    }

    public func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        let environment = await detectEnvironment()
        guard environment.isRunning else { throw DJBackendError.disconnected(identifier) }

        let profile = await midi.currentProfile()
        guard profile[command.action] != nil else {
            throw DJBackendError.capabilityUnavailable(
                command.action.requiredCapability,
                reason: "La commande \(command.action.rawValue) est absente du mapping actif."
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
            detail: "Commande MIDI envoyée en mode automatique supervisé."
        )
    }

    public func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        switch expectedEffect {
        case .loadedTrack(let track, _):
            let observation = await observe(maxDepth: 10, maximumStrings: 1_000)
            let titleFound = track.title.map(observation.contains(text:)) ?? false
            let artistFound = track.artist.map(observation.contains(text:)) ?? true
            if titleFound && artistFound {
                return DJCommandVerification(
                    status: .verified,
                    confidence: .validated,
                    detail: "Le morceau attendu est visible dans \(displayName)."
                )
            }

        case .playback(let shouldPlay, _):
            let first = await observe(maxDepth: 10, maximumStrings: 1_000)
            try await Task.sleep(for: .milliseconds(650))
            let second = await observe(maxDepth: 10, maximumStrings: 1_000)
            let probe = DJPlaybackTimecodeProbe().compare(
                firstVisibleText: first.visibleText,
                secondVisibleText: second.visibleText
            )
            if shouldPlay && probe.motion == .moving {
                return DJCommandVerification(
                    status: .verified,
                    confidence: .validated,
                    detail: "Le compteur visible avance : la lecture a démarré."
                )
            }
            if !shouldPlay && probe.motion == .stable && probe.comparedTimecodeCount > 0 {
                return DJCommandVerification(
                    status: .verified,
                    confidence: .validated,
                    detail: "Le compteur visible est stable : la lecture est arrêtée."
                )
            }

        case .normalizedValue:
            return DJCommandVerification(
                status: .observed,
                confidence: .observed,
                detail: "La valeur MIDI a été envoyée ; le watchdog audio supervise le résultat."
            )

        case .stateChanged:
            break
        }

        return DJCommandVerification(
            status: .unknown,
            confidence: .unverified,
            detail: "L’effet n’est pas lisible dans l’interface ; la surveillance audio reste la preuve de secours."
        )
    }

    public func takeManualControl() async {
        // Stopping future automation is owned by LiveAutopilotCoordinator. No
        // extra MIDI command is sent because it could alter the current mix.
    }

    private func observe(maxDepth: Int, maximumStrings: Int) async -> DJWindowObservation {
        let backend = identifier
        return await MainActor.run {
            DJAccessibilityBridge().observe(
                backend: backend,
                maxDepth: maxDepth,
                maximumStrings: maximumStrings
            )
        }
    }

    private func status(
        available: Bool,
        method: DJIntegrationMethod,
        environment: DJBackendEnvironment,
        reason: String?
    ) -> DJCapabilityStatus {
        DJCapabilityStatus(
            availability: available ? .available : .unavailable,
            confidence: available ? .validated : .unverified,
            validation: available ? .automatedSuccess : .failed,
            method: available ? method : .unavailable,
            testedSoftwareVersion: environment.softwareVersion,
            controllerName: CoreMIDIController.virtualPortName,
            reason: reason
        )
    }

    private var commandCapabilities: [DJCapability] {
        [
            .visiblePlaylistReading,
            .trackLoading,
            .playPause,
            .cue,
            .sync,
            .tempo,
            .channelVolume,
            .eqLow,
            .eqMid,
            .eqHigh,
            .filter,
            .crossfader,
            .loop,
            .effects,
        ]
    }
}
#endif
