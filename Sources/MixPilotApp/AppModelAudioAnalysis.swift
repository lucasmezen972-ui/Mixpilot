#if os(macOS)
import Foundation
import MixPilotCore

@MainActor
extension AppModel {
    func applyLocalAudioAnalysis(
        _ localAnalysis: LocalAudioAnalysis,
        to trackID: UUID,
        capturedStartTime: TimeInterval
    ) throws -> TrackAnalysisRefinement {
        guard var project = preparedProject else {
            throw PreparationAnalysisApplicationError.noProject
        }
        guard !project.locked else {
            throw PreparationAnalysisApplicationError.projectLocked
        }
        guard let index = project.tracks.firstIndex(where: { $0.id == trackID }) else {
            throw PreparationAnalysisApplicationError.trackNotFound
        }

        let current = project.tracks[index]
        let refinement = TrackAnalysisRefiner().refine(
            track: current.track,
            existing: current.analysis,
            local: localAnalysis,
            capturedStartTime: capturedStartTime
        )
        project.tracks[index] = PreparedTrack(
            track: refinement.track,
            analysis: refinement.analysis
        )
        project.transitions = TransitionPlanner().planSet(project.tracks.map(\.track))
        project.updatedAt = Date()
        preparedProject = project
        optimizationReport = SetOptimizer().analyze(tracks: project.tracks.map(\.track))
        runtimeStatus = "Analyse locale appliquée à \(refinement.track.title)"
        return refinement
    }
}

enum PreparationAnalysisApplicationError: Error, LocalizedError {
    case noProject
    case projectLocked
    case trackNotFound

    var errorDescription: String? {
        switch self {
        case .noProject: "Aucun projet n’est préparé."
        case .projectLocked: "Déverrouille ou duplique le projet avant de modifier son analyse."
        case .trackNotFound: "Le morceau sélectionné n’existe plus dans le projet."
        }
    }
}
#endif
