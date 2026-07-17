import Foundation
@testable import MixPilotCore

actor MockDJBackendState {
    var commands: [DJBackendCommand] = []
    var manualControlCount = 0
    var connected = true
    var delay: Duration = .zero

    func record(_ command: DJBackendCommand) {
        commands.append(command)
    }

    func requestManualControl() {
        manualControlCount += 1
    }

    func setConnected(_ value: Bool) {
        connected = value
    }

    func setDelay(_ value: Duration) {
        delay = value
    }
}

struct FullyCapableBackend: DJBackend {
    let identifier: DJBackendIdentifier
    let displayName: String
    let state: MockDJBackendState

    init(
        identifier: DJBackendIdentifier = .serato,
        state: MockDJBackendState = MockDJBackendState()
    ) {
        self.identifier = identifier
        self.displayName = identifier.displayName
        self.state = state
    }

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(
            identifier: identifier,
            isInstalled: true,
            isRunning: await state.connected,
            softwareVersion: "test-1.0",
            bundleIdentifier: "test.\(identifier.rawValue)",
            processIdentifier: 42,
            controllerName: "MixPilot Virtual Controller"
        )
    }

    func capabilities() async -> DJBackendCapabilities {
        let ready = DJCapabilityStatus(
            availability: .available,
            confidence: .validated,
            validation: .automatedSuccess,
            method: .coreMIDI,
            testedSoftwareVersion: "test-1.0"
        )
        return DJBackendCapabilities(values: Dictionary(
            uniqueKeysWithValues: DJCapability.allCases.map { ($0, ready) }
        ))
    }

    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(
            backend: identifier,
            items: [
                DJBackendValidationItem(
                    id: "ready",
                    title: "Connexion",
                    detail: "Le backend simulé est prêt.",
                    status: .automatedSuccess
                )
            ]
        )
    }

    func readState() async throws -> DJBackendState {
        guard await state.connected else { throw DJBackendError.disconnected(identifier) }
        return DJBackendState(
            activeDeck: .a,
            decks: [
                .a: DJDeckState(deck: .a, isPlaying: true, channelVolume: 1),
                .b: DJDeckState(deck: .b, isPlaying: false, channelVolume: 0)
            ],
            isReliable: true
        )
    }

    func readDeckState(_ deck: DeckID) async throws -> DJDeckState {
        guard await state.connected else { throw DJBackendError.disconnected(identifier) }
        return DJDeckState(deck: deck, isPlaying: deck == .a)
    }

    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        guard await state.connected else { throw DJBackendError.disconnected(identifier) }
        let delay = await state.delay
        if delay > .zero { try await Task.sleep(for: delay) }
        try Task.checkCancellation()
        await state.record(command)
        return DJCommandReceipt(commandID: command.id, status: .acknowledged)
    }

    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        guard await state.connected else { throw DJBackendError.disconnected(identifier) }
        return DJCommandVerification(
            status: .verified,
            confidence: .validated,
            detail: "Effet simulé confirmé."
        )
    }

    func takeManualControl() async {
        await state.requestManualControl()
    }
}

struct PartialBackend: DJBackend {
    let identifier: DJBackendIdentifier
    let displayName: String
    let state: MockDJBackendState

    init(identifier: DJBackendIdentifier = .rekordbox) {
        self.identifier = identifier
        self.displayName = identifier.displayName
        self.state = MockDJBackendState()
    }

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(identifier: identifier, isInstalled: true, isRunning: true, softwareVersion: "test-partial")
    }

    func capabilities() async -> DJBackendCapabilities {
        var result = DJBackendCapabilities()
        let available: Set<DJCapability> = [
            .processDetection, .versionDetection, .libraryReading,
            .trackLoading, .playPause, .cue, .sync,
            .channelVolume, .eqLow, .eqMid, .eqHigh,
            .mappingImport, .remoteControl, .recovery
        ]
        for capability in DJCapability.allCases {
            result[capability] = DJCapabilityStatus(
                availability: available.contains(capability) ? .available : .unavailable,
                confidence: available.contains(capability) ? .observed : .unverified,
                validation: available.contains(capability) ? .requiresDeviceValidation : .blockedByPlatform,
                method: available.contains(capability) ? .importedMapping : .unavailable,
                reason: available.contains(capability) ? nil : "Non disponible dans ce backend simulé."
            )
        }
        return result
    }

    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(backend: identifier, items: [])
    }

    func readState() async throws -> DJBackendState {
        DJBackendState(isReliable: false)
    }

    func readDeckState(_ deck: DeckID) async throws -> DJDeckState {
        DJDeckState(deck: deck)
    }

    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        let capability = Self.capability(for: command.action)
        guard await capabilities().supports(capability) else {
            throw DJBackendError.capabilityUnavailable(capability, reason: "Cette commande n’est pas disponible dans le backend partiel.")
        }
        await state.record(command)
        return DJCommandReceipt(commandID: command.id, status: .acknowledged)
    }

    func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification {
        DJCommandVerification(status: .unknown, confidence: .unverified, detail: "L’effet ne peut pas être observé de manière fiable.")
    }

    func takeManualControl() async {
        await state.requestManualControl()
    }

    static func capability(for action: DJControlAction) -> DJCapability {
        switch action {
        case .playA, .playB, .pauseA, .pauseB: .playPause
        case .cueA, .cueB: .cue
        case .syncA, .syncB: .sync
        case .loadA, .loadB: .trackLoading
        case .browserUp, .browserDown, .browserFocus: .visiblePlaylistReading
        case .volumeA, .volumeB: .channelVolume
        case .crossfader: .crossfader
        case .lowEQA, .lowEQB: .eqLow
        case .midEQA, .midEQB: .eqMid
        case .highEQA, .highEQB: .eqHigh
        case .filterA, .filterB: .filter
        case .pitchA, .pitchB: .tempo
        case .echoA, .echoB, .echoAmountA, .echoAmountB: .effects
        case .loopA, .loopB, .exitLoopA, .exitLoopB: .loop
        }
    }
}

