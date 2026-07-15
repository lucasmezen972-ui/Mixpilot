#if os(macOS)
import Combine
import Foundation
import MixPilotCore
import MixPilotMIDI
import MixPilotSystem

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot = LiveSnapshot(
        state: .idle,
        currentTrack: nil,
        nextTrack: nil,
        activeDeck: .a,
        completedTransitions: 0,
        totalTransitions: 0,
        progress: 0,
        incidents: [],
        statusMessage: "Prêt à lancer une simulation"
    )
    @Published private(set) var report: SimulationReport?
    @Published private(set) var isRunningSimulation = false
    @Published private(set) var midiStatus = "Non testé"
    @Published private(set) var seratoStatus = "Non détecté"
    @Published private(set) var accessibilityStatus = "Non autorisée"
    @Published private(set) var audioStatus = "Non testée"
    @Published var selectedSection: SidebarSection = .dashboard

    private var midiController: CoreMIDIController?
    private let environmentProbe = SeratoEnvironmentProbe()

    init() {
        refreshEnvironment()
        configureMIDI()
    }

    func refreshEnvironment() {
        let result = environmentProbe.probe()
        seratoStatus = result.isRunning ? "Serato détecté" : "Serato non lancé"
        accessibilityStatus = result.accessibilityGranted ? "Autorisée" : "Action requise"
        audioStatus = result.audioPermission
    }

    func configureMIDI() {
        do {
            midiController = try CoreMIDIController()
            midiStatus = "Port virtuel actif"
        } catch {
            midiStatus = "Échec : \(error.localizedDescription)"
        }
    }

    func runSimulation() {
        guard !isRunningSimulation else { return }
        isRunningSimulation = true
        report = nil

        Task {
            do {
                let tracks = SetSimulator().makeTracks(count: 50)
                let plans = TransitionPlanner().planSet(tracks)
                let engine = AutopilotEngine()
                try await engine.load(tracks: tracks, plans: plans)
                try await engine.start()

                var step = 0
                var latest = await engine.snapshot()
                while latest.state != .completed && latest.state != .failed {
                    if step == 18 { await engine.inject(.slowLoad) }
                    if step == 77 { await engine.inject(.internetLoss) }
                    latest = await engine.advance()
                    snapshot = latest
                    try? await Task.sleep(for: .milliseconds(35))
                    step += 1
                }

                report = SimulationReport(
                    trackCount: tracks.count,
                    transitionCount: plans.count,
                    completedTransitions: latest.completedTransitions,
                    finalState: latest.state,
                    incidentCount: latest.incidents.count,
                    recoveredIncidentCount: latest.incidents.filter(\.recovered).count,
                    minimumConfidence: plans.map(\.confidence).min() ?? 100
                )
            } catch {
                snapshot.statusMessage = "Simulation interrompue : \(error.localizedDescription)"
            }
            isRunningSimulation = false
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard = "Tableau de bord"
    case studio = "Studio"
    case live = "Live"
    case feasibility = "Feasibility Lab"
    case diagnostics = "Diagnostics"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard: "rectangle.grid.2x2"
        case .studio: "waveform.path.ecg"
        case .live: "play.circle"
        case .feasibility: "checklist"
        case .diagnostics: "stethoscope"
        }
    }
}
#endif
