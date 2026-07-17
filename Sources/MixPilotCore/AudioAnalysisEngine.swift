import Foundation

public struct MonoPCMBuffer: Sendable {
    public var samples: [Float]
    public var sampleRate: Double

    public init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = max(1, sampleRate)
    }

    public var duration: TimeInterval {
        Double(samples.count) / sampleRate
    }
}

public struct OnsetEvent: Codable, Hashable, Sendable {
    public var time: TimeInterval
    public var strength: Double

    public init(time: TimeInterval, strength: Double) {
        self.time = max(0, time)
        self.strength = max(0, strength)
    }
}

public struct BeatGridEstimate: Codable, Hashable, Sendable {
    public var bpm: Double
    public var beatPeriod: TimeInterval
    public var phase: TimeInterval
    public var confidence: Double
    public var beatTimes: [TimeInterval]

    public init(
        bpm: Double,
        beatPeriod: TimeInterval,
        phase: TimeInterval,
        confidence: Double,
        beatTimes: [TimeInterval]
    ) {
        self.bpm = max(0, bpm)
        self.beatPeriod = max(0, beatPeriod)
        self.phase = max(0, phase)
        self.confidence = confidence.clamped(to: 0...1)
        self.beatTimes = beatTimes
    }
}

public enum EnergySectionKind: String, Codable, Sendable {
    case quiet
    case medium
    case high
}

public struct EnergySection: Codable, Hashable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval
    public var normalizedEnergy: Double
    public var kind: EnergySectionKind

    public init(start: TimeInterval, end: TimeInterval, normalizedEnergy: Double, kind: EnergySectionKind) {
        self.start = max(0, start)
        self.end = max(start, end)
        self.normalizedEnergy = normalizedEnergy.clamped(to: 0...1)
        self.kind = kind
    }
}

public struct LocalAudioAnalysis: Codable, Hashable, Sendable {
    public var duration: TimeInterval
    public var integratedRMS: Double
    public var peak: Double
    public var onsets: [OnsetEvent]
    public var beatGrid: BeatGridEstimate?
    public var energySections: [EnergySection]

    public init(
        duration: TimeInterval,
        integratedRMS: Double,
        peak: Double,
        onsets: [OnsetEvent],
        beatGrid: BeatGridEstimate?,
        energySections: [EnergySection]
    ) {
        self.duration = max(0, duration)
        self.integratedRMS = max(0, integratedRMS)
        self.peak = max(0, peak)
        self.onsets = onsets
        self.beatGrid = beatGrid
        self.energySections = energySections
    }
}

public struct LocalAudioAnalyzer: Sendable {
    public var frameSize: Int
    public var hopSize: Int
    public var minimumBPM: Double
    public var maximumBPM: Double

    public init(
        frameSize: Int = 1_024,
        hopSize: Int = 512,
        minimumBPM: Double = 60,
        maximumBPM: Double = 200
    ) {
        self.frameSize = max(128, frameSize)
        self.hopSize = max(64, hopSize)
        self.minimumBPM = max(30, minimumBPM)
        self.maximumBPM = max(self.minimumBPM + 1, maximumBPM)
    }

    public func analyze(_ buffer: MonoPCMBuffer) -> LocalAudioAnalysis {
        guard !buffer.samples.isEmpty else {
            return LocalAudioAnalysis(
                duration: 0,
                integratedRMS: 0,
                peak: 0,
                onsets: [],
                beatGrid: nil,
                energySections: []
            )
        }

        let envelope = energyEnvelope(buffer)
        let onsets = detectOnsets(envelope: envelope, sampleRate: buffer.sampleRate)
        let beatGrid = estimateBeatGrid(
            envelope: envelope,
            onsets: onsets,
            duration: buffer.duration,
            sampleRate: buffer.sampleRate
        )
        let sections = makeEnergySections(
            envelope: envelope,
            duration: buffer.duration,
            sampleRate: buffer.sampleRate
        )

        var sumSquares = 0.0
        var peak = 0.0
        for sample in buffer.samples {
            let value = Double(sample)
            sumSquares += value * value
            peak = max(peak, abs(value))
        }

        return LocalAudioAnalysis(
            duration: buffer.duration,
            integratedRMS: sqrt(sumSquares / Double(buffer.samples.count)),
            peak: peak,
            onsets: onsets,
            beatGrid: beatGrid,
            energySections: sections
        )
    }

