import Foundation

public enum DJBackendIdentifier: String, Codable, CaseIterable, Identifiable, Sendable {
    case djay
    case rekordbox
    case serato

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .djay: "djay Pro"
        case .rekordbox: "rekordbox"
        case .serato: "Serato DJ Pro"
        }
    }
}

public enum DJCapability: String, Codable, CaseIterable, Hashable, Sendable {
    case processDetection
    case versionDetection
    case libraryReading
    case visiblePlaylistReading
    case trackLoading
    case playPause
    case cue
    case sync
    case tempo
    case channelVolume
    case eqLow
    case eqMid
    case eqHigh
    case filter
    case crossfader
    case loop
    case effects
    case automix
    case transitionTrigger
    case deckStateReading
    case trackStateReading
    case waveformReading
    case masterAudioMonitoring
    case mappingImport
    case mappingAutoInstall
    case mappingRollback
    case remoteControl
    case recovery
}

public enum DJCapabilityAvailability: String, Codable, Sendable {
    case available
    case partiallyAvailable
    case unavailable
    case unknown
}

public enum DJCapabilityConfidence: String, Codable, Sendable {
    case documented
    case validated
    case observed
    case simulated
    case unverified
}

public enum DJValidationStatus: String, Codable, Sendable {
    case automatedSuccess = "AUTOMATED_SUCCESS"
    case simulatedSuccess = "SIMULATED_SUCCESS"
    case requiresBackendValidation = "REQUIRES_BACKEND_VALIDATION"
    case requiresDeviceValidation = "REQUIRES_DEVICE_VALIDATION"
    case blockedByPlatform = "BLOCKED_BY_PLATFORM"
    case failed = "FAILED"
    case unknown = "UNKNOWN"
}

public enum DJIntegrationMethod: String, Codable, Sendable {
    case coreMIDI
    case importedMapping
    case accessibility
    case nativeAutomix
    case documentedLibraryImport
    case visibleInterfaceObservation
    case localAudioMonitoring
    case guidedManualStep
    case unavailable
}

public struct DJUserAction: Codable, Hashable, Sendable {
    public var title: String
    public var instructions: String

    public init(title: String, instructions: String) {
        self.title = title
        self.instructions = instructions
    }
}

public struct DJCapabilityStatus: Codable, Hashable, Sendable {
    public var availability: DJCapabilityAvailability
    public var confidence: DJCapabilityConfidence
    public var validation: DJValidationStatus
    public var method: DJIntegrationMethod?
    public var lastValidatedAt: Date?
    public var testedSoftwareVersion: String?
    public var mappingVersion: String?
    public var controllerName: String?
    public var reason: String?
    public var userAction: DJUserAction?

    public init(
        availability: DJCapabilityAvailability,
        confidence: DJCapabilityConfidence = .unverified,
        validation: DJValidationStatus = .unknown,
        method: DJIntegrationMethod? = nil,
        lastValidatedAt: Date? = nil,
        testedSoftwareVersion: String? = nil,
        mappingVersion: String? = nil,
        controllerName: String? = nil,
        reason: String? = nil,
        userAction: DJUserAction? = nil
    ) {
        self.availability = availability
        self.confidence = confidence
        self.validation = validation
        self.method = method
        self.lastValidatedAt = lastValidatedAt
        self.testedSoftwareVersion = testedSoftwareVersion
        self.mappingVersion = mappingVersion
        self.controllerName = controllerName
        self.reason = reason
        self.userAction = userAction
    }

    public var canBePlanned: Bool {
        guard availability == .available || availability == .partiallyAvailable else { return false }
        return validation != .failed && validation != .blockedByPlatform
    }

    public var isVerifiedForLive: Bool {
        availability == .available && validation == .requiresDeviceValidation ? false :
            availability == .available && validation != .failed && validation != .unknown
    }
}

public struct DJBackendCapabilities: Codable, Hashable, Sendable {
    public var values: [DJCapability: DJCapabilityStatus]

    public init(values: [DJCapability: DJCapabilityStatus] = [:]) {
        self.values = values
    }

    public subscript(_ capability: DJCapability) -> DJCapabilityStatus {
        get {
            values[capability] ?? DJCapabilityStatus(
                availability: .unknown,
                reason: "Cette capacité n’a pas encore été évaluée."
            )
        }
        set { values[capability] = newValue }
    }

    public func supports(_ capability: DJCapability) -> Bool {
        self[capability].canBePlanned
    }

