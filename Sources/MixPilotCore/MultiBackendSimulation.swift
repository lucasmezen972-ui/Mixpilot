import Foundation

public enum MultiBackendSimulationScenario: String, Codable, CaseIterable, Sendable {
    case baseline
    case partialCapabilities
    case noCrossfader
    case noEffects
    case noStateReading
    case mappingIncompatible
    case backendLost
    case delayedCommand
    case unconfirmedCommand
    case duplicateCommand
    case internetLost
    case iphoneLost
    case softwareVersionChanged
    case manualControl
}

public enum SimulatedRuntimeDecision: String, Codable, Sendable {
    case preparePlan
    case useFallback
    case continueLocally
    case blockBeforeLive
    case openCircuitBreaker
    case deduplicate
    case requireRevalidation
    case manualControl
}

public struct MultiBackendSimulationResult: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var backend: DJBackendIdentifier
    public var scenario: MultiBackendSimulationScenario
    public var validationStatus: DJValidationStatus
    public var expectedDecision: SimulatedRuntimeDecision
    public var plannedTransitions: Int
    public var fallbackTransitions: Int
    public var blockedTransitions: Int
    public var passed: Bool
    public var detail: String

    public init(
        id: UUID = UUID(),
        backend: DJBackendIdentifier,
        scenario: MultiBackendSimulationScenario,
        validationStatus: DJValidationStatus = .simulatedSuccess,
        expectedDecision: SimulatedRuntimeDecision,
        plannedTransitions: Int,
        fallbackTransitions: Int,
        blockedTransitions: Int,
        passed: Bool,
        detail: String
    ) {
        self.id = id
        self.backend = backend
        self.scenario = scenario
        self.validationStatus = validationStatus
        self.expectedDecision = expectedDecision
        self.plannedTransitions = plannedTransitions
        self.fallbackTransitions = fallbackTransitions
        self.blockedTransitions = blockedTransitions
        self.passed = passed
        self.detail = detail
    }
}

public struct MultiBackendSimulationReport: Codable, Hashable, Sendable {
    public var trackCount: Int
    public var results: [MultiBackendSimulationResult]

    public init(trackCount: Int, results: [MultiBackendSimulationResult]) {
        self.trackCount = max(0, trackCount)
        self.results = results
    }

    public var passedCount: Int { results.filter(\.passed).count }
    public var failedCount: Int { results.count - passedCount }
    public var succeeded: Bool { !results.isEmpty && failedCount == 0 }
}

public struct MultiBackendSimulationSuite: Sendable {
    public init() {}

    public func run(
        backends: [DJBackendIdentifier] = DJBackendIdentifier.allCases,
        trackCount: Int = 50
    ) -> MultiBackendSimulationReport {
        let tracks = SetSimulator().makeTracks(count: max(2, trackCount))
        let plans = TransitionPlanner().planSet(tracks)
        var results: [MultiBackendSimulationResult] = []

        for backend in backends {
            for scenario in MultiBackendSimulationScenario.allCases {
                results.append(run(
                    backend: backend,
                    scenario: scenario,
                    plans: plans
                ))
            }
        }

        return MultiBackendSimulationReport(
            trackCount: tracks.count,
            results: results
        )
    }

    private func run(
        backend: DJBackendIdentifier,
        scenario: MultiBackendSimulationScenario,
        plans: [TransitionPlan]
    ) -> MultiBackendSimulationResult {
        let capabilities = capabilities(for: backend, scenario: scenario)
        let adaptations = TransitionCapabilityNegotiator().adaptSet(
            plans,
            to: capabilities
        )
        let executable = adaptations.filter(\.isExecutable).count
        let fallback = adaptations.filter { $0.isExecutable && $0.usedFallback }.count
        let blocked = adaptations.count - executable
        let decision = expectedDecision(for: scenario)
        let passed = assertion(
            scenario: scenario,
            capabilities: capabilities,
            adaptations: adaptations,
            fallbackCount: fallback,
            blockedCount: blocked
        )

        return MultiBackendSimulationResult(
            backend: backend,
            scenario: scenario,
            expectedDecision: decision,
            plannedTransitions: executable,
            fallbackTransitions: fallback,
            blockedTransitions: blocked,
            passed: passed,
            detail: detail(
                backend: backend,
                scenario: scenario,
                decision: decision
            )
        )
    }

    private func capabilities(
        for backend: DJBackendIdentifier,
        scenario: MultiBackendSimulationScenario
    ) -> DJBackendCapabilities {
        var result = baselineCapabilities(for: backend)

        switch scenario {
        case .baseline, .delayedCommand, .duplicateCommand, .internetLost,
             .iphoneLost, .manualControl:
            break

        case .partialCapabilities:
            makeUnavailable(.effects, in: &result)
            makeUnavailable(.crossfader, in: &result)
            makeUnavailable(.filter, in: &result)

        case .noCrossfader:
            makeUnavailable(.crossfader, in: &result)

        case .noEffects:
            makeUnavailable(.effects, in: &result)

        case .noStateReading:
            makePending(.deckStateReading, in: &result)
            makePending(.trackStateReading, in: &result)
            makePending(.automix, in: &result)

        case .mappingIncompatible:
            makeUnavailable(.trackLoading, in: &result)
            makeUnavailable(.playPause, in: &result)
            makeUnavailable(.channelVolume, in: &result)

        case .backendLost:
            for capability in [
                DJCapability.processDetection,
                .trackLoading,
                .playPause,
                .channelVolume,
                .deckStateReading,
                .trackStateReading,
            ] {
                makeUnavailable(capability, in: &result)
            }

        case .unconfirmedCommand:
            makePending(.trackLoading, in: &result)
            makePending(.playPause, in: &result)
            makePending(.channelVolume, in: &result)

        case .softwareVersionChanged:
            for capability in DJCapability.allCases {
                makePending(capability, in: &result)
            }
        }

        return result
    }