    public func detectOnsets(
        envelope: [Double],
        sampleRate: Double
    ) -> [OnsetEvent] {
        guard envelope.count >= 4 else { return [] }
        let hopDuration = Double(hopSize) / sampleRate
        let positiveDifferences = zip(envelope.dropFirst(), envelope).map { max(0, $0 - $1) }
        let medianDifference = median(positiveDifferences)
        let meanDifference = positiveDifferences.reduce(0, +) / Double(positiveDifferences.count)
        let threshold = max(0.000_001, medianDifference * 2.8, meanDifference * 1.45)
        let minimumSpacingFrames = max(1, Int(0.11 / hopDuration))

        var output: [OnsetEvent] = []
        var lastAcceptedIndex = -minimumSpacingFrames
        for index in 1..<(envelope.count - 1) {
            let difference = max(0, envelope[index] - envelope[index - 1])
            guard difference >= threshold,
                  difference >= max(0, envelope[index + 1] - envelope[index]),
                  index - lastAcceptedIndex >= minimumSpacingFrames else { continue }

            output.append(OnsetEvent(
                time: Double(index) * hopDuration,
                strength: difference / threshold
            ))
            lastAcceptedIndex = index
        }
        return output
    }

    public func estimateBeatGrid(
        envelope: [Double],
        onsets: [OnsetEvent],
        duration: TimeInterval,
        sampleRate: Double
    ) -> BeatGridEstimate? {
        guard envelope.count >= 16, duration >= 4 else { return nil }
        let hopDuration = Double(hopSize) / sampleRate
        let onsetEnvelope = onsetStrengthEnvelope(envelope)
        let minLag = max(1, Int((60 / maximumBPM) / hopDuration))
        let maxLag = min(onsetEnvelope.count / 2, Int((60 / minimumBPM) / hopDuration))
        guard maxLag > minLag else { return nil }

        var bestLag = 0
        var bestScore = 0.0
        var scores: [Double] = []
        scores.reserveCapacity(maxLag - minLag + 1)

        for lag in minLag...maxLag {
            var score = 0.0
            var normalizer = 0.0
            for index in lag..<onsetEnvelope.count {
                let left = onsetEnvelope[index]
                let right = onsetEnvelope[index - lag]
                score += left * right
                normalizer += (left * left) + (right * right)
            }
            let normalized = normalizer > 0 ? (2 * score / normalizer) : 0
            scores.append(normalized)
            if normalized > bestScore {
                bestScore = normalized
                bestLag = lag
            }
        }
        guard bestLag > 0, bestScore > 0.05 else { return nil }

        let rawPeriod = Double(bestLag) * hopDuration
        let rawBPM = 60 / rawPeriod
        let bpm = normalizedTempo(rawBPM)
        let beatPeriod = 60 / bpm
        let phase = bestPhase(
            onsets: onsets,
            period: beatPeriod,
            duration: duration
        )

        var beatTimes: [TimeInterval] = []
        var time = phase
        while time <= duration {
            beatTimes.append(time)
            time += beatPeriod
        }

        let contrast: Double
        if scores.count >= 2 {
            let sorted = scores.sorted(by: >)
            contrast = max(0, sorted[0] - sorted[1])
        } else {
            contrast = bestScore
        }
        let onsetCoverage = min(1, Double(onsets.count) / max(8, duration / beatPeriod * 0.45))
        let confidence = min(1, (bestScore * 0.58) + (contrast * 1.8) + (onsetCoverage * 0.28))

        return BeatGridEstimate(
            bpm: bpm,
            beatPeriod: beatPeriod,
            phase: phase,
            confidence: confidence,
            beatTimes: beatTimes
        )
    }

