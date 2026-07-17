import Foundation
import Testing
@testable import MixPilotCore

struct CloudObservabilityTests {
    @Test func telemetryRemovesSensitivePayloadFields() {
        let event = MixPilotTelemetryEvent(
            category: "rekordbox",
            name: "validation.completed",
            payload: [
                "track_title": "Secret Song",
                "artist": "Secret Artist",
                "file_path": "/Users/lucas/Music/file.mp3",
                "command": "PlayPause",
                "latency_ms": "42"
            ]
        )

        #expect(event.payload["track_title"] == nil)
        #expect(event.payload["artist"] == nil)
        #expect(event.payload["file_path"] == nil)
        #expect(event.payload["command"] == "PlayPause")
        #expect(event.payload["latency_ms"] == "42")
    }

    @Test func offlineQueueIsIdempotentAndPersistent() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MixPilotTelemetryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("queue.json")
        let event = MixPilotTelemetryEvent(category: "app", name: "started")

        let queue = MixPilotTelemetryQueue(fileURL: url)
        try await queue.enqueue(event)
        try await queue.enqueue(event)
        #expect(await queue.count == 1)

        let reloaded = MixPilotTelemetryQueue(fileURL: url)
        #expect(await reloaded.count == 1)
        try await reloaded.remove(clientEventIDs: [event.clientEventID])
        #expect(await reloaded.count == 0)
    }
}