    public func supportsAll(_ capabilities: Set<DJCapability>) -> Bool {
        capabilities.allSatisfy(supports)
    }

    public var degradedCapabilities: [DJCapability] {
        DJCapability.allCases.filter {
            let status = self[$0]
            return status.availability == .partiallyAvailable ||
                status.validation == .requiresBackendValidation ||
                status.validation == .requiresDeviceValidation
        }
    }
}

public struct DJBackendEnvironment: Codable, Hashable, Sendable {
    public var identifier: DJBackendIdentifier
    public var isInstalled: Bool
    public var isRunning: Bool
    public var softwareVersion: String?
    public var bundleIdentifier: String?
    public var processIdentifier: Int32?
    public var controllerName: String?

    public init(
        identifier: DJBackendIdentifier,
        isInstalled: Bool,
        isRunning: Bool,
        softwareVersion: String? = nil,
        bundleIdentifier: String? = nil,
        processIdentifier: Int32? = nil,
        controllerName: String? = nil
    ) {
        self.identifier = identifier
        self.isInstalled = isInstalled
        self.isRunning = isRunning
        self.softwareVersion = softwareVersion
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.controllerName = controllerName
    }
}

public struct DJTrackReference: Codable, Hashable, Sendable {
    public var id: String
    public var title: String?
    public var artist: String?

    public init(id: String, title: String? = nil, artist: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
    }
}

public struct DJDeckState: Codable, Hashable, Sendable {
    public var deck: DeckID
    public var track: DJTrackReference?
    public var isPlaying: Bool?
    public var position: TimeInterval?
    public var tempoBPM: Double?
    public var channelVolume: Double?

    public init(
        deck: DeckID,
        track: DJTrackReference? = nil,
        isPlaying: Bool? = nil,
        position: TimeInterval? = nil,
        tempoBPM: Double? = nil,
        channelVolume: Double? = nil
    ) {
        self.deck = deck
        self.track = track
        self.isPlaying = isPlaying
        self.position = position
        self.tempoBPM = tempoBPM
        self.channelVolume = channelVolume
    }
}

public struct DJBackendState: Codable, Hashable, Sendable {
    public var observedAt: Date
    public var activeDeck: DeckID?
    public var decks: [DeckID: DJDeckState]
    public var automixEnabled: Bool?
    public var isReliable: Bool

    public init(
        observedAt: Date = Date(),
        activeDeck: DeckID? = nil,
        decks: [DeckID: DJDeckState] = [:],
        automixEnabled: Bool? = nil,
        isReliable: Bool = false
    ) {
        self.observedAt = observedAt
        self.activeDeck = activeDeck
        self.decks = decks
        self.automixEnabled = automixEnabled
        self.isReliable = isReliable
    }
}

public enum DJControlAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case playA, playB
    case pauseA, pauseB
    case cueA, cueB
    case syncA, syncB
    case loadA, loadB
    case browserUp, browserDown, browserFocus
    case volumeA, volumeB
    case crossfader
    case lowEQA, lowEQB
    case midEQA, midEQB
    case highEQA, highEQB
    case filterA, filterB
    case pitchA, pitchB
    case echoA, echoB
    case echoAmountA, echoAmountB
    case loopA, loopB
    case exitLoopA, exitLoopB

    public var id: String { rawValue }

    public static func play(deck: DeckID) -> Self { deck == .a ? .playA : .playB }
    public static func pause(deck: DeckID) -> Self { deck == .a ? .pauseA : .pauseB }
    public static func cue(deck: DeckID) -> Self { deck == .a ? .cueA : .cueB }
    public static func sync(deck: DeckID) -> Self { deck == .a ? .syncA : .syncB }
    public static func load(deck: DeckID) -> Self { deck == .a ? .loadA : .loadB }
    public static func volume(deck: DeckID) -> Self { deck == .a ? .volumeA : .volumeB }
    public static func lowEQ(deck: DeckID) -> Self { deck == .a ? .lowEQA : .lowEQB }
    public static func filter(deck: DeckID) -> Self { deck == .a ? .filterA : .filterB }
    public static func echo(deck: DeckID) -> Self { deck == .a ? .echoA : .echoB }
    public static func echoAmount(deck: DeckID) -> Self { deck == .a ? .echoAmountA : .echoAmountB }
}

public struct DJBackendCommand: Codable, Hashable, Sendable {
    public var id: UUID
    public var action: DJControlAction
    public var normalizedValue: Double?
    public var requestedAt: Date
    public var idempotencyKey: String

