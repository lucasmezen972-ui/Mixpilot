#if os(macOS)
import Combine
import Foundation
import MixPilotCore
import MixPilotRuntime
import MixPilotSystem

@MainActor
final class RecoveryCenterModel: ObservableObject {
    @Published private(set) var checkpoint: LiveCheckpoint?
    @Published private(set) var project: SetProject?
    @Published private(set) var observation: DJWindowObservation?
    @Published private(set) var reconciliation: CheckpointReconciliationResult?
    @Published private(set) var status = "Recherche d’une session interrompue…"
    @Published private(set) var isLoading = false

    private let checkpointStore = LiveAutopilotCoordinator.makeDefaultCheckpointStore()
    private let projectStore: JSONProjectStore
    private let accessibilityBridge = DJAccessibilityBridge()

    init() {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        projectStore = JSONProjectStore(
            directory: root
                .appendingPathComponent("MixPilot Autopilot", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
        )
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        status = "Lecture du checkpoint et vérification du logiciel DJ…"

        Task {
            do {
                let loadedCheckpoint = try await checkpointStore.load()
                let projects = try await projectStore.list()
                let loadedProject = loadedCheckpoint.flatMap { checkpoint in
                    projects.first { $0.id == checkpoint.projectID }
                }
                let recordedBackend = loadedCheckpoint?.backend ?? loadedProject?.backend
                let currentObservation = recordedBackend.map {
                    accessibilityBridge.observe(
                        backend: $0,
                        maxDepth: 6,
                        maximumStrings: 400
                    )
                }

                checkpoint = loadedCheckpoint
                project = loadedProject
                observation = currentObservation

                if let loadedCheckpoint, let loadedProject {
                    let expectedTitle = loadedProject.tracks.indices.contains(
                        loadedCheckpoint.currentTrackIndex
                    ) ? loadedProject.tracks[loadedCheckpoint.currentTrackIndex].track.title : nil
                    let observedTitle = expectedTitle.flatMap { title in
                        currentObservation?.contains(text: title) == true ? title : nil
                    }
                    reconciliation = CheckpointReconciler().reconcile(
                        checkpoint: loadedCheckpoint,
                        project: loadedProject,
                        activeBackend: recordedBackend,
                        backendRunning: currentObservation?.isRunning == true,
                        observedTrackTitle: observedTitle,
                        audioActive: false
                    )
                    status = reconciliation?.explanation ?? "État à vérifier"
                } else if loadedCheckpoint != nil {
                    reconciliation = nil
                    status = "Le checkpoint existe, mais son projet sauvegardé est introuvable. Contrôle manuel obligatoire."
                } else {
                    reconciliation = nil
                    status = "Aucune session interrompue n’a été détectée."
                }
            } catch {
                checkpoint = nil
                project = nil
                observation = nil
                reconciliation = nil
                status = "La récupération locale n’a pas pu être lue. Aucun redémarrage automatique n’est autorisé."
            }
            isLoading = false
        }
    }

    func discardCheckpoint() {
        Task {
            do {
                try await checkpointStore.clear()
                checkpoint = nil
                project = nil
                observation = nil
                reconciliation = nil
                status = "Checkpoint supprimé. Une nouvelle session peut être lancée."
            } catch {
                status = "Le checkpoint n’a pas pu être supprimé. Aucune reprise automatique ne sera tentée."
            }
        }
    }
}
#endif
