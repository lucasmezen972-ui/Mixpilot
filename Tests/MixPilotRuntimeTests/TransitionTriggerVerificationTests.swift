#if os(macOS)
import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotRuntime

private struct TriggerRecord: Sendable, Equatable {
    let action: DJControlAction
    let strict: Bool
}

private actor TriggerSender: DJTransitionCommandSending {
    var records: [TriggerRecord] = []

    func trigger(_ action: DJControlAction) async throws {
        records.append(.init(action: action, strict: false))
    }

    func trigger(_ action: DJControlAction, requireVerification: Bool) async throws {
        records.append(.init(action: action, strict: requireVerification))
    }

    func set(_ action: DJControlAction, value: Double) async throws {}
}

@Test("Transition trigger policy")
func transitionTriggerPolicy() async throws {
    let sender = TriggerSender()
    let executor = TransitionExecutor(sender: sender)
    let plan = TransitionPlan(
        outgoingTrackID: UUID(),
        incomingTrackID: UUID(),
        kind: .safeFade,
        bars: 1,
        targetBPM: 120,
        confidence: 100,
        reasons: [],
        lanes: []
    )

    _ = try await executor.execute(
        plan: plan,
        outgoingDeck: .a,
        framesPerSecond: 1,
        speedMultiplier: 1_000
    )

    let records = await sender.records
    #expect(records == [
        .init(action: .syncB, strict: false),
        .init(action: .playB, strict: true),
        .init(action: .pauseA, strict: true),
    ])
}
#endif
