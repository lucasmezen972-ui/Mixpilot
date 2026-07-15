#if os(macOS)
import MixPilotCore
import SwiftUI

struct RecoveryCenterView: View {
    @StateObject private var model = RecoveryCenterModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Centre de récupération").font(.largeTitle.bold())
                        Text("Aucune commande n’est envoyée automatiquement depuis cet écran.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Réexaminer Serato") { model.refresh() }
                        .buttonStyle(.borderedProminent)
                }

                GroupBox("Diagnostic") {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: decisionSymbol).font(.largeTitle)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(decisionTitle).font(.title2.bold())
                            Text(model.status).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                }

                if let checkpoint = model.checkpoint {
                    GroupBox("Dernier état sauvegardé") {
                        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 9) {
                            recoveryRow("Projet", checkpoint.projectName)
                            recoveryRow("État", checkpoint.state.rawValue)
                            recoveryRow("Morceau", "\(checkpoint.currentTrackIndex + 1)")
                            recoveryRow("Deck actif", checkpoint.activeDeck.rawValue)
                            recoveryRow("Transitions terminées", "\(checkpoint.completedTransitionCount)")
                            recoveryRow("Dernière commande", checkpoint.lastCommand ?? "Aucune")
                            recoveryRow("Sauvegardé", checkpoint.updatedAt.formatted(date: .abbreviated, time: .standard))
                        }
                        .padding(8)
                    }
                }

                if let observation = model.observation {
                    GroupBox("État observé") {
                        HStack(spacing: 22) {
                            Label(
                                observation.isRunning ? "Serato lancé" : "Serato absent",
                                systemImage: observation.isRunning ? "checkmark.circle" : "xmark.circle"
                            )
                            Label(
                                observation.accessibilityGranted ? "Accessibilité autorisée" : "Accessibilité bloquée",
                                systemImage: observation.accessibilityGranted ? "hand.thumbsup" : "hand.raised.slash"
                            )
                            Text("\(observation.visibleText.count) éléments lisibles")
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }
                }

                GroupBox("Action recommandée") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(actionExplanation)
                        if model.checkpoint != nil {
                            Button("Abandonner cette ancienne session", role: .destructive) {
                                model.discardCheckpoint()
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .padding(28)
        }
        .frame(minWidth: 760, minHeight: 560)
        .onAppear { model.refresh() }
    }

    @ViewBuilder
    private func recoveryRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).fontWeight(.medium)
        }
    }

    private var decisionTitle: String {
        switch model.reconciliation?.decision {
        case .resumeAutomatically: "Reprise techniquement possible"
        case .requireObservation: "Observation supplémentaire nécessaire"
        case .requireManualConfirmation: "Contrôle manuel obligatoire"
        case .switchToEmergency: "Secours local recommandé"
        case .discardCompletedSession: "Ancienne session terminée"
        case nil: model.checkpoint == nil ? "Aucune récupération nécessaire" : "État indéterminé"
        }
    }

    private var decisionSymbol: String {
        switch model.reconciliation?.decision {
        case .resumeAutomatically: "arrow.clockwise.circle.fill"
        case .requireObservation: "eye.circle.fill"
        case .requireManualConfirmation: "hand.raised.circle.fill"
        case .switchToEmergency: "lifepreserver.fill"
        case .discardCompletedSession: "checkmark.circle.fill"
        case nil: "questionmark.circle"
        }
    }

    private var actionExplanation: String {
        switch model.reconciliation?.decision {
        case .resumeAutomatically:
            "Le titre observé correspond au checkpoint. La reprise devra toutefois être confirmée depuis l’écran Live après vérification audio."
        case .requireObservation:
            "Le bon titre semble chargé, mais l’audio n’est pas confirmé. Vérifie la sortie et utilise le préflight avant toute reprise."
        case .requireManualConfirmation:
            "Ne relance pas l’Autopilot. Replace Serato dans un état connu ou abandonne l’ancienne session."
        case .switchToEmergency:
            "Serato n’est pas disponible. Lance la bibliothèque locale de secours avant toute tentative de réparation."
        case .discardCompletedSession:
            "Cette session était déjà terminée et peut être supprimée sans risque."
        case nil:
            model.checkpoint == nil ? "Aucune action n’est nécessaire." : "Inspecte Serato et décide manuellement."
        }
    }
}
#endif
