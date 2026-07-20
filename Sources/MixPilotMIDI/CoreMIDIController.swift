#if os(macOS)
import CoreMIDI
import Foundation
import MixPilotCore

public enum MIDIControllerError: Error, LocalizedError {
    case clientCreation(OSStatus)
    case sourceCreation(OSStatus)
    case destinationCreation(OSStatus)
    case packetCreation
    case missingMapping(SeratoAction)
    case endpointNotPublished(String)

    public var errorDescription: String? {
        switch self {
        case .clientCreation(let status): "Impossible de créer le client CoreMIDI (\(status))."
        case .sourceCreation(let status): "Impossible de créer l’entrée MIDI virtuelle (\(status))."
        case .destinationCreation(let status): "Impossible de créer la sortie MIDI virtuelle (\(status))."
        case .packetCreation: "Impossible de construire le paquet MIDI."
        case .missingMapping(let action): "La commande \(action.rawValue) n'est pas encore mappée."
        case .endpointNotPublished(let detail): "Le contrôleur MIDI virtuel n’est pas publié correctement : \(detail)"
        }
    }
}

public struct MIDIPublishedEndpoint: Codable, Hashable, Sendable {
    public var name: String
    public var displayName: String
    public var manufacturer: String
    public var model: String
    public var uniqueID: Int32?
    public var isSource: Bool

    public init(
        name: String,
        displayName: String,
        manufacturer: String,
        model: String,
        uniqueID: Int32?,
        isSource: Bool
    ) {
        self.name = name
        self.displayName = displayName
        self.manufacturer = manufacturer
        self.model = model
        self.uniqueID = uniqueID
        self.isSource = isSource
    }
}

public struct MIDIPublicationDiagnostic: Codable, Hashable, Sendable {
    public var expectedSourceName: String
    public var expectedDestinationName: String
    public var sourcePublished: Bool
    public var destinationPublished: Bool
    public var sourceUniqueIDMatches: Bool
    public var destinationUniqueIDMatches: Bool
    public var visibleSources: [MIDIPublishedEndpoint]
    public var visibleDestinations: [MIDIPublishedEndpoint]
    public var configurationWarnings: [String]

    public init(
        expectedSourceName: String,
        expectedDestinationName: String,
        sourcePublished: Bool,
        destinationPublished: Bool,
        sourceUniqueIDMatches: Bool,
        destinationUniqueIDMatches: Bool,
        visibleSources: [MIDIPublishedEndpoint],
        visibleDestinations: [MIDIPublishedEndpoint],
        configurationWarnings: [String]
    ) {
        self.expectedSourceName = expectedSourceName
        self.expectedDestinationName = expectedDestinationName
        self.sourcePublished = sourcePublished
        self.destinationPublished = destinationPublished
        self.sourceUniqueIDMatches = sourceUniqueIDMatches
        self.destinationUniqueIDMatches = destinationUniqueIDMatches
        self.visibleSources = visibleSources
        self.visibleDestinations = visibleDestinations
        self.configurationWarnings = configurationWarnings
    }

    public var isReadyForSerato: Bool {
        sourcePublished && destinationPublished
    }

    public var summary: String {
        if isReadyForSerato {
            return configurationWarnings.isEmpty
                ? "Contrôleur CoreMIDI publié"
                : "Contrôleur publié avec \(configurationWarnings.count) avertissement(s)"
        }
        if !sourcePublished && !destinationPublished {
            return "Entrée et sortie MIDI introuvables dans CoreMIDI"
        }
        if !sourcePublished { return "Entrée MIDI virtuelle introuvable" }
        return "Sortie MIDI virtuelle introuvable"
    }
}

// SAFETY: CoreMIDI handles are immutable after initialization. Every packet send
// is serialized by sendLock, and disposal only occurs once when the final owner dies.
private final class SharedMIDIEndpoint: @unchecked Sendable {
    let client: MIDIClientRef
    let source: MIDIEndpointRef
    let destination: MIDIEndpointRef
    let sendLock = NSLock()
    let configurationWarnings: [String]

    init(sourceName: String, destinationName: String) throws {
        var createdClient = MIDIClientRef()
        let clientStatus = MIDIClientCreateWithBlock("MixPilot MIDI Client" as CFString, &createdClient) { _ in }
        guard clientStatus == noErr else { throw MIDIControllerError.clientCreation(clientStatus) }

        var createdDestination = MIDIEndpointRef()
        let destinationStatus = MIDIDestinationCreateWithBlock(
            createdClient,
            destinationName as CFString,
            &createdDestination
        ) { _, _ in }
        guard destinationStatus == noErr else {
            MIDIClientDispose(createdClient)
            throw MIDIControllerError.destinationCreation(destinationStatus)
        }

        var createdSource = MIDIEndpointRef()
        let sourceStatus = MIDISourceCreate(createdClient, sourceName as CFString, &createdSource)
        guard sourceStatus == noErr else {
            MIDIEndpointDispose(createdDestination)
            MIDIClientDispose(createdClient)
            throw MIDIControllerError.sourceCreation(sourceStatus)
        }

        client = createdClient
        source = createdSource
        destination = createdDestination

        var warnings: [String] = []
        Self.configure(
            endpoint: source,
            name: sourceName,
            displayName: sourceName,
            uniqueID: CoreMIDIController.sourceUniqueID,
            warnings: &warnings
        )
        Self.configure(
            endpoint: destination,
            name: destinationName,
            displayName: destinationName,
            uniqueID: CoreMIDIController.destinationUniqueID,
            warnings: &warnings
        )
        configurationWarnings = warnings
    }

