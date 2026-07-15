import Foundation

public struct RuntimeStressReport: Codable, Hashable, Sendable {
    public var trackCount: Int
    public var transitionCount: Int
    public var generatedFrameCount: Int
    public var generatedControlValueCount: Int
    public var invalidValueCount: Int
    public var missingCrossfaderTransitionCount: Int
    public var maximumControlJump: Double
    public var finalActiveDeck: DeckID

    public init(
        trackCount: Int,
        transitionCount: Int,
        generatedFrameCount: Int,
        generatedControlValueCount: Int,
        invalidValueCount: Int,
        missingCrossfaderTransitionCount: Int,
        maximumControlJump: Double,
        finalActiveDeck: DeckID
    ) {
        self.trackCount = trackCount
        self.transitionCount = transitionCount
        self.generatedFrameCount = generatedFrameCount
        self.generatedControlValueCount = generatedControlValueCount
        self.invalidValueCount = invalidValueCount
        self.missingCrossfaderTransitionCount = missingCrossfaderTransitionCount
        self.maximumControlJump = max(0, maximumControlJump)
        self.finalActiveDeck = finalActiveDeck
    }

    public var succeeded: Bool {
        invalidValueCount == 0 &&
            missingCrossfaderTransitionCount == 0 &&
            transitionCount == max(0, trackCount - 1) &&
            generatedFrameCount > 0
    }
}

public struct RuntimeStressSimulator: Sendable {
    private let frameGenerator: TransitionFrameGenerator

    public init(frameGenerator: TransitionFrameGenerator = TransitionFrameGenerator()) {
        self.frameGenerator = frameGenerator
    }

    public func run(trackCount: Int = 50, framesPerSecond: Int = 30) -> RuntimeStressReport {
        let tracks = SetSimulator().makeTracks(count: max(2, trackCount))
        let plans = TransitionPlanner().planSet(tracks)
        var activeDeck: DeckID = .a
        var frameCount = 0
        var valueCount = 0
        var invalidValues = 0
        var missingCrossfader = 0
        var maximumJump = 0.0
        var previousValues: [SeratoAction: Double] = [:]

        for plan in plans {
            let frames = frameGenerator.frames(
                for: plan,
                outgoingDeck: activeDeck,
                framesPerSecond: framesPerSecond
            )
            frameCount += frames.count
            if !frames.contains(where: { $0.values[.crossfader] != nil }) {
                missingCrossfader += 1
            }

            for frame in frames {
                for (action, value) in frame.values {
                    valueCount += 1
                    if !value.isFinite || value < 0 || value > 1 {
                        invalidValues += 1
                    }
                    if let previous = previousValues[action] {
                        maximumJump = max(maximumJump, abs(value - previous))
                    }
                    previousValues[action] = value
                }
            }
            activeDeck = activeDeck.opposite
        }

        return RuntimeStressReport(
            trackCount: tracks.count,
            transitionCount: plans.count,
            generatedFrameCount: frameCount,
            generatedControlValueCount: valueCount,
            invalidValueCount: invalidValues,
            missingCrossfaderTransitionCount: missingCrossfader,
            maximumControlJump: maximumJump,
            finalActiveDeck: activeDeck
        )
    }
}
