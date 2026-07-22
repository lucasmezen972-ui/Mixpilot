#if os(macOS)
import AppKit
import Foundation
import MixPilotSystem
import SwiftUI

struct PermissionOnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var snapshot = MacPermissionSnapshot.initial
    @State private var activeRequest: MacPermissionKind?
    private let coordinator = MacPermissionCoordinator()

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MixPilotSectionHero(
                        eyebrow: "Configuration initiale",
                        title: "Autoriser uniquement ce qui améliore le Live",
                        subtitle: "MixPilot demande chaque accès séparément. Tu peux continuer en mode dégradé : aucune permission recommandée ne masque le tableau Live.",
                        symbol: "checkmark.shield.fill",
                        accent: .cyan
                    ) {
                        Button("Actualiser les statuts") { refresh() }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                    }

                    MixPilotNotice(
                        title: "Aucune demande automatique",
                        message: "Une fenêtre macOS ne s’ouvre qu’après avoir choisi Activer. Les permissions manquantes deviennent des avertissements, pas un faux blocage global.",
                        kind: .info
                    )

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 300), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(MacPermissionKind.allCases) { kind in
                            permissionCard(kind)
                        }
                    }

                    MixPilotGlassCard(accent: snapshot.allRecommendedGranted ? .green : .orange) {
                        HStack(alignment: .center, spacing: 16) {
                            Image(systemName: snapshot.allRecommendedGranted
                                  ? "checkmark.seal.fill"
                                  : "exclamationmark.triangle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(snapshot.allRecommendedGranted ? .green : .orange)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(snapshot.allRecommendedGranted
                                     ? "Autorisations recommandées prêtes"
                                     : "Mode dégradé disponible")
                                    .font(.headline)
                                Text(snapshot.allRecommendedGranted
                                     ? "Tu peux maintenant choisir le logiciel DJ à piloter."
                                     : "Tu pourras réactiver ces accès plus tard depuis l’écran du logiciel DJ.")
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                            Spacer()
                            Button(snapshot.allRecommendedGranted
                                   ? "Choisir le logiciel DJ"
                                   : "Continuer en mode dégradé") {
                                model.completeOnboarding()
                            }
                            .buttonStyle(MixPilotPrimaryButtonStyle(
                                accent: snapshot.allRecommendedGranted ? .green : .orange
                            ))
                            .disabled(activeRequest != nil)
                        }
                    }
                }
                .padding(30)
                .frame(maxWidth: 1_120, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1_020, minHeight: 700)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            refresh()
        }
    }

    private func permissionCard(_ kind: MacPermissionKind) -> some View {
        let state = snapshot[kind]
        let accent = color(for: state)

        return MixPilotGlassCard(cornerRadius: 22, padding: 20, accent: accent) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 12) {
                    Image(systemName: symbol(for: kind))
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title(for: kind)).font(.headline)
                        Text(purpose(for: kind))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.52))
                    }
                    Spacer()
                    MixPilotStatusBadge(
                        title: label(for: state),
                        symbol: statusSymbol(for: state),
                        accent: accent
                    )
                }

                Text(detail(for: kind))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.64))
                    .frame(minHeight: 54, alignment: .topLeading)

                HStack(spacing: 8) {
                    if !state.isAuthorized {
                        Button(activeRequest == kind ? "Demande en cours…" : "Activer") {
                            request(kind)
                        }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: accent))
                        .disabled(activeRequest != nil)

                        Button("Réglages Système") {
                            coordinator.openSystemSettings(for: kind)
                        }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                        .disabled(activeRequest != nil)
                    } else {
                        Label("Accès confirmé", systemImage: "checkmark.circle.fill")
                            .font(.callout.bold())
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    private func request(_ kind: MacPermissionKind) {
        guard activeRequest == nil else { return }
        activeRequest = kind
        Task { @MainActor in
            snapshot = await coordinator.request(kind)
            activeRequest = nil
            model.refreshEnvironment()
        }
    }

    private func refresh() {
        snapshot = coordinator.snapshot()
        model.refreshEnvironment()
    }

    private func title(for kind: MacPermissionKind) -> String {
        switch kind {
        case .accessibility: "Accessibilité"
        case .screenRecording: "Capture d’écran"
        case .microphone: "Microphone"
        }
    }

    private func purpose(for kind: MacPermissionKind) -> String {
        switch kind {
        case .accessibility: "Observer l’interface du logiciel DJ"
        case .screenRecording: "Lire la playlist visible par OCR"
        case .microphone: "Surveiller silence et saturation"
        }
    }

    private func detail(for kind: MacPermissionKind) -> String {
        switch kind {
        case .accessibility:
            "Permet de lire les titres, decks et contrôles visibles sans capturer tes fichiers musicaux."
        case .screenRecording:
            "Utilisée seulement lorsque la playlist Rekordbox n’est pas accessible autrement. L’OCR reste local."
        case .microphone:
            "Utilisé pour la surveillance audio locale. Le son brut n’est ni stocké ni envoyé au cloud."
        }
    }

    private func symbol(for kind: MacPermissionKind) -> String {
        switch kind {
        case .accessibility: "accessibility"
        case .screenRecording: "rectangle.dashed.badge.record"
        case .microphone: "mic.fill"
        }
    }

    private func label(for state: MacPermissionState) -> String {
        switch state {
        case .authorized: "Autorisé"
        case .actionRequired: "À activer"
        case .denied: "Refusé"
        case .restricted: "Restreint"
        }
    }

    private func statusSymbol(for state: MacPermissionState) -> String {
        switch state {
        case .authorized: "checkmark.circle.fill"
        case .actionRequired: "circle.dashed"
        case .denied: "xmark.circle.fill"
        case .restricted: "lock.fill"
        }
    }

    private func color(for state: MacPermissionState) -> Color {
        switch state {
        case .authorized: .green
        case .actionRequired: .orange
        case .denied: .red
        case .restricted: .red
        }
    }
}
#endif
