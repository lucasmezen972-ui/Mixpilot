import Foundation

public struct TransitionRequirements: Codable, Hashable, Sendable {
    public var required: Set<DJCapability>
    public var preferred: Set<DJCapability>
    public var fallbackVariants: [TransitionKind]

    public init(
        required: Set<DJCapability>,
        preferred: Set<DJCapability> = [],
        fallbackVariants: [TransitionKind] = []
    ) {
        self.required = required
        self.preferred = preferred
        self.fallbackVariants = fallbackVariants
    }
}

public extension TransitionKind {
    var requirements: TransitionRequirements {
        let base: Set<DJCapability> = [.trackLoading, .playPause, .channelVolume]
        switch self {
        case .smoothBlend:
            return TransitionRequirements(
                required: base,
                preferred: [.sync, .eqLow, .crossfader],
                fallbackVariants: [.safeFade, .hardCut]
            )
        case .bassSwap:
            return TransitionRequirements(
                required: base.union([.eqLow]),
                preferred: [.sync, .crossfader],
                fallbackVariants: [.smoothBlend, .safeFade, .hardCut]
            )
        case .rapSwitch:
            return TransitionRequirements(
                required: base,
                preferred: [.sync, .crossfader],
                fallbackVariants: [.safeFade, .hardCut]
            )
        case .shattaDrop:
            return TransitionRequirements(
                required: base,
                preferred: [.sync, .crossfader, .filter],
                fallbackVariants: [.rapSwitch, .safeFade, .hardCut]
            )
        case .echoExit:
            return TransitionRequirements(
                required: base.union([.effects]),
                preferred: [.sync, .crossfader],
                fallbackVariants: [.bassSwap, .smoothBlend, .safeFade, .hardCut]
            )
        case .safeFade:
            return TransitionRequirements(
                required: base,
                preferred: [.sync, .crossfader],
                fallbackVariants: [.hardCut]
            )
        case .hardCut:
            return TransitionRequirements(
                required: base,
                preferred: [.sync],
                fallbackVariants: []
            )
        }
    }
}

public extension DJControlAction {
    var requiredCapability: DJCapability {
        switch self {
        case .playA, .playB, .pauseA, .pauseB: .playPause
        case .cueA, .cueB: .cue
        case .syncA, .syncB: .sync
        case .loadA, .loadB: .trackLoading
        case .browserUp, .browserDown, .browserFocus: .visiblePlaylistReading
        case .volumeA, .volumeB: .channelVolume
        case .crossfader: .crossfader
        case .lowEQA, .lowEQB: .eqLow
        case .midEQA, .midEQB: .eqMid
        case .highEQA, .highEQB: .eqHigh
        case .filterA, .filterB: .filter
        case .pitchA, .pitchB: .tempo
        case .echoA, .echoB, .echoAmountA, .echoAmountB: .effects
        case .loopA, .loopB, .exitLoopA, .exitLoopB: .loop
        }
    }
}

public struct TransitionAdaptationResult: Codable, Hashable, Sendable {
    public var originalKind: TransitionKind
    public var selectedPlan: TransitionPlan?
    public var missingRequiredCapabilities: Set<DJCapability>
    public var unavailablePreferredCapabilities: Set<DJCapability>
    public var explanation: String

    public init(
        originalKind: TransitionKind,
        selectedPlan: TransitionPlan?,
        missingRequiredCapabilities: Set<DJCapability>,
        unavailablePreferredCapabilities: Set<DJCapability>,
        explanation: String
    ) {
        self.originalKind = originalKind
        self.selectedPlan = selectedPlan
        self.missingRequiredCapabilities = missingRequiredCapabilities
        self.unavailablePreferredCapabilities = unavailablePreferredCapabilities
        self.explanation = explanation
    }

    public var isExecutable: Bool { selectedPlan != nil }
    public var usedFallback: Bool { selectedPlan?.kind != originalKind }
}

public struct TransitionCapabilityNegotiator: Sendable {
    public init() {}

    public func adapt(
        _ plan: TransitionPlan,
        to capabilities: DJBackendCapabilities
    ) -> TransitionAdaptationResult {
        let requirements = plan.kind.requirements
        let missing = requirements.required.filter { !capabilities.supports($0) }
        let preferredUnavailable = requirements.preferred.filter { !capabilities.supports($0) }

        if missing.isEmpty {
            let filtered = filteringUnsupportedLanes(plan, capabilities: capabilities)
            return TransitionAdaptationResult(
                originalKind: plan.kind,
                selectedPlan: filtered,
                missingRequiredCapabilities: [],
                unavailablePreferredCapabilities: preferredUnavailable,
                explanation: preferredUnavailable.isEmpty
                    ? "La transition est compatible avec le backend actif."
                    : "La transition reste disponible avec une version adaptée aux commandes validées."
            )
        }

        for fallback in requirements.fallbackVariants {
            let fallbackMissing = fallback.requirements.required.filter { !capabilities.supports($0) }
            guard fallbackMissing.isEmpty else { continue }

            let fallbackPlan = makeFallbackPlan(from: plan, kind: fallback, capabilities: capabilities)
            let fallbackPreferred = fallback.requirements.preferred.filter { !capabilities.supports($0) }
            return TransitionAdaptationResult(
                originalKind: plan.kind,
                selectedPlan: fallbackPlan,
                missingRequiredCapabilities: missing,
                unavailablePreferredCapabilities: fallbackPreferred,
                explanation: "\(plan.kind.rawValue) utilise une fonction indisponible. MixPilot utilisera \(fallback.rawValue) pour garder une transition sûre."
            )
        }

        return TransitionAdaptationResult(
            originalKind: plan.kind,
            selectedPlan: nil,
            missingRequiredCapabilities: missing,
            unavailablePreferredCapabilities: preferredUnavailable,
            explanation: "Aucune variante sûre ne peut être exécutée avec les commandes actuellement validées."
        )
    }