struct UnreliableBackend: DJBackend {
    let identifier: DJBackendIdentifier = .djay
    let displayName = "djay Pro"
    let state = MockDJBackendState()

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(identifier: identifier, isInstalled: true, isRunning: true, softwareVersion: "test-unreliable")
    }

    func capabilities() async -> DJBackendCapabilities {
        var values = DJBackendCapabilities()
        for capability in DJCapability.allCases {
            values[capability] = DJCapabilityStatus(
                availability: .partiallyAvailable,
                confidence: .unverified,
                validation: .requiresBackendValidation,
                reason: "Le backend simulé peut répondre de manière incomplète."
            )
        }
        return values
    }

    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(backend: identifier, items: [])
    }

    func readState() async throws -> DJBackendState {
        DJBackendState(isReliable: false)
    }

    func readDeckState(_ deck: DeckID) async throws -> DJDeckState {
        DJDeckState(deck: deck)
    }

    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        await state.record(command)
        return DJCommandReceipt(commandID: command.id, status: .unknown, detail: "Commande envoyée sans confirmation.")
    }

    func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification {
        DJCommandVerification(status: .unknown, confidence: .unverified, detail: "État impossible à confirmer.")
    }

    func takeManualControl() async {
        await state.requestManualControl()
    }
}

struct ReadOnlyBackend: DJBackend {
    let identifier: DJBackendIdentifier = .djay
    let displayName = "djay Pro"

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(identifier: identifier, isInstalled: true, isRunning: true)
    }

    func capabilities() async -> DJBackendCapabilities {
        var values = DJBackendCapabilities()
        for capability in DJCapability.allCases {
            let readable: Set<DJCapability> = [.processDetection, .versionDetection, .visiblePlaylistReading, .trackStateReading]
            values[capability] = DJCapabilityStatus(
                availability: readable.contains(capability) ? .available : .unavailable,
                confidence: readable.contains(capability) ? .observed : .unverified,
                validation: readable.contains(capability) ? .requiresDeviceValidation : .blockedByPlatform,
                method: readable.contains(capability) ? .accessibility : .unavailable
            )
        }
        return values
    }

    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(backend: identifier, items: [])
    }

    func readState() async throws -> DJBackendState { DJBackendState(isReliable: false) }
    func readDeckState(_ deck: DeckID) async throws -> DJDeckState { DJDeckState(deck: deck) }

    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        throw DJBackendError.commandRejected("Ce backend fonctionne actuellement en lecture seule.")
    }

    func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification {
        DJCommandVerification(status: .unknown, confidence: .observed, detail: "Lecture seule.")
    }

    func takeManualControl() async {}
}

struct DisconnectedBackend: DJBackend {
    let identifier: DJBackendIdentifier
    let displayName: String

    init(identifier: DJBackendIdentifier = .serato) {
        self.identifier = identifier
        self.displayName = identifier.displayName
    }

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(identifier: identifier, isInstalled: true, isRunning: false)
    }

    func capabilities() async -> DJBackendCapabilities { DJBackendCapabilities() }
    func validateConfiguration() async -> DJBackendValidationReport { DJBackendValidationReport(backend: identifier, items: []) }
    func readState() async throws -> DJBackendState { throw DJBackendError.disconnected(identifier) }
    func readDeckState(_ deck: DeckID) async throws -> DJDeckState { throw DJBackendError.disconnected(identifier) }
    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt { throw DJBackendError.disconnected(identifier) }
    func verify(command: DJBackendCommand, expectedEffect: DJExpectedEffect) async throws -> DJCommandVerification { throw DJBackendError.disconnected(identifier) }
    func takeManualControl() async {}
}
