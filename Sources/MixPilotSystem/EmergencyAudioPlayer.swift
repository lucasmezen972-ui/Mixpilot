#if os(macOS)
@preconcurrency import AVFoundation
import Foundation

public struct EmergencyLibrarySummary: Hashable, Sendable {
    public var fileCount: Int
    public var totalDuration: TimeInterval
    public var invalidFiles: [String]

    public init(fileCount: Int, totalDuration: TimeInterval, invalidFiles: [String]) {
        self.fileCount = fileCount
        self.totalDuration = totalDuration
        self.invalidFiles = invalidFiles
    }
}

@MainActor
public final class EmergencyAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var queue: [URL] = []
    private var currentIndex = 0

    public private(set) var currentURL: URL?
    public private(set) var isPlaying = false
    public private(set) var totalDuration: TimeInterval = 0
    public private(set) var invalidFiles: [String] = []

    public override init() {
        super.init()
    }

    @discardableResult
    public func prepare(url: URL) throws -> EmergencyLibrarySummary {
        try prepare(urls: [url])
    }

    @discardableResult
    public func prepare(urls: [URL]) throws -> EmergencyLibrarySummary {
        stopImmediately()
        queue = []
        invalidFiles = []
        totalDuration = 0
        currentIndex = 0

        for url in urls {
            do {
                let probe = try AVAudioPlayer(contentsOf: url)
                guard probe.duration > 0 else {
                    invalidFiles.append(url.lastPathComponent)
                    continue
                }
                queue.append(url)
                totalDuration += probe.duration
            } catch {
                invalidFiles.append(url.lastPathComponent)
            }
        }

        guard let first = queue.first else {
            throw NSError(
                domain: "MixPilotEmergencyAudio",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Aucun fichier audio local valide n'a été sélectionné."]
            )
        }
        try prepareCurrent(url: first)
        return EmergencyLibrarySummary(
            fileCount: queue.count,
            totalDuration: totalDuration,
            invalidFiles: invalidFiles
        )
    }

    public func play(fadeInDuration: TimeInterval = 1.2) {
        guard let player else { return }
        player.volume = 0
        player.play()
        player.setVolume(1, fadeDuration: fadeInDuration)
        isPlaying = true
    }

    public func stop(fadeOutDuration: TimeInterval = 1.2) {
        guard let player else { return }
        player.setVolume(0, fadeDuration: fadeOutDuration)
        let playerToStop = player
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(fadeOutDuration))
            playerToStop.stop()
            self.isPlaying = false
        }
    }

    public func skip() {
        guard !queue.isEmpty else { return }
        player?.stop()
        currentIndex = (currentIndex + 1) % queue.count
        do {
            try prepareCurrent(url: queue[currentIndex])
            play(fadeInDuration: 0.4)
        } catch {
            isPlaying = false
        }
    }

    public func clear() {
        stopImmediately()
        queue = []
        currentIndex = 0
        currentURL = nil
        totalDuration = 0
        invalidFiles = []
    }

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, !self.queue.isEmpty else { return }
            self.currentIndex = (self.currentIndex + 1) % self.queue.count
            do {
                try self.prepareCurrent(url: self.queue[self.currentIndex])
                self.play(fadeInDuration: 0.35)
            } catch {
                self.isPlaying = false
            }
        }
    }

    private func prepareCurrent(url: URL) throws {
        let preparedPlayer = try AVAudioPlayer(contentsOf: url)
        preparedPlayer.delegate = self
        preparedPlayer.prepareToPlay()
        player = preparedPlayer
        currentURL = url
        isPlaying = false
    }

    private func stopImmediately() {
        player?.stop()
        player = nil
        isPlaying = false
    }
}
#endif
