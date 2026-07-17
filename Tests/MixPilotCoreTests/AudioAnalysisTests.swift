import Foundation
import Testing
@testable import MixPilotCore

@Test("Synthetic click track estimates BPM close to 120")
func syntheticClickTrackBPM() {
    let sampleRate = 8_000.0
    let duration = 20.0
    let bpm = 120.0
    let beatPeriod = 60.0 / bpm
    let sampleCount = Int(sampleRate * duration)
    var samples = Array(repeating: Float.zero, count: sampleCount)

    var beatTime = 0.25
    while beatTime < duration {
        let start = Int(beatTime * sampleRate)
        for offset in 0..<min(80, sampleCount - start) {
            let decay = exp(-Double(offset) / 14)
            samples[start + offset] += Float(decay * 0.9)
        }
        beatTime += beatPeriod
    }

    let analyzer = LocalAudioAnalyzer(frameSize: 256, hopSize: 64, minimumBPM: 70, maximumBPM: 160)
    let result = analyzer.analyze(MonoPCMBuffer(samples: samples, sampleRate: sampleRate))

    let estimated = try? #require(result.beatGrid)
    #expect(estimated != nil)
    if let estimated {
        #expect(abs(estimated.bpm - 120) < 2.5)
        #expect(estimated.beatTimes.count > 30)
        #expect(estimated.confidence > 0.35)
    }
}

@Test("Energy analysis separates quiet and strong regions")
func energySectionsSeparateDynamics() {
    let sampleRate = 4_000.0
    let quiet = Array(repeating: Float(0.01), count: Int(sampleRate * 10))
    let loud = Array(repeating: Float(0.75), count: Int(sampleRate * 10))
    let analyzer = LocalAudioAnalyzer(frameSize: 256, hopSize: 128)
    let result = analyzer.analyze(MonoPCMBuffer(samples: quiet + loud, sampleRate: sampleRate))

    #expect(result.energySections.count >= 2)
    #expect(result.energySections.first?.normalizedEnergy ?? 1 < 0.2)
    #expect(result.energySections.last?.kind == .high)
}

@Test("Empty PCM input returns a safe empty analysis")
func emptyPCMAnalysis() {
    let result = LocalAudioAnalyzer().analyze(MonoPCMBuffer(samples: [], sampleRate: 44_100))
    #expect(result.duration == 0)
    #expect(result.beatGrid == nil)
    #expect(result.onsets.isEmpty)
}
