#if os(macOS)
import CoreMIDI
import Foundation
import MixPilotCore

public enum MIDIControllerError: Error, LocalizedError {
    case clientCreation(OSStatus)
    case sourceCreation(OSStatus)
    case packetCreation
    case missingMapping(SeratoAction)

    public var errorDescription: String? {
        switch self {
        case .clientCreation(let status): "Impossible de créer le client CoreMIDI (\(status))."
        case .sourceCreation(let status): "Impossible de créer le port MIDI virtuel (\(status))."
        case .packetCreation: "Impossible de construire le paquet MIDI."
        case .missingMapping(let action): "La commande \(action.rawValue) n'est pas encore mappée."
        }
    }
}

public final class CoreMIDIController: @unchecked Sendable {
    public static let virtualPortName = "MixPilot Virtual Controller"

    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()
    private let lock = NSLock()

    public init() throws {
        let clientStatus = MIDIClientCreateWithBlock("MixPilot MIDI Client" as CFString, &client) { _ in }
        guard clientStatus == noErr else { throw MIDIControllerError.clientCreation(clientStatus) }

        let sourceStatus = MIDISourceCreate(client, Self.virtualPortName as CFString, &source)
        guard sourceStatus == noErr else {
            MIDIClientDispose(client)
            throw MIDIControllerError.sourceCreation(sourceStatus)
        }
    }

    deinit {
        if source != 0 { MIDIEndpointDispose(source) }
        if client != 0 { MIDIClientDispose(client) }
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
        lock.lock()
        defer { lock.unlock() }

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
                return MIDIReceived(source, listPointer) == noErr
            }
        }

        guard sent else { throw MIDIControllerError.packetCreation }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
#endif