    public init(
        id: UUID = UUID(),
        action: DJControlAction,
        normalizedValue: Double? = nil,
        requestedAt: Date = Date(),
        idempotencyKey: String? = nil
    ) {
        self.id = id
        self.action = action
        self.normalizedValue = normalizedValue.map { min(max($0, 0), 1) }
        self.requestedAt = requestedAt
        self.idempotencyKey = idempotencyKey ?? id.uuidString
    }
}

public enum DJCommandLifecycleStatus: String, Codable, Sendable {
    case requested = "REQUESTED"
    case sent = "SENT"
    case acknowledged = "ACKNOWLEDGED"
    case observed = "OBSERVED"
    case verified = "VERIFIED"
    case failed = "FAILED"
    case unknown = "UNKNOWN"
}

public struct DJCommandReceipt: Codable, Hashable, Sendable {
    public var commandID: UUID
    public var status: DJCommandLifecycleStatus
    public var updatedAt: Date
    public var detail: String?

    public init(
        commandID: UUID,
        status: DJCommandLifecycleStatus,
        updatedAt: Date = Date(),
        detail: String? = nil
    ) {
        self.commandID = commandID
        self.status = status
        self.updatedAt = updatedAt
        self.detail = detail
    }
}

public enum DJExpectedEffect: Codable, Hashable, Sendable {
    case playback(Bool, deck: DeckID)
    case loadedTrack(DJTrackReference, deck: DeckID)
    case normalizedValue(Double, capability: DJCapability, deck: DeckID?)
    case stateChanged
}

public struct DJCommandVerification: Codable, Hashable, Sendable {
    public var status: DJCommandLifecycleStatus
    public var confidence: DJCapabilityConfidence
    public var detail: String

    public init(
        status: DJCommandLifecycleStatus,
        confidence: DJCapabilityConfidence,
        detail: String
    ) {
        self.status = status
        self.confidence = confidence
        self.detail = detail
    }
}

public struct DJBackendValidationItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var status: DJValidationStatus
    public var capability: DJCapability?
    public var userAction: DJUserAction?

    public init(
        id: String,
        title: String,
        detail: String,
        status: DJValidationStatus,
        capability: DJCapability? = nil,
        userAction: DJUserAction? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.capability = capability
        self.userAction = userAction
    }
}

public struct DJBackendValidationReport: Codable, Hashable, Sendable {
    public var backend: DJBackendIdentifier
    public var generatedAt: Date
    public var items: [DJBackendValidationItem]

    public init(
        backend: DJBackendIdentifier,
        generatedAt: Date = Date(),
        items: [DJBackendValidationItem]
    ) {
        self.backend = backend
        self.generatedAt = generatedAt
        self.items = items
    }

    public var hasBlockingFailure: Bool {
        items.contains { $0.status == .failed || $0.status == .blockedByPlatform }
    }
}

public enum DJBackendError: Error, LocalizedError, Sendable {
    case notSelected
    case unavailable(DJBackendIdentifier)
    case liveChangeForbidden
    case capabilityUnavailable(DJCapability, reason: String?)
    case commandTimedOut(DJControlAction)
    case commandRejected(String)
    case stateUnavailable(String)
    case disconnected(DJBackendIdentifier)

    public var errorDescription: String? {
        switch self {
        case .notSelected:
            "Choisis le logiciel DJ à utiliser avant de continuer."
        case .unavailable(let backend):
            "\(backend.displayName) n’est pas disponible sur ce Mac."
        case .liveChangeForbidden:
            "Le logiciel DJ ne peut pas être changé pendant le Live. Reprends la main ou termine le set avant de changer."
        case .capabilityUnavailable(_, let reason):
            reason ?? "Cette fonction n’est pas disponible dans la configuration actuelle."
        case .commandTimedOut:
            "Le logiciel DJ n’a pas confirmé la commande à temps. MixPilot n’enverra pas de commandes supplémentaires à l’aveugle."
        case .commandRejected(let reason):
            reason
        case .stateUnavailable(let reason):
            reason
        case .disconnected(let backend):
            "La connexion avec \(backend.displayName) a été perdue. Reprends la main et vérifie le logiciel avant de continuer."
        }
    }
}

public protocol DJBackend: Sendable {
    var identifier: DJBackendIdentifier { get }
    var displayName: String { get }

    func detectEnvironment() async -> DJBackendEnvironment
    func capabilities() async -> DJBackendCapabilities
    func validateConfiguration() async -> DJBackendValidationReport
    func readState() async throws -> DJBackendState
    func readDeckState(_ deck: DeckID) async throws -> DJDeckState
    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt
    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification
    func takeManualControl() async
}

