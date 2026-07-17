import Foundation

public enum ScenarioExpectedOutcome: String, Codable, Sendable {
    case recovered
    case manualControl
    case failedSafely
}

public struct FailureScenario: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var incident: IncidentKind
    public var injectionStep: Int
    public var expectedOutcome: ScenarioExpectedOutcome

    public init(
        id: UUID = UUID(),
        name: String,
        incident: IncidentKind,
        injectionStep: Int,
        expectedOutcome: ScenarioExpectedOutcome
    ) {
        self.id = id
        self.name = name
        self.incident = incident
        self.injectionStep = max(0, injectionStep)
        self.expectedOutcome = expectedOutcome
    }
}

public struct FailureScenarioResult: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var scenario: FailureScenario
    public var finalState: AutopilotState
    public var incidentRecorded: Bool
    public var incidentRecovered: Bool
    public var passed: Bool
    public var stepsExecuted: Int

    public init(
        id: UUID = UUID(),
        scenario: FailureScenario,
        finalState: AutopilotState,
        incidentRecorded: Bool,
        incidentRecovered: Bool,
        passed: Bool,
        stepsExecuted: Int
    ) {
        self.id = id
        self.scenario = scenario
        self.finalState = finalState
        self.incidentRecorded = incidentRecorded
        self.incidentRecovered = incidentRecovered
        self.passed = passed
        self.stepsExecuted = max(0, stepsExecuted)
    }
}

public struct FailureScenarioMatrixReport: Codable, Hashable, Sendable {
    public var trackCount: Int
    public var results: [FailureScenarioResult]

    public init(trackCount: Int, results: [FailureScenarioResult]) {
        self.trackCount = max(0, trackCount)
        self.results = results
    }

    public var passedCount: Int { results.filter(\.passed).count }
    public var failedCount: Int { results.count - passedCount }
    public var succeeded: Bool { !results.isEmpty && failedCount == 0 }
}

public struct FailureScenarioSuite: Sendable {
    public init() {}

    public static var releaseCandidateScenarios: [FailureScenario] {
        [
            FailureScenario(name: "Chargement lent", incident: .slowLoad, injectionStep: 4, expectedOutcome: .recovered),
            FailureScenario(name: "Délai de chargement dépassé", incident: .loadTimeout, injectionStep: 6, expectedOutcome: .recovered),
            FailureScenario(name: "Mauvais morceau", incident: .wrongTrack, injectionStep: 8, expectedOutcome: .recovered),
            FailureScenario(name: "Transition incohérente", incident: .transitionMismatch, injectionStep: 10, expectedOutcome: .recovered),
            FailureScenario(name: "Perte Internet", incident: .internetLoss, injectionStep: 12, expectedOutcome: .recovered),
            FailureScenario(name: "Silence audio", incident: .audioSilence, injectionStep: 14, expectedOutcome: .recovered),
            FailureScenario(name: "Source audio perdue", incident: .audioSourceLost, injectionStep: 16, expectedOutcome: .recovered),
            FailureScenario(name: "Saturation audio", incident: .audioClipping, injectionStep: 18, expectedOutcome: .recovered),
            FailureScenario(name: "Connexion MIDI perdue", incident: .midiUnavailable, injectionStep: 20, expectedOutcome: .recovered),
            FailureScenario(name: "Backend DJ fermé", incident: .backendUnavailable, injectionStep: 22, expectedOutcome: .recovered),
            FailureScenario(name: "Secteur débranché", incident: .powerDisconnected, injectionStep: 24, expectedOutcome: .recovered),
            FailureScenario(name: "Dernier état incohérent", incident: .checkpointMismatch, injectionStep: 26, expectedOutcome: .manualControl),
            FailureScenario(name: "Musique de secours en panne", incident: .emergencyPlayerFailure, injectionStep: 28, expectedOutcome: .failedSafely),
        ]
    }

    public func run(
        scenarios: [FailureScenario] = Self.releaseCandidateScenarios,
        trackCount: Int = 12,
        maximumSteps: Int = 500
    ) async -> FailureScenarioMatrixReport {
        var results: [FailureScenarioResult] = []
        let tracks = SetSimulator().makeTracks(count: max(2, trackCount))
        let plans = TransitionPlanner().planSet(tracks)

        for scenario in scenarios {
            let engine = AutopilotEngine()
            do {
                try await engine.load(tracks: tracks, plans: plans)
                try await engine.start()
            } catch {
                results.append(FailureScenarioResult(
                    scenario: scenario,
                    finalState: .failed,
                    incidentRecorded: false,
                    incidentRecovered: false,
                    passed: false,
                    stepsExecuted: 0
                ))
                continue
            }

            var snapshot = await engine.snapshot()
            var step = 0
            var injected = false
            while step < maximumSteps {
                if step == scenario.injectionStep {
                    await engine.inject(scenario.incident)
                    injected = true
                }
                snapshot = await engine.advance()
                step += 1

                if snapshot.state == .manualControl ||
                    snapshot.state == .failed ||
                    snapshot.state == .completed {
                    break
                }

                if injected,
                   let incident = snapshot.incidents.last,
                   incident.kind == scenario.incident,
                   incident.recovered,
                   scenario.expectedOutcome == .recovered {
                    break
                }
            }

            let incident = snapshot.incidents.first { $0.kind == scenario.incident }
            let passed: Bool
            switch scenario.expectedOutcome {
            case .recovered:
                passed = incident?.recovered == true && snapshot.state != .failed
            case .manualControl:
                passed = incident != nil && snapshot.state == .manualControl
            case .failedSafely:
                passed = incident != nil && snapshot.state == .failed
            }

            results.append(FailureScenarioResult(
                scenario: scenario,
                finalState: snapshot.state,
                incidentRecorded: incident != nil,
                incidentRecovered: incident?.recovered ?? false,
                passed: passed,
                stepsExecuted: step
            ))
        }

        return FailureScenarioMatrixReport(trackCount: tracks.count, results: results)
    }
}
