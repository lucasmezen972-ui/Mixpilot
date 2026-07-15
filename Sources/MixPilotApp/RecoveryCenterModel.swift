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
    @Published private(set) var observation: SeratoWindowObservation?
    @Published private(set) var reconciliation: CheckpointReconciliationResult?
    @Published private(set) var status = "Recherche d’une session interrompue…"
    @Published private(set) var isLoading = false

    private let checkpointStore = LiveAutopilotCoordinator.makeDefaultCheckpointStore()
    private let projectStore: JSONProjectStore
    private let accessibilityBridge = SeratoAccessibilityBridge()

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
        status = "Lecture du checkpoint et observation de Serato…"

        Task {
            do {
                let loadedCheckpoint = try await checkpointStore.load()
                let projects = try await projectStore.list()
                let loadedProject = loadedCheckpoint.flatMap { checkpoint in
                    projects.first { $0.id == checkpoint.projectID }
                }
                let currentObservation = accessibilityBridge.observe(maxDepth: 6, maximumStrings: 400)

                checkpoint = loadedCheckpoint
                project = loadedProject
                observation = currentObservation

                if let loadedCheckpoint, let loadedProject {
                    let expectedTitle = loadedProject.tracks.indices.contains(loadedCheckpoint.currentTrackIndex)
                        ? loadedProject.tracks[loadedCheckpoint.currentTrackIndex].track.title
                        : nil
                    let observedTitle = expectedTitle.flatMap { title in
                        currentObservation.contains(text: title) ? title : nil
                    }
                    reconciliation = CheckpointReconciler().reconcile(
                        checkpoint: loadedCheckpoint,
                        project: loadedProject,
                        observedTrackTitle: observedTitle,
                        seratoRunning: currentObservation.isRunning,
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
                status = "Impossible de lire la récupération : \(error.localizedDescription)"
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
                reconciliation = nil
                status = "Checkpoint supprimé. Une nouvelle session peut être lancée."
            } catch {
                status = "Impossible de supprimer le checkpoint : \(error.localizedDescription)"
            }
        }
    }
}
#endif
