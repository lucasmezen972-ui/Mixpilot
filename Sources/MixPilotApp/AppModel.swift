#if os(macOS)
import AppKit
import Combine
import Foundation
import MixPilotCore
import MixPilotMIDI
import MixPilotRuntime
import MixPilotSystem

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot = LiveSnapshot(
        state: .idle,
        currentTrack: nil,
        nextTrack: nil,
        activeDeck: .a,
        completedTransitions: 0,
        totalTransitions: 0,
        progress: 0,
        incidents: [],
        statusMessage: "Prêt à préparer un set"
    )
    @Published var report: SimulationReport?
    @Published var isRunningSimulation = false
    @Published var midiStatus = "Non testé"
    @Published var backendStatus = "Choisis ton logiciel DJ"
    @Published var selectedBackend: DJBackendIdentifier?
    @Published var backendDescriptors: [DJBackendDescriptor] = []
    @Published var backendValidationReport: DJBackendValidationReport?
    @Published var accessibilityStatus = "Non autorisée"
    @Published var accessibilityGranted = false
    @Published var audioStatus = "Non testée"
    @Published var audioLevelDB = -160.0
    @Published var libraryRowCount = 0
    @Published var preparedProject: SetProject?
    @Published var playlistWarnings: [PlaylistImportWarning] = []
    @Published var mappingProfile = MIDIMappingProfile.developmentDefault
    @Published var emergencyStatus = "Aucun fichier sélectionné"
    @Published var emergencyDuration: TimeInterval = 0
    @Published var runtimeStatus = "Inactif"
    @Published var runtimeEvents: [String] = []
    @Published var isLiveRunning = false
    @Published var liveArmed = false
    @Published var connectivityStatus = ConnectivityStatus(
        isAvailable: false,
        isExpensive: false,
        interfaceDescription: "Initialisation"
    )
    @Published var powerStatus = PowerStatus(
        connectedToPower: false,
        batteryLevel: nil,
        lowPowerModeEnabled: false
    )
    @Published var preflightReport = PreflightReport(items: [])
    @Published var optimizationReport: SetOptimizationReport?
    @Published var selectedSection: SidebarSection = .dashboard

    var seratoStatus: String { backendStatus }

    var midiController: CoreMIDIController?
    var mappedController: MappedMIDIController?
    var mappingStore: MIDIMappingProfileStore?
    var backendRegistry: DJBackendRegistry?
    var runtimeCoordinator: LiveAutopilotCoordinator?
    var liveTask: Task<Void, Never>?
    var liveReconciliationTask: Task<Void, Never>?
    var lastAudioLevelUIUpdateAt: TimeInterval = 0
    var audioMonitoringGeneration: UInt64 = 0

    let accessibilityBridge = DJAccessibilityBridge()
    let commandValidationStore = UserDefaultsDJCommandValidationStore()
    let audioMonitor = AudioLevelMonitor()
    let audioWatchdog = AudioWatchdog()
    let emergencyPlayer = EmergencyAudioPlayer()
    let connectivityMonitor = ConnectivityMonitor()
    let powerProbe = PowerStatusProbe()
    let sleepAssertion = SleepAssertionManager()
    let projectStore: JSONProjectStore

    init() {
        let supportRoot = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        projectStore = JSONProjectStore(
            directory: supportRoot
                .appendingPathComponent("MixPilot Autopilot", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
        )

        connectivityMonitor.start { [weak self] status in
            Task { @MainActor [weak self] in
                self?.connectivityStatus = status
                self?.evaluatePreflight()
            }
        }
        configureMIDI()
        refreshEnvironment()
    }

    deinit {
        liveTask?.cancel()
        liveReconciliationTask?.cancel()
        audioMonitor.stop()
        connectivityMonitor.stop()
        sleepAssertion.release()
    }
}


enum SidebarSection: String, CaseIterable, Identifiable {
    case onboarding = "Configuration"
    case dashboard = "Tableau de bord"
    case studio = "Préparer"
    case mapping = "Connexion DJ"
    case preflight = "Vérifier"
    case live = "Live"
    case feasibility = "Avancé"
    case diagnostics = "Diagnostics"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .onboarding: "wand.and.stars"
        case .dashboard: "rectangle.grid.2x2"
        case .studio: "waveform.path.ecg"
        case .mapping: "slider.horizontal.3"
        case .preflight: "checkmark.shield"
        case .live: "play.circle"
        case .feasibility: "gearshape.2"
        case .diagnostics: "stethoscope"
        }
    }
}
#endif
