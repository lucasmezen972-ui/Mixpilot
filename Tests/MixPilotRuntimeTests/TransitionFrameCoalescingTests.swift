#if os(macOS)
import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotRuntime

private actor FrameProbe: DJTransitionCommandSending {
    private var values: [DJControlAction: [Double]] = [:]

    func trigger(_ action: DJControlAction) async throws {}
    func trigger(_ action: DJControlAction, requireVerification: Bool) async throws {}

    func set(_ action: DJControlAction, value: Double) async throws {
        values[action, default: []].append(value)
    }

    func recorded(_ action: DJControlAction) -> [Double] {
        values[action] ?? []
    }
}

@Test("Transition frames are coalesced and keep the final value")
func transitionFramesAreCoalesced() async throws {
    let probe = FrameProbe()
    let executor = TransitionExecutor(sender: probe)
    let plan = TransitionPlan(
        outgoingTrackID: UUID(),
        incomingTrackID: UUID(),
        kind: .smoothBlend,
        bars: 4,
        targetBPM: 120,
        confidence: 100,
        reasons: [],
        lanes: [
            AutomationLane(
                target: .crossfader,
                points: [
                    AutomationPoint(beat: 0, value: 0),
                    AutomationPoint(beat: 16, value: 1),
                ]
            )
        ]
    )

    let summary = try await executor.execute(
        plan: plan,
        outgoingDeck: .a,
        framesPerSecond: 120,
        speedMultiplier: 1_000
    )

    let crossfader = await probe.recorded(.crossfader)
    #expect(summary.completed)
    #expect(!crossfader.isEmpty)
    #expect(crossfader.count <= 129)
    #expect(crossfader.last == 1)
}
#endif
