import Testing
@testable import MixPilotCore

@Test("Modeled preview returns scored transition alternatives")
func previewReturnsScoredVariants() {
    let outgoing = Track(
        title: "Rap vocal",
        artist: "A",
        bpm: 92,
        duration: 210,
        energy: 0.62,
        vocalDensity: 0.9,
        profile: .rap
    )
    let incoming = Track(
        title: "Shatta drop",
        artist: "B",
        bpm: 108,
        duration: 190,
        energy: 0.9,
        vocalDensity: 0.72,
        profile: .shatta
    )
    let plan = TransitionPlanner().plan(from: outgoing, to: incoming)
    let preview = RehearsalPreviewEngine().preview(
        plan: plan,
        outgoing: outgoing,
        incoming: incoming
    )

    #expect(preview.modeledOnly)
    #expect(preview.result.variants.count >= 2)
    #expect(preview.result.variants.allSatisfy { $0.score != nil })
    #expect(preview.result.selectedVariant != nil)
    #expect(!preview.explanation.isEmpty)
}

@Test("Large tempo gap favors a safe independent transition")
func largeTempoGapFavorsSafety() {
    let outgoing = Track(title: "Slow", artist: "A", bpm: 70, duration: 200, energy: 0.4, vocalDensity: 0.7, profile: .family)
    let incoming = Track(title: "Fast", artist: "B", bpm: 150, duration: 200, energy: 0.9, vocalDensity: 0.8, profile: .shatta)
    let plan = TransitionPlanner().plan(from: outgoing, to: incoming)
    let preview = RehearsalPreviewEngine().preview(plan: plan, outgoing: outgoing, incoming: incoming)
    let selectedKind = preview.result.selectedVariant?.plan.kind

    #expect(selectedKind == .safeFade || selectedKind == .echoExit || selectedKind == .hardCut)
}
