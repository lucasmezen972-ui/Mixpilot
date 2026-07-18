import Testing
@testable import MixPilotCore

@Suite("DJ playback timecode probe")
struct DJPlaybackProbeTests {
    @Test("Moving deck timecode is detected")
    func detectsMovement() {
        let result = DJPlaybackTimecodeProbe().compare(
            firstVisibleText: ["Deck A", "01:12.10", "03:40"],
            secondVisibleText: ["Deck A", "01:12.82", "03:40"]
        )

        #expect(result.motion == .moving)
        #expect(result.comparedTimecodeCount == 2)
        #expect(result.largestDelta > 0.7)
    }

    @Test("Stable timecodes remain stable")
    func detectsStability() {
        let result = DJPlaybackTimecodeProbe().compare(
            firstVisibleText: ["00:00", "03:40"],
            secondVisibleText: ["00:00", "03:40"]
        )

        #expect(result.motion == .stable)
        #expect(result.comparedTimecodeCount == 2)
    }

    @Test("No timecode is reported as unavailable")
    func unavailableWithoutTimecode() {
        let result = DJPlaybackTimecodeProbe().compare(
            firstVisibleText: ["Spotify", "Water", "Tyla"],
            secondVisibleText: ["Spotify", "Water", "Tyla"]
        )

        #expect(result.motion == .unavailable)
        #expect(result.comparedTimecodeCount == 0)
    }

    @Test("Playback actions expose their expected state and deck")
    func playbackActionMetadata() {
        #expect(DJControlAction.playA.expectedPlaybackState == true)
        #expect(DJControlAction.pauseB.expectedPlaybackState == false)
        #expect(DJControlAction.playA.targetDeck == .a)
        #expect(DJControlAction.pauseB.targetDeck == .b)
        #expect(DJControlAction.cueA.expectedPlaybackState == nil)
    }
}
