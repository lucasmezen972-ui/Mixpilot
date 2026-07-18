import Foundation

public enum DJPlaybackMotion: String, Codable, Hashable, Sendable {
    case moving
    case stable
    case unavailable
}

public struct DJPlaybackProbeResult: Codable, Hashable, Sendable {
    public var motion: DJPlaybackMotion
    public var comparedTimecodeCount: Int
    public var largestDelta: TimeInterval

    public init(
        motion: DJPlaybackMotion,
        comparedTimecodeCount: Int,
        largestDelta: TimeInterval
    ) {
        self.motion = motion
        self.comparedTimecodeCount = max(0, comparedTimecodeCount)
        self.largestDelta = max(0, largestDelta)
    }
}

public struct DJPlaybackTimecodeProbe: Sendable {
    public init() {}

    public func compare(
        firstVisibleText: [String],
        secondVisibleText: [String]
    ) -> DJPlaybackProbeResult {
        let first = extractTimecodes(from: firstVisibleText)
        let second = extractTimecodes(from: secondVisibleText)
        let count = min(first.count, second.count)
        guard count > 0 else {
            return DJPlaybackProbeResult(
                motion: .unavailable,
                comparedTimecodeCount: 0,
                largestDelta: 0
            )
        }

        let deltas = (0..<count).map { index in
            abs(second[index] - first[index])
        }
        let largest = deltas.max() ?? 0
        let moving = deltas.contains { delta in
            delta >= 0.12 && delta <= 3.5
        }

        return DJPlaybackProbeResult(
            motion: moving ? .moving : .stable,
            comparedTimecodeCount: count,
            largestDelta: largest
        )
    }

    public func extractTimecodes(from visibleText: [String]) -> [TimeInterval] {
        visibleText.flatMap(extractTimecodes(from:))
    }

    private func extractTimecodes(from value: String) -> [TimeInterval] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?<!\d)(?:(\d{1,2}):)?(\d{1,2}):(\d{2})(?:[\.,](\d{1,3}))?(?!\d)"#
        ) else { return [] }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            func number(_ capture: Int) -> Double? {
                let range = match.range(at: capture)
                guard range.location != NSNotFound,
                      let swiftRange = Range(range, in: value) else { return nil }
                return Double(value[swiftRange])
            }

            guard let minutesOrHours = number(2),
                  let seconds = number(3),
                  seconds < 60 else { return nil }
            let hours = number(1) ?? 0
            let fractionText: Double
            if let fraction = number(4) {
                let digits = match.range(at: 4).length
                fractionText = fraction / pow(10, Double(max(1, digits)))
            } else {
                fractionText = 0
            }
            return (hours * 3_600) + (minutesOrHours * 60) + seconds + fractionText
        }
    }
}

public extension DJControlAction {
    var expectedPlaybackState: Bool? {
        switch self {
        case .playA, .playB: true
        case .pauseA, .pauseB: false
        default: nil
        }
    }

    var targetDeck: DeckID? {
        switch self {
        case .playA, .pauseA, .cueA, .syncA, .loadA, .volumeA,
             .lowEQA, .midEQA, .highEQA, .filterA, .pitchA,
             .echoA, .echoAmountA, .loopA, .exitLoopA:
            .a
        case .playB, .pauseB, .cueB, .syncB, .loadB, .volumeB,
             .lowEQB, .midEQB, .highEQB, .filterB, .pitchB,
             .echoB, .echoAmountB, .loopB, .exitLoopB:
            .b
        case .browserUp, .browserDown, .browserFocus, .crossfader:
            nil
        }
    }
}
