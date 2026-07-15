#if os(macOS)
import Foundation
import MixPilotCore

@MainActor
extension AppModel {
    func previewLocalAudioAnalysis(
        _ localAnalysis: LocalAudioAnalysis,
        for trackID: UUID,
        capturedStartTime: TimeInterval
    ) throws -> TrackAnalysisRefinement {
        guard let project = preparedProject else {
            throw PreparationAnalysisApplicationError.noProject
        }
        guard let preparedTrack = project.tracks.first(where: { $0.id == trackID }) else {
            throw PreparationAnalysisApplicationError.trackNotFound
        }

        return TrackAnalysisRefiner().refine(
            track: preparedTrack.track,
            existing: preparedTrack.analysis,
            local: localAnalysis,
            capturedStartTime: capturedStartTime
        )
    }
}

enum PreparationAnalysisApplicationError: Error, LocalizedError {
    case noProject
    case trackNotFound

    var errorDescription: String? {
        switch self {
        case .noProject: "Aucun projet n’est préparé."
        case .trackNotFound: "Le morceau sélectionné n’existe plus dans le projet."
        }
    }
}
#endif
