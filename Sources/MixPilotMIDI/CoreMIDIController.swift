#if os(macOS)
import CoreMIDI
import Foundation
import MixPilotCore

public enum MIDIControllerError: Error, LocalizedError {
    case clientCreation(OSStatus)
    case sourceCreation(OSStatus)
    case packetCreation

    public var errorDescription: String? {
        switch self {
        case .clientCreation(let status): "Impossible de créer le client CoreMIDI (\(status))."
        case .sourceCreation(let status): "Impossible de créer le port MIDI virtuel (\(status))."
        case .packetCreation: "Impossible de construire le paquet MIDI."
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
        try send([0xB0 | (channel & 0x0F), controller, normalized])
    }

    public func sendNote(channel: UInt8 = 0, note: UInt8, velocity: UInt8 = 127) throws {
        try send([0x90 | (channel & 0x0F), note, velocity])
        try send([0x80 | (channel & 0x0F), note, 0])
    }

    private func send(_ bytes: [UInt8]) throws {
        lock.lock()
        defer { lock.unlock() }

        var packetList = MIDIPacketList()
        let sent = withUnsafeMutablePointer(to: &packetList) { listPointer -> Bool in
            var packetPointer = MIDIPacketListInit(listPointer)
            return bytes.withUnsafeBufferPointer { bytePointer in
                guard let baseAddress = bytePointer.baseAddress else { return false }
                guard let addedPacket = MIDIPacketListAdd(
                    listPointer,
                    MemoryLayout<MIDIPacketList>.size,
                    packetPointer,
                    0,
                    bytes.count,
                    baseAddress
                ) else { return false }
                packetPointer = addedPacket
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
