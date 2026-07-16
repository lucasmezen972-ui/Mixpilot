#if os(macOS)
import MixPilotCore
import SwiftUI

struct RecoveryCenterView: View {
    @StateObject private var model = RecoveryCenterModel()

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MixPilotSectionHero(
                        eyebrow: "Sécurité de session",
                        title: "Centre de récupération",
                        subtitle: "Analyse le dernier checkpoint sans envoyer automatiquement la moindre commande.",
                        symbol: "lifepreserver.fill",
                        accent: decisionColor
                    ) {
                        Button("RÉEXAMINER LE LOGICIEL DJ") { model.refresh() }
                            .buttonStyle(MixPilotPrimaryButtonStyle(accent: decisionColor))
                    }

                    MixPilotGlassCard(accent: decisionColor) {
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(decisionColor.opacity(0.14))
                                Image(systemName: decisionSymbol)
                                    .font(.system(size: 31, weight: .semibold))
                                    .foregroundStyle(decisionColor)
                            }
                            .frame(width: 64, height: 64)

                            VStack(alignment: .leading, spacing: 6) {
                                MixPilotStatusBadge(title: decisionBadge, symbol: decisionSymbol, accent: decisionColor)
                                Text(decisionTitle)
                                    .font(.system(size: 23, weight: .bold, design: .rounded))
                                Text(model.status)
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.54))
                            }
                            Spacer()
                        }
                    }

                    HStack(alignment: .top, spacing: 16) {
                        if let checkpoint = model.checkpoint {
                            MixPilotGlassCard(accent: .purple) {
                                VStack(alignment: .leading, spacing: 13) {
                                    MixPilotPanelTitle(title: "Dernier état sauvegardé", symbol: "externaldrive.badge.timemachine", subtitle: checkpoint.projectName, accent: .purple)
                                    recoveryRow("État", checkpoint.state.rawValue)
                                    recoveryRow("Morceau", "\(checkpoint.currentTrackIndex + 1)")
                                    recoveryRow("Deck actif", checkpoint.activeDeck.rawValue)
                                    recoveryRow("Transitions terminées", "\(checkpoint.completedTransitionCount)")
                                    recoveryRow("Dernière commande", checkpoint.lastCommand ?? "Aucune")
                                    recoveryRow("Sauvegardé", checkpoint.updatedAt.formatted(date: .abbreviated, time: .standard))
                                }
                            }
                        } else {
                            MixPilotGlassCard(accent: .green) {
                                VStack(alignment: .leading, spacing: 12) {
                                    MixPilotPanelTitle(title: "Aucun checkpoint", symbol: "checkmark.circle.fill", subtitle: "Aucune session interrompue à récupérer.", accent: .green)
                                    Text("Le centre reste disponible si une future session Live est interrompue.")
                                        .font(.callout)
                                        .foregroundStyle(.white.opacity(0.52))
                                }
                            }
                        }

                        if let observation = model.observation {
                            MixPilotGlassCard(accent: .cyan) {
                                VStack(alignment: .leading, spacing: 13) {
                                    MixPilotPanelTitle(title: "État observé", symbol: "eye.fill", subtitle: "Lecture uniquement", accent: .cyan)
                                    observationRow(
                                        observation.isRunning ? "Application détectée" : "Application absente",
                                        observation.isRunning,
                                        "app.badge.checkmark"
                                    )
                                    observationRow(
                                        observation.accessibilityGranted ? "Accessibilité autorisée" : "Accessibilité bloquée",
                                        observation.accessibilityGranted,
                                        "hand.raised.fill"
                                    )
                                    recoveryRow("Éléments lisibles", "\(observation.visibleText.count)")
                                }
                            }
                        }
                    }

                    MixPilotGlassCard(accent: .orange) {
                        VStack(alignment: .leading, spacing: 13) {
                            MixPilotPanelTitle(title: "Action recommandée", symbol: "signpost.right.and.left.fill", subtitle: "Décision conservatrice", accent: .orange)
                            Text(actionExplanation)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.62))
                            if model.checkpoint != nil {
                                Button("ABANDONNER CETTE ANCIENNE SESSION") {
                                    model.discardCheckpoint()
                                }
                                .buttonStyle(MixPilotDangerButtonStyle())
                            }
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 900, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 820, minHeight: 620)
        .onAppear { model.refresh() }
    }

    private func recoveryRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.46))
            Spacer()
            Text(value)
                .font(.callout.bold())
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 3)
    }

    private func observationRow(_ title: String, _ positive: Bool, _ symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: positive ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(positive ? .green : .red)
            Image(systemName: symbol).foregroundStyle(.cyan)
            Text(title).font(.callout)
            Spacer()
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

    private var decisionBadge: String {
        switch model.reconciliation?.decision {
        case .resumeAutomatically: "Reprise contrôlée"
        case .requireObservation: "À observer"
        case .requireManualConfirmation: "Action manuelle"
        case .switchToEmergency: "Mode secours"
        case .discardCompletedSession: "Session terminée"
        case nil: "Diagnostic"
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

    private var decisionColor: Color {
        switch model.reconciliation?.decision {
        case .resumeAutomatically: .green
        case .requireObservation: .cyan
        case .requireManualConfirmation: .orange
        case .switchToEmergency: .red
        case .discardCompletedSession: .green
        case nil: .purple
        }
    }

    private var actionExplanation: String {
        switch model.reconciliation?.decision {
        case .resumeAutomatically:
            "Le titre observé correspond au checkpoint. La reprise devra toutefois être confirmée depuis l’écran Live après vérification audio."
        case .requireObservation:
            "Le bon titre semble chargé, mais l’audio n’est pas confirmé. Vérifie la sortie et utilise le Préflight avant toute reprise."
        case .requireManualConfirmation:
            "Ne relance pas l’Autopilot. Replace le logiciel DJ dans un état connu ou abandonne l’ancienne session."
        case .switchToEmergency:
            "Le logiciel DJ n’est pas disponible. Lance la bibliothèque locale de secours avant toute tentative de réparation."
        case .discardCompletedSession:
            "Cette session était déjà terminée et peut être supprimée sans risque."
        case nil:
            model.checkpoint == nil ? "Aucune action n’est nécessaire." : "Inspecte le logiciel DJ et décide manuellement."
        }
    }
}
#endif