    deinit {
        if source != 0 { MIDIEndpointDispose(source) }
        if destination != 0 { MIDIEndpointDispose(destination) }
        if client != 0 { MIDIClientDispose(client) }
    }

    private static func configure(
        endpoint: MIDIEndpointRef,
        name: String,
        displayName: String,
        uniqueID: Int32,
        warnings: inout [String]
    ) {
        setString(endpoint, property: kMIDIPropertyName, value: name, warnings: &warnings)
        setString(endpoint, property: kMIDIPropertyDisplayName, value: displayName, warnings: &warnings)
        setString(endpoint, property: kMIDIPropertyManufacturer, value: "MixPilot", warnings: &warnings)
        setString(endpoint, property: kMIDIPropertyModel, value: "MixPilot Virtual Controller", warnings: &warnings)
        setInteger(endpoint, property: kMIDIPropertyUniqueID, value: uniqueID, warnings: &warnings)
        setInteger(endpoint, property: kMIDIPropertyPrivate, value: 0, warnings: &warnings)
        setInteger(endpoint, property: kMIDIPropertyOffline, value: 0, warnings: &warnings)
    }

    private static func setString(
        _ endpoint: MIDIEndpointRef,
        property: CFString,
        value: String,
        warnings: inout [String]
    ) {
        let status = MIDIObjectSetStringProperty(endpoint, property, value as CFString)
        if status != noErr {
            warnings.append("Propriété \(property) non publiée (\(status))")
        }
    }

    private static func setInteger(
        _ endpoint: MIDIEndpointRef,
        property: CFString,
        value: Int32,
        warnings: inout [String]
    ) {
        let status = MIDIObjectSetIntegerProperty(endpoint, property, value)
        if status != noErr {
            warnings.append("Propriété \(property) non publiée (\(status))")
        }
    }
}

// SAFETY: endpoint is only read or written while creationLock is held. The shared
// endpoint is created once, retained for process lifetime, and never replaced.
private final class SharedMIDIEndpointRegistry: @unchecked Sendable {
    static let shared = SharedMIDIEndpointRegistry()

    private let creationLock = NSLock()
    private var endpoint: SharedMIDIEndpoint?

    private init() {}

    func resolve(sourceName: String, destinationName: String) throws -> SharedMIDIEndpoint {
        creationLock.lock()
        defer { creationLock.unlock() }
        if let endpoint { return endpoint }
        let created = try SharedMIDIEndpoint(sourceName: sourceName, destinationName: destinationName)
        endpoint = created
        return created
    }
}

// SAFETY: CoreMIDIController only holds an immutable reference to the internally
// synchronized SharedMIDIEndpoint. Public methods do not mutate controller state.
public final class CoreMIDIController: @unchecked Sendable {
    public static let virtualPortName = "MixPilot Virtual Controller"
    public static let virtualOutputPortName = "MixPilot Virtual Controller Output"
    public static let sourceUniqueID: Int32 = 1_297_110_605
    public static let destinationUniqueID: Int32 = 1_297_110_606

    private let endpoint: SharedMIDIEndpoint

    public init() throws {
        endpoint = try SharedMIDIEndpointRegistry.shared.resolve(
            sourceName: Self.virtualPortName,
            destinationName: Self.virtualOutputPortName
        )
        let diagnostic = publicationDiagnostic()
        guard diagnostic.sourcePublished else {
            throw MIDIControllerError.endpointNotPublished(diagnostic.summary)
        }
    }

    public func publicationDiagnostic() -> MIDIPublicationDiagnostic {
        let sources = Self.enumerateEndpoints(sources: true)
        let destinations = Self.enumerateEndpoints(sources: false)
        let source = sources.first { endpoint in
            endpoint.name == Self.virtualPortName || endpoint.displayName == Self.virtualPortName
        }
        let destination = destinations.first { endpoint in
            endpoint.name == Self.virtualOutputPortName || endpoint.displayName == Self.virtualOutputPortName
        }

        return MIDIPublicationDiagnostic(
            expectedSourceName: Self.virtualPortName,
            expectedDestinationName: Self.virtualOutputPortName,
            sourcePublished: source != nil,
            destinationPublished: destination != nil,
            sourceUniqueIDMatches: source?.uniqueID == Self.sourceUniqueID,
            destinationUniqueIDMatches: destination?.uniqueID == Self.destinationUniqueID,
            visibleSources: sources,
            visibleDestinations: destinations,
            configurationWarnings: endpoint.configurationWarnings
        )
    }

