import Foundation

public struct SimulationReport: Codable, Sendable {
    public var trackCount: Int
    public var transitionCount: Int
    public var completedTransitions: Int
    public var finalState: AutopilotState
    public var incidentCount: Int
    public var recoveredIncidentCount: Int
    public var minimumConfidence: Int
    public var safeManualHandoff: Bool

    public init(
        trackCount: Int,
        transitionCount: Int,
        completedTransitions: Int,
        finalState: AutopilotState,
        incidentCount: Int,
        recoveredIncidentCount: Int,
        minimumConfidence: Int,
        safeManualHandoff: Bool = false
    ) {
        self.trackCount = trackCount
        self.transitionCount = transitionCount
        self.completedTransitions = completedTransitions
        self.finalState = finalState
        self.incidentCount = incidentCount
        self.recoveredIncidentCount = recoveredIncidentCount
        self.minimumConfidence = minimumConfidence
        self.safeManualHandoff = safeManualHandoff
    }

    public var succeeded: Bool {
        let completedNormally = finalState == .completed &&
            completedTransitions == transitionCount &&
            incidentCount == recoveredIncidentCount
        return completedNormally || (finalState == .manualControl && safeManualHandoff)
    }
}

public struct SetSimulator: Sendable {
    public init() {}

    public func makeTracks(count: Int) -> [Track] {
        let profiles: [MusicalProfile] = [.family, .rap, .afro, .zouk, .kompa, .dancehall, .shatta, .bouyon, .variety]
        var tracks: [Track] = []
        tracks.reserveCapacity(count)
        for index in 0..<count {
            let title = "Titre \(index + 1)"
            let artist = "Artiste \((index % 8) + 1)"
            let bpm = 88.0 + Double((index * 7) % 48)
            let duration = 165.0 + Double((index * 11) % 90)
            let energy = 0.35 + Double((index * 13) % 60) / 100.0
            let vocalDensity = 0.25 + Double((index * 17) % 70) / 100.0
            let profile = profiles[index % profiles.count]
            tracks.append(Track(
                title: title,
                artist: artist,
                bpm: bpm,
                duration: duration,
                energy: energy,
                vocalDensity: vocalDensity,
                profile: profile
            ))
        }
        return tracks
    }

    public func run(trackCount: Int = 50, injectedIncidents: [Int: IncidentKind] = [:]) async throws -> SimulationReport {
        let tracks = makeTracks(count: trackCount)
        let plans = TransitionPlanner().planSet(tracks)
        let engine = AutopilotEngine()
        try await engine.load(tracks: tracks, plans: plans)
        try await engine.start()

        var step = 0
        var snapshot = await engine.snapshot()
        let maxSteps = max(20, trackCount * 20)

        while snapshot.state != .completed &&
              snapshot.state != .failed &&
              snapshot.state != .manualControl &&
              step < maxSteps {
            if let incident = injectedIncidents[step] {
                await engine.inject(incident)
            }
            snapshot = await engine.advance()
            step += 1
        }

        let manualHandoffKinds: Set<IncidentKind> = [
            .audioSourceLost,
            .midiUnavailable,
            .backendUnavailable,
            .checkpointMismatch,
        ]
        let safeManualHandoff = snapshot.state == .manualControl &&
            snapshot.incidents.last.map { manualHandoffKinds.contains($0.kind) } == true

        return SimulationReport(
            trackCount: tracks.count,
            transitionCount: plans.count,
            completedTransitions: snapshot.completedTransitions,
            finalState: snapshot.state,
            incidentCount: snapshot.incidents.count,
            recoveredIncidentCount: snapshot.incidents.filter(\.recovered).count,
            minimumConfidence: plans.map(\.confidence).min() ?? 100,
            safeManualHandoff: safeManualHandoff
        )
    }
}
