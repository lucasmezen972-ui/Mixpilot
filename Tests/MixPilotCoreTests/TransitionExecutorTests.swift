import Testing
@testable import MixPilotCore

private actor RecordingSender: SeratoCommandSending {
    private var records: [String] = []

    func trigger(_ action: SeratoAction) async throws {
        records.append("trigger:\(action.rawValue)")
    }

    func set(_ action: SeratoAction, value: Double) async throws {
        records.append("set:\(action.rawValue):\(String(format: "%.3f", value))")
    }

    func allRecords() -> [String] { records }
}

@Test("Transition executor starts incoming deck automates controls and stops outgoing deck")
func transitionExecutorSequence() async throws {
    let tracks = SetSimulator().makeTracks(count: 2)
    let plan = TransitionPlanner().plan(from: tracks[0], to: tracks[1])
    let sender = RecordingSender()
    let executor = TransitionExecutor(sender: sender)

    let summary = try await executor.execute(
        plan: plan,
        outgoingDeck: .a,
        framesPerSecond: 5,
        speedMultiplier: 100_000
    )
    let records = await sender.allRecords()

    #expect(summary.completed)
    #expect(summary.outgoingDeck == .a)
    #expect(summary.incomingDeck == .b)
    #expect(records.contains("trigger:syncB"))
    #expect(records.contains("trigger:playB"))
    #expect(records.contains("trigger:pauseA"))
    #expect(records.contains { $0.hasPrefix("set:crossfader:") })
}