    private func baselineCapabilities(
        for backend: DJBackendIdentifier
    ) -> DJBackendCapabilities {
        var result = DJBackendCapabilities()
        let simulated = DJCapabilityStatus(
            availability: .available,
            confidence: .simulated,
            validation: .simulatedSuccess,
            method: .guidedManualStep,
            testedSoftwareVersion: "simulated"
        )

        for capability in DJCapability.allCases {
            result[capability] = simulated
        }

        if backend != .djay {
            makeUnavailable(.automix, in: &result)
        }
        return result
    }

    private func makeUnavailable(
        _ capability: DJCapability,
        in matrix: inout DJBackendCapabilities
    ) {
        matrix[capability] = DJCapabilityStatus(
            availability: .unavailable,
            confidence: .simulated,
            validation: .simulatedSuccess,
            method: .unavailable,
            reason: "Capacité retirée par le scénario de simulation."
        )
    }

    private func makePending(
        _ capability: DJCapability,
        in matrix: inout DJBackendCapabilities
    ) {
        matrix[capability] = DJCapabilityStatus(
            availability: .partiallyAvailable,
            confidence: .observed,
            validation: .requiresDeviceValidation,
            method: .accessibility,
            reason: "État volontairement non confirmé dans la simulation."
        )
    }

    private func expectedDecision(
        for scenario: MultiBackendSimulationScenario
    ) -> SimulatedRuntimeDecision {
        switch scenario {
        case .baseline:
            .preparePlan
        case .partialCapabilities, .noCrossfader, .noEffects:
            .useFallback
        case .noStateReading, .mappingIncompatible:
            .blockBeforeLive
        case .backendLost, .delayedCommand, .unconfirmedCommand, .manualControl:
            .manualControl
        case .duplicateCommand:
            .deduplicate
        case .internetLost, .iphoneLost:
            .continueLocally
        case .softwareVersionChanged:
            .requireRevalidation
        }
    }

    private func assertion(
        scenario: MultiBackendSimulationScenario,
        capabilities: DJBackendCapabilities,
        adaptations: [TransitionAdaptationResult],
        fallbackCount: Int,
        blockedCount: Int
    ) -> Bool {
        switch scenario {
        case .baseline:
            return blockedCount == 0

        case .partialCapabilities, .noCrossfader:
            return blockedCount == 0

        case .noEffects:
            let containedEcho = adaptations.contains { $0.originalKind == .echoExit }
            let echoAdapted = adaptations
                .filter { $0.originalKind == .echoExit }
                .allSatisfy { $0.isExecutable && $0.usedFallback }
            return !containedEcho || echoAdapted

        case .noStateReading:
            return !capabilities[.deckStateReading].isConfirmedForLive &&
                !capabilities[.trackStateReading].isConfirmedForLive

        case .mappingIncompatible:
            return blockedCount > 0 &&
                !capabilities.supports(.trackLoading) &&
                !capabilities.supports(.playPause)

        case .backendLost:
            return blockedCount > 0 &&
                !capabilities.supports(.processDetection) &&
                !capabilities.supports(.trackLoading) &&
                !capabilities.supports(.playPause)

        case .delayedCommand:
            // Timeout and circuit-breaker behavior is exercised by BackendCommandQueue tests.
            return blockedCount == 0

        case .unconfirmedCommand:
            return blockedCount > 0 &&
                !capabilities[.trackLoading].isConfirmedForLive &&
                !capabilities[.playPause].isConfirmedForLive &&
                !capabilities[.channelVolume].isConfirmedForLive

        case .manualControl:
            return blockedCount == 0

        case .duplicateCommand:
            // Idempotency behavior is exercised by BackendCommandQueue tests.
            return blockedCount == 0

        case .internetLost, .iphoneLost:
            return blockedCount == 0

        case .softwareVersionChanged:
            return DJCapability.allCases.allSatisfy {
                !capabilities[$0].isConfirmedForLive &&
                    capabilities[$0].validation == .requiresDeviceValidation
            }
        }
    }

    private func detail(
        backend: DJBackendIdentifier,
        scenario: MultiBackendSimulationScenario,
        decision: SimulatedRuntimeDecision
    ) -> String {
        "Simulation \(scenario.rawValue) pour \(backend.displayName) : décision attendue \(decision.rawValue). Aucun logiciel ou matériel réel n’a été contacté."
    }
}
