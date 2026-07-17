#if os(macOS)
import Testing
@testable import MixPilotMIDI

@Test("MixPilot publishes a visible CoreMIDI source and destination")
func publishesControllerPair() throws {
    let controller = try CoreMIDIController()
    let diagnostic = try controller.requirePublishedControllerPair()

    #expect(diagnostic.sourcePublished)
    #expect(diagnostic.destinationPublished)
    #expect(diagnostic.visibleSources.contains { endpoint in
        endpoint.name == CoreMIDIController.virtualPortName ||
            endpoint.displayName == CoreMIDIController.virtualPortName
    })
    #expect(diagnostic.visibleDestinations.contains { endpoint in
        endpoint.name == CoreMIDIController.virtualOutputPortName ||
            endpoint.displayName == CoreMIDIController.virtualOutputPortName
    })
}

@Test("MixPilot virtual controller can emit MIDI after publication")
func emitsMIDIAfterPublication() throws {
    let controller = try CoreMIDIController()
    _ = try controller.requirePublishedControllerPair()

    try controller.sendNote(channel: 0, note: 60, velocity: 100)
    try controller.sendControlChangeRaw(channel: 0, controller: 11, value: 64)
}
#endif