    public func requirePublishedControllerPair() throws -> MIDIPublicationDiagnostic {
        let diagnostic = publicationDiagnostic()
        guard diagnostic.isReadyForSerato else {
            throw MIDIControllerError.endpointNotPublished(diagnostic.summary)
        }
        return diagnostic
    }

    public func sendControlChange(channel: UInt8 = 0, controller: UInt8, value: Double) throws {
        let normalized = UInt8((value.clamped(to: 0...1) * 127).rounded())
        try sendControlChangeRaw(channel: channel, controller: controller, value: normalized)
    }

    public func sendControlChangeRaw(channel: UInt8 = 0, controller: UInt8, value: UInt8) throws {
        try send([0xB0 | (channel & 0x0F), controller & 0x7F, value & 0x7F])
    }

    public func sendNote(channel: UInt8 = 0, note: UInt8, velocity: UInt8 = 127) throws {
        try sendNoteOn(channel: channel, note: note, velocity: velocity)
        try sendNoteOff(channel: channel, note: note)
    }

    public func sendNoteOn(channel: UInt8 = 0, note: UInt8, velocity: UInt8 = 127) throws {
        try send([0x90 | (channel & 0x0F), note & 0x7F, velocity & 0x7F])
    }

    public func sendNoteOff(channel: UInt8 = 0, note: UInt8, velocity: UInt8 = 0) throws {
        try send([0x80 | (channel & 0x0F), note & 0x7F, velocity & 0x7F])
    }

    public func trigger(_ mapping: MIDIMessageMapping) throws {
        switch mapping.kind {
        case .note:
            try sendNote(
                channel: mapping.channel,
                note: mapping.number,
                velocity: mapping.maximumRawValue
            )
        case .controlChange:
            try sendControlChangeRaw(
                channel: mapping.channel,
                controller: mapping.number,
                value: mapping.maximumRawValue
            )
            if mapping.isMomentary {
                try sendControlChangeRaw(
                    channel: mapping.channel,
                    controller: mapping.number,
                    value: mapping.offRawValue
                )
            }
        }
    }

    public func set(_ mapping: MIDIMessageMapping, normalizedValue: Double) throws {
        let rawValue = mapping.rawValue(for: normalizedValue)
        switch mapping.kind {
        case .note:
            try sendNoteOn(channel: mapping.channel, note: mapping.number, velocity: rawValue)
            if mapping.isMomentary {
                try sendNoteOff(channel: mapping.channel, note: mapping.number, velocity: mapping.offRawValue)
            }
        case .controlChange:
            try sendControlChangeRaw(
                channel: mapping.channel,
                controller: mapping.number,
                value: rawValue
            )
        }
    }

    private func send(_ bytes: [UInt8]) throws {
        endpoint.sendLock.lock()
        defer { endpoint.sendLock.unlock() }

        var packetList = MIDIPacketList()
        let sent = withUnsafeMutablePointer(to: &packetList) { listPointer -> Bool in
            let packetPointer = MIDIPacketListInit(listPointer)
            return bytes.withUnsafeBufferPointer { bytePointer in
                guard let baseAddress = bytePointer.baseAddress else { return false }
                _ = MIDIPacketListAdd(
                    listPointer,
                    MemoryLayout<MIDIPacketList>.size,
                    packetPointer,
                    0,
                    bytes.count,
                    baseAddress
                )
                return MIDIReceived(endpoint.source, listPointer) == noErr
            }
        }

        guard sent else { throw MIDIControllerError.packetCreation }
    }

    private static func enumerateEndpoints(sources: Bool) -> [MIDIPublishedEndpoint] {
        let count = sources ? MIDIGetNumberOfSources() : MIDIGetNumberOfDestinations()
        return (0..<count).compactMap { index in
            let endpoint = sources ? MIDIGetSource(index) : MIDIGetDestination(index)
            guard endpoint != 0 else { return nil }
            return MIDIPublishedEndpoint(
                name: stringProperty(endpoint, key: kMIDIPropertyName) ?? "",
                displayName: stringProperty(endpoint, key: kMIDIPropertyDisplayName) ?? "",
                manufacturer: stringProperty(endpoint, key: kMIDIPropertyManufacturer) ?? "",
                model: stringProperty(endpoint, key: kMIDIPropertyModel) ?? "",
                uniqueID: integerProperty(endpoint, key: kMIDIPropertyUniqueID),
                isSource: sources
            )
        }
    }

    private static func stringProperty(_ object: MIDIObjectRef, key: CFString) -> String? {
        var value: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(object, key, &value) == noErr,
              let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func integerProperty(_ object: MIDIObjectRef, key: CFString) -> Int32? {
        var value: Int32 = 0
        guard MIDIObjectGetIntegerProperty(object, key, &value) == noErr else { return nil }
        return value
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
#endif