public struct DJBackendDescriptor: Sendable {
    public var identifier: DJBackendIdentifier
    public var displayName: String
    public var environment: DJBackendEnvironment
    public var capabilities: DJBackendCapabilities

    public init(
        identifier: DJBackendIdentifier,
        displayName: String,
        environment: DJBackendEnvironment,
        capabilities: DJBackendCapabilities
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.environment = environment
        self.capabilities = capabilities
    }
}

public protocol DJBackendSelectionStoring: Sendable {
    func loadSelection() async -> DJBackendIdentifier?
    func saveSelection(_ identifier: DJBackendIdentifier?) async throws
}

public actor UserDefaultsDJBackendSelectionStore: DJBackendSelectionStoring {
    public static let defaultsKey = "MixPilotSelectedDJBackendV2"
    public static let legacyDefaultsKey = "MixPilotSelectedDJSoftware"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadSelection() async -> DJBackendIdentifier? {
        if let rawValue = defaults.string(forKey: Self.defaultsKey),
           let identifier = DJBackendIdentifier(rawValue: rawValue) {
            return identifier
        }

        if let legacyValue = defaults.string(forKey: Self.legacyDefaultsKey),
           let migrated = DJBackendIdentifier(rawValue: legacyValue) {
            defaults.set(migrated.rawValue, forKey: Self.defaultsKey)
            return migrated
        }

        return nil
    }

    public func saveSelection(_ identifier: DJBackendIdentifier?) async throws {
        if let identifier {
            defaults.set(identifier.rawValue, forKey: Self.defaultsKey)
        } else {
            defaults.removeObject(forKey: Self.defaultsKey)
        }
    }
}

public actor InMemoryDJBackendSelectionStore: DJBackendSelectionStoring {
    private var identifier: DJBackendIdentifier?

    public init(identifier: DJBackendIdentifier? = nil) {
        self.identifier = identifier
    }

    public func loadSelection() async -> DJBackendIdentifier? { identifier }

    public func saveSelection(_ identifier: DJBackendIdentifier?) async throws {
        self.identifier = identifier
    }
}

public actor DJBackendRegistry {
    private let backends: [DJBackendIdentifier: any DJBackend]
    private let selectionStore: any DJBackendSelectionStoring
    private var selectedIdentifier: DJBackendIdentifier?
    private var liveActive = false

    public init(
        backends: [any DJBackend],
        selectionStore: any DJBackendSelectionStoring = UserDefaultsDJBackendSelectionStore()
    ) {
        self.backends = Dictionary(uniqueKeysWithValues: backends.map { ($0.identifier, $0) })
        self.selectionStore = selectionStore
    }

    public func restoreSelection() async -> DJBackendIdentifier? {
        if selectedIdentifier == nil {
            selectedIdentifier = await selectionStore.loadSelection()
        }
        return selectedIdentifier
    }

    public func availableBackends() async -> [DJBackendDescriptor] {
        var descriptors: [DJBackendDescriptor] = []
        for identifier in DJBackendIdentifier.allCases {
            guard let backend = backends[identifier] else { continue }
            async let environment = backend.detectEnvironment()
            async let capabilities = backend.capabilities()
            descriptors.append(await DJBackendDescriptor(
                identifier: identifier,
                displayName: backend.displayName,
                environment: environment,
                capabilities: capabilities
            ))
        }
        return descriptors
    }

    public func selectedBackend() async -> DJBackendIdentifier? {
        await restoreSelection()
    }

    public func select(_ identifier: DJBackendIdentifier) async throws {
        guard !liveActive else { throw DJBackendError.liveChangeForbidden }
        guard backends[identifier] != nil else { throw DJBackendError.unavailable(identifier) }
        selectedIdentifier = identifier
        try await selectionStore.saveSelection(identifier)
    }

    public func clearSelection() async throws {
        guard !liveActive else { throw DJBackendError.liveChangeForbidden }
        selectedIdentifier = nil
        try await selectionStore.saveSelection(nil)
    }

    public func activeBackend() async throws -> any DJBackend {
        guard let selected = await restoreSelection() else { throw DJBackendError.notSelected }
        guard let backend = backends[selected] else { throw DJBackendError.unavailable(selected) }
        return backend
    }

    public func setLiveActive(_ active: Bool) {
        liveActive = active
    }

    public func isLiveActive() -> Bool { liveActive }
}
