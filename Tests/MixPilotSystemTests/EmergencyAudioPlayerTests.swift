#if os(macOS)
@preconcurrency import AVFoundation
import Foundation
import Testing
@testable import MixPilotSystem

@MainActor
@Test("Emergency player reports failure before preparation")
func emergencyPlayerRequiresPreparation() {
    let player = EmergencyAudioPlayer()

    #expect(!player.play(fadeInDuration: 0))
    #expect(!player.isPlaying)
    #expect(player.lastError != nil)
}

@MainActor
@Test("Emergency library rejects invalid files and deduplicates valid files")
func emergencyLibraryFiltersAndDeduplicates() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let valid = directory.appendingPathComponent("valid.caf")
    let invalid = directory.appendingPathComponent("invalid.caf")
    try makeAudioFile(at: valid, duration: 0.2)
    try Data("not audio".utf8).write(to: invalid)

    let player = EmergencyAudioPlayer()
    let summary = try player.prepare(urls: [invalid, valid, valid])

    #expect(summary.fileCount == 1)
    #expect(summary.totalDuration > 0)
    #expect(summary.invalidFiles == ["invalid.caf"])
    #expect(player.currentURL == valid.standardizedFileURL)
}

@MainActor
@Test("Clear resets emergency playback state")
func clearResetsEmergencyState() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let valid = directory.appendingPathComponent("valid.caf")
    try makeAudioFile(at: valid, duration: 0.2)

    let player = EmergencyAudioPlayer()
    _ = try player.prepare(url: valid)
    player.clear()

    #expect(player.currentURL == nil)
    #expect(player.totalDuration == 0)
    #expect(player.invalidFiles.isEmpty)
    #expect(!player.isPlaying)
    #expect(player.lastError == nil)
}

@MainActor
@Test("A stale fade-out cannot stop a newer playback generation")
func staleFadeDoesNotStopNewPlayback() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let valid = directory.appendingPathComponent("long.caf")
    try makeAudioFile(at: valid, duration: 1)

    let player = EmergencyAudioPlayer()
    _ = try player.prepare(url: valid)
    #expect(player.play(fadeInDuration: 0))
    player.stop(fadeOutDuration: 0.05)
    #expect(player.play(fadeInDuration: 0))

    try await Task.sleep(for: .milliseconds(100))

    #expect(player.isPlaying)
    player.stop(fadeOutDuration: 0)
}

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MixPilotEmergencyAudioTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func makeAudioFile(at url: URL, duration: TimeInterval) throws {
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
        throw CocoaError(.fileWriteUnknown)
    }
    let frameCount = AVAudioFrameCount(max(1, duration * format.sampleRate))
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        throw CocoaError(.fileWriteUnknown)
    }
    buffer.frameLength = frameCount
    if let channels = buffer.floatChannelData {
        channels[0].initialize(repeating: 0, count: Int(frameCount))
    }
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
}
#endif