    public func adaptSet(
        _ plans: [TransitionPlan],
        to capabilities: DJBackendCapabilities
    ) -> [TransitionAdaptationResult] {
        plans.map { adapt($0, to: capabilities) }
    }

    private func filteringUnsupportedLanes(
        _ plan: TransitionPlan,
        capabilities: DJBackendCapabilities
    ) -> TransitionPlan {
        var adapted = plan
        adapted.lanes = plan.lanes.filter { capabilities.supports(capability(for: $0.target)) }
        return adapted
    }

    private func makeFallbackPlan(
        from plan: TransitionPlan,
        kind: TransitionKind,
        capabilities: DJBackendCapabilities
    ) -> TransitionPlan {
        let bars = fallbackBars(for: kind)
        let totalBeats = Double(max(1, bars * 4))
        let cutAtEnd = kind == .hardCut || kind == .rapSwitch || kind == .shattaDrop
        var lanes = volumeLanes(totalBeats: totalBeats, cutAtEnd: cutAtEnd)

        if capabilities.supports(.crossfader) {
            lanes.append(AutomationLane(
                target: .crossfader,
                points: cutAtEnd
                    ? [
                        AutomationPoint(beat: 0, value: 0),
                        AutomationPoint(beat: max(1, totalBeats - 1), value: 0),
                        AutomationPoint(beat: totalBeats, value: 1),
                    ]
                    : [
                        AutomationPoint(beat: 0, value: 0),
                        AutomationPoint(beat: totalBeats, value: 1),
                    ]
            ))
        }

        if (kind == .smoothBlend || kind == .bassSwap), capabilities.supports(.eqLow) {
            lanes.append(contentsOf: [
                AutomationLane(target: .incomingLowEQ, points: [
                    AutomationPoint(beat: 0, value: 0),
                    AutomationPoint(beat: totalBeats * 0.55, value: 0),
                    AutomationPoint(beat: totalBeats * 0.7, value: 1),
                ]),
                AutomationLane(target: .outgoingLowEQ, points: [
                    AutomationPoint(beat: 0, value: 1),
                    AutomationPoint(beat: totalBeats * 0.7, value: 0),
                ]),
            ])
        }

        var adapted = plan
        adapted.kind = kind
        adapted.bars = bars
        adapted.lanes = lanes
        adapted.reasons.append("Plan adapté aux capacités validées du backend actif")
        return adapted
    }

    private func capability(for target: AutomationTarget) -> DJCapability {
        switch target {
        case .crossfader: .crossfader
        case .outgoingVolume, .incomingVolume: .channelVolume
        case .outgoingLowEQ, .incomingLowEQ: .eqLow
        case .outgoingFilter: .filter
        case .echoAmount: .effects
        }
    }

    private func fallbackBars(for kind: TransitionKind) -> Int {
        switch kind {
        case .smoothBlend: 16
        case .bassSwap: 8
        case .rapSwitch: 8
        case .shattaDrop: 4
        case .echoExit: 4
        case .safeFade: 8
        case .hardCut: 1
        }
    }

    private func volumeLanes(totalBeats: Double, cutAtEnd: Bool) -> [AutomationLane] {
        if cutAtEnd {
            return [
                AutomationLane(target: .incomingVolume, points: [
                    AutomationPoint(beat: 0, value: 0),
                    AutomationPoint(beat: max(1, totalBeats - 1), value: 0),
                    AutomationPoint(beat: totalBeats, value: 1),
                ]),
                AutomationLane(target: .outgoingVolume, points: [
                    AutomationPoint(beat: 0, value: 1),
                    AutomationPoint(beat: max(1, totalBeats - 1), value: 1),
                    AutomationPoint(beat: totalBeats, value: 0),
                ]),
            ]
        }

        return [
            AutomationLane(target: .incomingVolume, points: [
                AutomationPoint(beat: 0, value: 0),
                AutomationPoint(beat: totalBeats, value: 1),
            ]),
            AutomationLane(target: .outgoingVolume, points: [
                AutomationPoint(beat: 0, value: 1),
                AutomationPoint(beat: totalBeats, value: 0),
            ]),
        ]
    }
}
