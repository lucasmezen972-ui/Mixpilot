#if os(macOS)
import AVFoundation
import Foundation

@MainActor
public final class EmergencyAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    public private(set) var currentURL: URL?
    public private(set) var isPlaying = false

    public override init() {
        super.init()
    }

    public func prepare(url: URL) throws {
        let preparedPlayer = try AVAudioPlayer(contentsOf: url)
        preparedPlayer.delegate = self
        preparedPlayer.prepareToPlay()
        player = preparedPlayer
        currentURL = url
        isPlaying = false
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

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
#endif
