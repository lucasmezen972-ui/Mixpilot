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
    private var operationGeneration: UInt64 = 0
    private var invalidPaths: Set<String> = []

    public private(set) var currentURL: URL?
    public private(set) var isPlaying = false
    public private(set) var totalDuration: TimeInterval = 0
    public private(set) var invalidFiles: [String] = []
    public private(set) var lastError: String?

    public override init() { super.init() }

    @discardableResult
    public func prepare(url: URL) throws -> EmergencyLibrarySummary {
        try prepare(urls: [url])
    }

    @discardableResult
    public func prepare(urls: [URL]) throws -> EmergencyLibrarySummary {
        stopImmediately()
        queue = []
        invalidFiles = []
        invalidPaths = []
        totalDuration = 0
        currentIndex = 0
        lastError = nil

        var seenPaths: Set<String> = []
        for url in urls {
            let normalized = url.standardizedFileURL
            guard seenPaths.insert(normalized.path).inserted else { continue }
            do {
                let probe = try makePreparedPlayer(url: normalized)
                guard probe.duration > 0 else {
                    appendInvalid(normalized)
                    continue
                }
                queue.append(normalized)
                totalDuration += probe.duration
            } catch {
                appendInvalid(normalized)
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

    @discardableResult
    public func play(fadeInDuration: TimeInterval = 1.2) -> Bool {
        guard let player else {
            isPlaying = false
            lastError = "Aucun fichier de secours n’est prêt."
            return false
        }
        operationGeneration &+= 1
        player.volume = 0
        guard player.play() else {
            if let currentURL { appendInvalid(currentURL) }
            isPlaying = false
            lastError = "Le fichier de secours n’a pas pu démarrer."
            return false
        }
        player.setVolume(1, fadeDuration: max(0, fadeInDuration))
        isPlaying = true
        lastError = nil
        return true
    }

    public func stop(fadeOutDuration: TimeInterval = 1.2) {
        operationGeneration &+= 1
        let generation = operationGeneration
        guard let player else {
            isPlaying = false
            return
        }
        let duration = max(0, fadeOutDuration)
        guard duration > 0 else {
            player.stop()
            isPlaying = false
            return
        }
        player.setVolume(0, fadeDuration: duration)
        Task { @MainActor [weak self, weak player] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self,
                  self.operationGeneration == generation,
                  let player,
                  self.player === player else { return }
            player.stop()
            self.isPlaying = false
        }
    }

    public func skip() {
        guard !queue.isEmpty else { return }
        operationGeneration &+= 1
        _ = advanceToPlayableTrack(fadeInDuration: 0.4)
    }

    public func clear() {
        stopImmediately()
        queue = []
        currentIndex = 0
        currentURL = nil
        totalDuration = 0
        invalidFiles = []
        invalidPaths = []
        lastError = nil
    }

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player, !self.queue.isEmpty else { return }
            self.operationGeneration &+= 1
            self.isPlaying = false
            if !flag {
                if let currentURL = self.currentURL { self.appendInvalid(currentURL) }
                self.lastError = "Le fichier de secours s’est interrompu avant sa fin."
            }
            _ = self.advanceToPlayableTrack(fadeInDuration: 0.35)
        }
    }

    nonisolated public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player, !self.queue.isEmpty else { return }
            self.operationGeneration &+= 1
            self.isPlaying = false
            if let currentURL = self.currentURL { self.appendInvalid(currentURL) }
            self.lastError = error?.localizedDescription ?? "Le fichier de secours ne peut plus être décodé."
            _ = self.advanceToPlayableTrack(fadeInDuration: 0.2)
        }
    }

    private func advanceToPlayableTrack(fadeInDuration: TimeInterval) -> Bool {
        guard !queue.isEmpty else { return false }

        let baseIndex = currentIndex
        player?.delegate = nil
        player?.stop()
        player = nil
        currentURL = nil
        isPlaying = false

        for offset in 1...queue.count {
            let candidateIndex = (baseIndex + offset) % queue.count
            let candidate = queue[candidateIndex].standardizedFileURL
            guard !invalidPaths.contains(candidate.path) else { continue }

            do {
                let preparedPlayer = try makePreparedPlayer(url: candidate)
                preparedPlayer.volume = 0
                guard preparedPlayer.play() else {
                    appendInvalid(candidate)
                    lastError = "Le fichier \(candidate.lastPathComponent) n’a pas pu démarrer."
                    continue
                }

                operationGeneration &+= 1
                preparedPlayer.setVolume(1, fadeDuration: max(0, fadeInDuration))
                player = preparedPlayer
                currentURL = candidate
                currentIndex = candidateIndex
                isPlaying = true
                lastError = nil
                return true
            } catch {
                appendInvalid(candidate)
                lastError = error.localizedDescription
            }
        }

        player = nil
        currentURL = nil
        isPlaying = false
        if lastError == nil { lastError = "Aucun fichier de secours n’est encore lisible." }
        return false
    }

    private func prepareCurrent(url: URL) throws {
        let normalized = url.standardizedFileURL
        let preparedPlayer = try makePreparedPlayer(url: normalized)
        player = preparedPlayer
        currentURL = normalized
        isPlaying = false
    }

    private func makePreparedPlayer(url: URL) throws -> AVAudioPlayer {
        let preparedPlayer = try AVAudioPlayer(contentsOf: url)
        preparedPlayer.delegate = self
        guard preparedPlayer.prepareToPlay() else {
            throw NSError(
                domain: "MixPilotEmergencyAudio",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Le fichier \(url.lastPathComponent) ne peut pas être préparé."]
            )
        }
        return preparedPlayer
    }

    private func appendInvalid(_ url: URL) {
        let normalized = url.standardizedFileURL
        guard invalidPaths.insert(normalized.path).inserted else { return }
        let name = normalized.lastPathComponent
        if !invalidFiles.contains(name) { invalidFiles.append(name) }
    }

    private func stopImmediately() {
        operationGeneration &+= 1
        player?.delegate = nil
        player?.stop()
        player = nil
        currentURL = nil
        isPlaying = false
    }
}
#endif