    private func energyEnvelope(_ buffer: MonoPCMBuffer) -> [Double] {
        let samples = buffer.samples
        guard samples.count >= frameSize else {
            let energy = samples.reduce(0.0) { $0 + Double($1 * $1) }
            return [sqrt(energy / Double(max(1, samples.count)))]
        }

        var output: [Double] = []
        var start = 0
        while start + frameSize <= samples.count {
            var sum = 0.0
            for index in start..<(start + frameSize) {
                let value = Double(samples[index])
                sum += value * value
            }
            output.append(sqrt(sum / Double(frameSize)))
            start += hopSize
        }
        return smooth(output, radius: 1)
    }

    private func onsetStrengthEnvelope(_ envelope: [Double]) -> [Double] {
        guard envelope.count > 1 else { return envelope }
        var output = Array(repeating: 0.0, count: envelope.count)
        for index in 1..<envelope.count {
            output[index] = max(0, envelope[index] - envelope[index - 1])
        }
        let maximum = output.max() ?? 0
        guard maximum > 0 else { return output }
        return output.map { $0 / maximum }
    }

    private func bestPhase(
        onsets: [OnsetEvent],
        period: TimeInterval,
        duration: TimeInterval
    ) -> TimeInterval {
        guard !onsets.isEmpty, period > 0 else { return 0 }
        let candidates = onsets.prefix(64).map { $0.time.truncatingRemainder(dividingBy: period) }
        var bestCandidate = candidates.first ?? 0
        var bestScore = -Double.infinity

        for candidate in candidates {
            var score = 0.0
            for onset in onsets {
                let relative = (onset.time - candidate) / period
                let distance = abs(relative - relative.rounded())
                let circularDistance = min(distance, 1 - distance)
                score += onset.strength * exp(-pow(circularDistance / 0.12, 2))
            }
            if score > bestScore {
                bestScore = score
                bestCandidate = candidate
            }
        }
        return min(max(0, bestCandidate), min(period, duration))
    }

    private func makeEnergySections(
        envelope: [Double],
        duration: TimeInterval,
        sampleRate: Double
    ) -> [EnergySection] {
        guard !envelope.isEmpty else { return [] }
        let hopDuration = Double(hopSize) / sampleRate
        let sectionDuration = 8.0
        let framesPerSection = max(1, Int(sectionDuration / hopDuration))
        let maximum = envelope.max() ?? 1
        let safeMaximum = max(maximum, 0.000_001)
        var sections: [EnergySection] = []

        var index = 0
        while index < envelope.count {
            let endIndex = min(envelope.count, index + framesPerSection)
            let slice = envelope[index..<endIndex]
            let average = slice.reduce(0, +) / Double(slice.count)
            let normalized = average / safeMaximum
            let kind: EnergySectionKind
            if normalized < 0.28 {
                kind = .quiet
            } else if normalized < 0.65 {
                kind = .medium
            } else {
                kind = .high
            }
            sections.append(EnergySection(
                start: Double(index) * hopDuration,
                end: min(duration, Double(endIndex) * hopDuration),
                normalizedEnergy: normalized,
                kind: kind
            ))
            index = endIndex
        }
        return mergeAdjacentSections(sections)
    }

    private func mergeAdjacentSections(_ sections: [EnergySection]) -> [EnergySection] {
        var output: [EnergySection] = []
        for section in sections {
            if var last = output.last, last.kind == section.kind {
                output.removeLast()
                let combinedDuration = max(0.000_001, section.end - last.start)
                let leftDuration = last.end - last.start
                let rightDuration = section.end - section.start
                last.normalizedEnergy = (
                    (last.normalizedEnergy * leftDuration) +
                    (section.normalizedEnergy * rightDuration)
                ) / combinedDuration
                last.end = section.end
                output.append(last)
            } else {
                output.append(section)
            }
        }
        return output
    }

    private func normalizedTempo(_ rawBPM: Double) -> Double {
        var bpm = rawBPM
        while bpm < minimumBPM { bpm *= 2 }
        while bpm > maximumBPM { bpm /= 2 }
        return bpm
    }

    private func smooth(_ values: [Double], radius: Int) -> [Double] {
        guard radius > 0, values.count > 2 else { return values }
        return values.indices.map { index in
            let lower = max(0, index - radius)
            let upper = min(values.count - 1, index + radius)
            let slice = values[lower...upper]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
