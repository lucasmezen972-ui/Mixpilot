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
                        subtitle: "Compare le dernier checkpoint à l’état réellement observé avant toute tentative de reprise.",
                        symbol: "lifepreserver.fill",
                        accent: decisionColor
                    ) {
                        Button("RÉEXAMINER") { model.refresh() }
                            .buttonStyle(MixPilotPrimaryButtonStyle(accent: decisionColor))
                    }

                    decisionCard

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 16)], spacing: 16) {
                        checkpointCard
                        observationCard
                    }

                    MixPilotGlassCard(accent: .orange, elevation: .elevated) {
                        VStack(alignment: .leading, spacing: 14) {
                            MixPilotPanelTitle(
                                title: "Action recommandée",
                                symbol: "signpost.right.and.left.fill",
                                subtitle: "Décision conservatrice et réversible",
                                accent: .orange
                            )

                            MixPilotNotice(
                                title: decisionBadge,
                                message: actionExplanation,
                                kind: noticeKind
                            )

                            if model.checkpoint != nil {
                                HStack(spacing: 10) {
                                    Button("ABANDONNER L’ANCIENNE SESSION") {
                                        model.discardCheckpoint()
                                    }
                                    .buttonStyle(MixPilotDangerButtonStyle())

                                    Button("RÉEXAMINER LE LOGICIEL DJ") {
                                        model.refresh()
                                    }
                                    .buttonStyle(MixPilotSecondaryButtonStyle())
                                }
                            }
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 980, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .mixPilotWindowSurface(minWidth: 860, minHeight: 650)
        .onAppear { model.refresh() }
    }

    private var decisionCard: some View {
        MixPilotGlassCard(accent: decisionColor, elevation: .elevated) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(decisionColor.opacity(0.13))
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(decisionColor.opacity(0.25), lineWidth: 1)
                    Image(systemName: decisionSymbol)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(decisionColor)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 7) {
                    MixPilotStatusBadge(title: decisionBadge, symbol: decisionSymbol, accent: decisionColor)
                    Text(decisionTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .tracking(-0.25)
                    Text(model.status)
                        .font(.callout)
                        .foregroundStyle(MixPilotPalette.textSecondary)
                        .lineSpacing(2)
                }
                Spacer(minLength: 12)
            }
        }
    }

    @ViewBuilder
    private var checkpointCard: some View {
        if let checkpoint = model.checkpoint {
            MixPilotGlassCard(accent: .purple) {
                VStack(alignment: .leading, spacing: 14) {
                    MixPilotPanelTitle(
                        title: "Dernier état sauvegardé",
                        symbol: "externaldrive.badge.timemachine",
                        subtitle: checkpoint.projectName,
                        accent: .purple
                    )
                    MixPilotSectionDivider(accent: .purple)
                    MixPilotKeyValueRow(label: "État", value: checkpoint.state.rawValue, accent: .purple, symbol: "waveform.path")
                    MixPilotKeyValueRow(label: "Morceau", value: "\(checkpoint.currentTrackIndex + 1)", accent: .purple, symbol: "music.note")
                    MixPilotKeyValueRow(label: "Deck actif", value: checkpoint.activeDeck.rawValue, accent: .purple, symbol: "record.circle")
                    MixPilotKeyValueRow(label: "Transitions terminées", value: "\(checkpoint.completedTransitionCount)", accent: .purple, symbol: "arrow.left.arrow.right")
                    MixPilotKeyValueRow(label: "Dernière commande", value: checkpoint.lastCommand ?? "Aucune", accent: .purple, symbol: "terminal")
                    MixPilotKeyValueRow(label: "Sauvegardé", value: checkpoint.updatedAt.formatted(date: .abbreviated, time: .standard), accent: .purple, symbol: "clock")
                }
            }
        } else {
            MixPilotEmptyState(
                title: "Aucune session interrompue",
                message: "Aucun checkpoint n’attend une reprise. Le centre restera disponible si une future session Live est interrompue.",
                symbol: "checkmark.shield.fill",
                accent: .green
            )
        }
    }

    @ViewBuilder
    private var observationCard: some View {
        if let observation = model.observation {
            MixPilotGlassCard(accent: .cyan) {
                VStack(alignment: .leading, spacing: 14) {
                    MixPilotPanelTitle(
                        title: "État observé",
                        symbol: "eye.fill",
                        subtitle: "Lecture uniquement — aucune commande envoyée",
                        accent: .cyan
                    )
                    MixPilotSectionDivider(accent: .cyan)
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
                    MixPilotKeyValueRow(
                        label: "Éléments lisibles",
                        value: "\(observation.visibleText.count)",
                        accent: .cyan,
                        symbol: "text.viewfinder"
                    )
                }
            }
        } else {
            MixPilotEmptyState(
                title: "Observation indisponible",
                message: "Lance un réexamen pour lire l’état du logiciel DJ et des permissions système.",
                symbol: "eye.slash.fill",
                accent: .orange
            ) {
                Button("RÉEXAMINER") { model.refresh() }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .orange))
            }
        }
    }

    private func observationRow(_ title: String, _ positive: Bool, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((positive ? Color.green : Color.red).opacity(0.12))
                Image(systemName: positive ? "checkmark" : "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(positive ? .green : .red)
            }
            .frame(width: 25, height: 25)
            Image(systemName: symbol)
                .foregroundStyle(.cyan)
                .frame(width: 18)
            Text(title)
                .font(.callout.weight(.medium))
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var noticeKind: MixPilotNotice.Kind {
        switch model.reconciliation?.decision {
        case .resumeAutomatically, .discardCompletedSession: .success
        case .requireObservation: .info
        case .requireManualConfirmation: .warning
        case .switchToEmergency: .danger
        case nil: model.checkpoint == nil ? .success : .warning
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