import Foundation

public struct TransitionFrame: Hashable, Sendable {
    public var index: Int
    public var elapsed: TimeInterval
    public var beat: Double
    public var values: [SeratoAction: Double]

    public init(index: Int, elapsed: TimeInterval, beat: Double, values: [SeratoAction: Double]) {
        self.index = index
        self.elapsed = elapsed
        self.beat = beat
        self.values = values
    }
}

public struct TransitionExecutionSummary: Hashable, Sendable {
    public var frameCount: Int
    public var duration: TimeInterval
    public var outgoingDeck: DeckID
    public var incomingDeck: DeckID
    public var completed: Bool

    public init(
        frameCount: Int,
        duration: TimeInterval,
        outgoingDeck: DeckID,
        incomingDeck: DeckID,
        completed: Bool
    ) {
        self.frameCount = frameCount
        self.duration = duration
        self.outgoingDeck = outgoingDeck
        self.incomingDeck = incomingDeck
        self.completed = completed
    }
}

public struct TransitionFrameGenerator: Sendable {
    public init() {}

    public func frames(
        for plan: TransitionPlan,
        outgoingDeck: DeckID,
        framesPerSecond: Int = 30
    ) -> [TransitionFrame] {
        let incomingDeck = outgoingDeck.opposite
        let totalBeats = Double(max(1, plan.bars * 4))
        let safeBPM = max(40, plan.targetBPM)
        let duration = totalBeats * 60.0 / safeBPM
        let frameRate = max(1, framesPerSecond)
        let frameCount = max(2, Int((duration * Double(frameRate)).rounded(.up)) + 1)

        return (0..<frameCount).map { index in
            let progress = Double(index) / Double(frameCount - 1)
            let elapsed = duration * progress
            let beat = totalBeats * progress
            var values: [SeratoAction: Double] = [:]

            for lane in plan.lanes {
                let rawValue = interpolatedValue(in: lane, atBeat: beat)
                guard let action = action(
                    for: lane.target,
                    outgoingDeck: outgoingDeck,
                    incomingDeck: incomingDeck
                ) else { continue }

                if lane.target == .crossfader && outgoingDeck == .b {
                    values[action] = 1 - rawValue
                } else {
                    values[action] = rawValue
                }
            }

            return TransitionFrame(index: index, elapsed: elapsed, beat: beat, values: values)
        }
    }

    public func interpolatedValue(in lane: AutomationLane, atBeat beat: Double) -> Double {
        guard let first = lane.points.first else { return 0 }
        guard lane.points.count > 1 else { return first.value }
        if beat <= first.beat { return first.value }
        guard let last = lane.points.last else { return first.value }
        if beat >= last.beat { return last.value }

        for pair in zip(lane.points, lane.points.dropFirst()) {
            let left = pair.0
            let right = pair.1
            guard beat >= left.beat && beat <= right.beat else { continue }
            let span = max(0.000_001, right.beat - left.beat)
            let localProgress = (beat - left.beat) / span
            return left.value + ((right.value - left.value) * localProgress)
        }
        return last.value
    }

    private func action(
        for target: AutomationTarget,
        outgoingDeck: DeckID,
        incomingDeck: DeckID
    ) -> SeratoAction? {
        switch target {
        case .crossfader:
            return .crossfader
        case .outgoingVolume:
            return .volume(deck: outgoingDeck)
        case .incomingVolume:
            return .volume(deck: incomingDeck)
        case .outgoingLowEQ:
            return .lowEQ(deck: outgoingDeck)
        case .incomingLowEQ:
            return .lowEQ(deck: incomingDeck)
        case .outgoingFilter:
            return .filter(deck: outgoingDeck)
        case .echoAmount:
            return .echoAmount(deck: outgoingDeck)
        }
    }
}

public actor TransitionExecutor {
    private let sender: any SeratoCommandSending
    private let frameGenerator: TransitionFrameGenerator

    public init(
        sender: any SeratoCommandSending,
        frameGenerator: TransitionFrameGenerator = TransitionFrameGenerator()
    ) {
        self.sender = sender
        self.frameGenerator = frameGenerator
    }

    public func execute(
        plan: TransitionPlan,
        outgoingDeck: DeckID,
        framesPerSecond: Int = 30,
        speedMultiplier: Double = 1
    ) async throws -> TransitionExecutionSummary {
        let incomingDeck = outgoingDeck.opposite
        let frames = frameGenerator.frames(
            for: plan,
            outgoingDeck: outgoingDeck,
            framesPerSecond: framesPerSecond
        )
        let duration = frames.last?.elapsed ?? 0

        try await sender.trigger(.sync(deck: incomingDeck))
        try await sender.trigger(.play(deck: incomingDeck))

        var previousElapsed: TimeInterval = 0
        for frame in frames {
            try Task.checkCancellation()
            let delay = max(0, frame.elapsed - previousElapsed) / max(0.01, speedMultiplier)
            if delay > 0 {
                try await Task.sleep(for: .seconds(delay))
            }
            for action in frame.values.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                if let value = frame.values[action] {
                    try await sender.set(action, value: value)
                }
            }
            previousElapsed = frame.elapsed
        }

        try await sender.trigger(.pause(deck: outgoingDeck))
        try await sender.set(.volume(deck: incomingDeck), value: 1)
        try await sender.set(.lowEQ(deck: incomingDeck), value: 1)

        return TransitionExecutionSummary(
            frameCount: frames.count,
            duration: duration,
            outgoingDeck: outgoingDeck,
            incomingDeck: incomingDeck,
            completed: true
        )
    }
}
