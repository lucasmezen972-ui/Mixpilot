import Foundation
import Testing
@testable import MixPilotCore

private func transitionPlan(kind: TransitionKind) -> TransitionPlan {
    TransitionPlan(
        outgoingTrackID: UUID(),
        incomingTrackID: UUID(),
        kind: kind,
        bars: 8,
        targetBPM: 120,
        confidence: 90,
        reasons: [],
        lanes: [
            AutomationLane(target: .echoAmount, points: [
                AutomationPoint(beat: 0, value: 0),
                AutomationPoint(beat: 32, value: 1)
            ]),
            AutomationLane(target: .crossfader, points: [
                AutomationPoint(beat: 0, value: 0),
                AutomationPoint(beat: 32, value: 1)
            ]),
            AutomationLane(target: .incomingVolume, points: [
                AutomationPoint(beat: 0, value: 0),
                AutomationPoint(beat: 32, value: 1)
            ]),
            AutomationLane(target: .outgoingVolume, points: [
                AutomationPoint(beat: 0, value: 1),
                AutomationPoint(beat: 32, value: 0)
            ])
        ]
    )
}

private func capabilities(
    available: Set<DJCapability>
) -> DJBackendCapabilities {
    var result = DJBackendCapabilities()
    for capability in DJCapability.allCases {
        result[capability] = DJCapabilityStatus(
            availability: available.contains(capability) ? .available : .unavailable,
            confidence: available.contains(capability) ? .validated : .unverified,
            validation: available.contains(capability) ? .automatedSuccess : .blockedByPlatform
        )
    }
    return result
}

@Test("Echo Exit falls back when effects are unavailable")
func echoExitUsesSafeFallbackWithoutEffect() {
    let backend = capabilities(available: [
        .trackLoading, .playPause, .channelVolume, .sync
    ])

    let result = TransitionCapabilityNegotiator().adapt(
        transitionPlan(kind: .echoExit),
        to: backend
    )

    #expect(result.isExecutable)
    #expect(result.usedFallback)
    #expect(result.selectedPlan?.kind == .smoothBlend || result.selectedPlan?.kind == .safeFade)
    #expect(result.selectedPlan?.lanes.contains { $0.target == .echoAmount } == false)
    #expect(result.selectedPlan?.lanes.contains { $0.target == .incomingVolume } == true)
    #expect(result.explanation.contains("indisponible"))
}

@Test("Crossfader is removed while volume protection remains")
func crossfaderIsOptionalWhenVolumesAreAvailable() {
    let backend = capabilities(available: [
        .trackLoading, .playPause, .channelVolume, .sync, .eqLow
    ])

    let original = TransitionPlanner().plan(
        from: Track(title: "A", artist: "A", bpm: 120, duration: 200, energy: 0.5, vocalDensity: 0.2, profile: .afro),
        to: Track(title: "B", artist: "B", bpm: 121, duration: 200, energy: 0.6, vocalDensity: 0.2, profile: .afro)
    )
    let result = TransitionCapabilityNegotiator().adapt(original, to: backend)

    #expect(result.isExecutable)
    #expect(result.selectedPlan?.lanes.contains { $0.target == .crossfader } == false)
    #expect(result.selectedPlan?.lanes.contains { $0.target == .incomingVolume } == true)
    #expect(result.selectedPlan?.lanes.contains { $0.target == .outgoingVolume } == true)
}

@Test("A transition is blocked when Play or channel volume is unavailable")
func transitionCannotRunWithoutCriticalControls() {
    let backend = capabilities(available: [.trackLoading])
    let result = TransitionCapabilityNegotiator().adapt(
        transitionPlan(kind: .safeFade),
        to: backend
    )

    #expect(!result.isExecutable)
    #expect(result.missingRequiredCapabilities.contains(.playPause))
    #expect(result.missingRequiredCapabilities.contains(.channelVolume))
}

@Test("Fully capable backends keep the original transition")
func capableBackendKeepsOriginalTransition() async {
    let backend = FullyCapableBackend(identifier: .djay)
    let result = TransitionCapabilityNegotiator().adapt(
        transitionPlan(kind: .echoExit),
        to: await backend.capabilities()
    )

    #expect(result.isExecutable)
    #expect(!result.usedFallback)
    #expect(result.selectedPlan?.kind == .echoExit)
}
