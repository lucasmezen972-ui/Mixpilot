import Foundation

public struct TransitionFrame: Hashable, Sendable {
    public var index: Int
    public var elapsed: TimeInterval
    public var beat: Double
    public var values: [DJControlAction: Double]

    public init(index: Int, elapsed: TimeInterval, beat: Double, values: [DJControlAction: Double]) {
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
            var values: [DJControlAction: Double] = [:]

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
    ) -> DJControlAction? {
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

public protocol DJTransitionCommandSending: DJCommandSending {
    func trigger(
        _ action: DJControlAction,
        requireVerification: Bool
    ) async throws
}

public actor TransitionExecutor {
    private let sender: any DJCommandSending
    private let frameGenerator: TransitionFrameGenerator

    public init(
        sender: any DJCommandSending,
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
        let speed = max(0.01, speedMultiplier)
        let clock = ContinuousClock()

        try await trigger(.sync(deck: incomingDeck), requireVerification: false)
        try await trigger(.play(deck: incomingDeck), requireVerification: true)

        let startedAt = clock.now
        let quantizationStep = 1.0 / 127.0
        var lastSentValues: [DJControlAction: Double] = [:]
        var processedFrames = 0

        for (position, frame) in frames.enumerated() {
            try Task.checkCancellation()

            let target = startedAt.advanced(by: .seconds(frame.elapsed / speed))
            if position + 1 < frames.count {
                let nextFrame = frames[position + 1]
                let nextTarget = startedAt.advanced(by: .seconds(nextFrame.elapsed / speed))
                if clock.now >= nextTarget {
                    continue
                }
            }
            if clock.now < target {
                try await clock.sleep(until: target)
            }

            let isFinalFrame = position == frames.count - 1
            for action in frame.values.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let value = frame.values[action] else { continue }
                if !isFinalFrame,
                   let previous = lastSentValues[action],
                   abs(previous - value) < quantizationStep {
                    continue
                }
                try await sender.set(action, value: value)
                lastSentValues[action] = value
            }
            processedFrames += 1
        }

        try await trigger(.pause(deck: outgoingDeck), requireVerification: true)
        try await sender.set(.volume(deck: incomingDeck), value: 1)
        try await sender.set(.lowEQ(deck: incomingDeck), value: 1)

        return TransitionExecutionSummary(
            frameCount: processedFrames,
            duration: duration,
            outgoingDeck: outgoingDeck,
            incomingDeck: incomingDeck,
            completed: true
        )
    }

    private func trigger(
        _ action: DJControlAction,
        requireVerification: Bool
    ) async throws {
        if let controlledSender = sender as? any DJTransitionCommandSending {
            try await controlledSender.trigger(
                action,
                requireVerification: requireVerification
            )
        } else {
            try await sender.trigger(action)
        }
    }
}
