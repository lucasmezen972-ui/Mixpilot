#if os(macOS)
import MixPilotCore
import SwiftUI

struct DJSoftwareSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    MixPilotSectionHero(
                        eyebrow: "Ton environnement DJ",
                        title: "Choisir le logiciel à piloter",
                        subtitle: "djay Pro, rekordbox et Serato DJ Pro sont trois backends officiels. MixPilot adapte ensuite les transitions aux fonctions réellement disponibles.",
                        symbol: "music.note.house.fill",
                        accent: .cyan
                    ) {
                        Button("Actualiser") { model.refreshEnvironment() }
                            .buttonStyle(MixPilotSecondaryButtonStyle())
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 300), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(DJBackendIdentifier.allCases) { backend in
                            backendCard(backend)
                        }
                    }

                    MixPilotGlassCard(accent: .cyan) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.cyan)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Même importance, capacités différentes")
                                    .font(.headline)
                                Text("Être officiellement pris en charge ne signifie pas que toutes les commandes sont identiques. MixPilot vérifie la version, le mapping et les tests réalisés sur ce Mac avant d’autoriser le Live.")
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                            Spacer()
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
        .onAppear { model.refreshEnvironment() }
    }

    private func backendCard(_ backend: DJBackendIdentifier) -> some View {
        let descriptor = model.backendDescriptors.first { $0.identifier == backend }
        let selected = model.selectedBackend == backend
        let accent = color(for: backend)
        let environment = descriptor?.environment
        let capabilities = descriptor?.capabilities ?? DJBackendCapabilities()
        let readyCount = DJCapability.allCases.filter { capabilities[$0].isVerifiedForLive }.count
        let availableCount = DJCapability.allCases.filter { capabilities[$0].canBePlanned }.count
        let missing = configurationSummary(backend, descriptor: descriptor)

        return MixPilotGlassCard(cornerRadius: 22, padding: 20, accent: accent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(accent.opacity(0.14))
                        Image(systemName: symbol(for: backend))
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(backend.displayName)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                        Text(productSubtitle(for: backend))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.52))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: selected ? "checkmark.seal.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected ? accent : .white.opacity(0.24))
                }

                HStack(spacing: 8) {
                    MixPilotStatusBadge(
                        title: installationLabel(environment),
                        symbol: environment?.isInstalled == true ? "checkmark.circle.fill" : "arrow.down.circle",
                        accent: environment?.isInstalled == true ? .green : .orange
                    )
                    if let version = environment?.softwareVersion {
                        MixPilotStatusBadge(title: "Version \(version)", symbol: "number", accent: .blue)
                    }
                }

                Text(modeDescription(for: backend))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.66))
                    .frame(minHeight: 42, alignment: .topLeading)

                VStack(spacing: 9) {
                    capabilityRow("Préparation du set", available: true, accent: accent)
                    capabilityRow(
                        backend == .djay ? "Automix supervisé" : "Contrôle des decks",
                        available: backend == .djay
                            ? capabilities[.automix].canBePlanned
                            : capabilities[.playPause].canBePlanned,
                        accent: accent
                    )
                    capabilityRow("Lecture de la bibliothèque", available: capabilities[.libraryReading].canBePlanned, accent: accent)
                    capabilityRow("Reprise manuelle", available: true, accent: accent)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("COMPATIBILITÉ")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.36))
                        Text("\(readyCount) validées • \(availableCount) disponibles")
                            .font(.caption.bold())
                    }
                    Spacer()
                    Text(environment?.isRunning == true ? "Connecté" : "À vérifier")
                        .font(.caption.bold())
                        .foregroundStyle(environment?.isRunning == true ? .green : .orange)
                }
                .padding(11)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 4) {
                    Text(missing.title)
                        .font(.caption.bold())
                        .foregroundStyle(missing.ready ? .green : .orange)
                    Text(missing.detail)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 45, alignment: .topLeading)

                HStack(spacing: 8) {
                    Button("Configurer") {
                        model.selectBackend(backend)
                        model.selectedSection = .mapping
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())

                    Button("Tester") {
                        model.selectBackend(backend)
                        model.refreshEnvironment()
                        model.evaluatePreflight()
                        model.selectedSection = .preflight
                    }
                    .buttonStyle(MixPilotSecondaryButtonStyle())

                    Button(selected ? "Utilisé" : "Utiliser") {
                        model.selectBackend(backend)
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: accent))
                    .disabled(selected || model.isLiveRunning)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if selected {
                Text("ACTIF")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.12), in: Capsule())
                    .padding(13)
            }
        }
    }

    private func capabilityRow(_ title: String, available: Bool, accent: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: available ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(available ? accent : .white.opacity(0.28))
            Text(title)
                .font(.caption)
                .foregroundStyle(available ? .white.opacity(0.72) : .white.opacity(0.4))
            Spacer()
        }
    }

    private func installationLabel(_ environment: DJBackendEnvironment?) -> String {
        guard let environment else { return "Non vérifié" }
        if !environment.isInstalled { return "Non installé" }
        return environment.isRunning ? "Ouvert" : "Installé"
    }

    private func configurationSummary(
        _ backend: DJBackendIdentifier,
        descriptor: DJBackendDescriptor?
    ) -> (title: String, detail: String, ready: Bool) {
        guard let descriptor else {
            return ("Vérification nécessaire", "MixPilot n’a pas encore analysé ce logiciel sur ce Mac.", false)
        }
        if !descriptor.environment.isInstalled {
            return ("Logiciel non installé", "Installe \(backend.displayName), puis relance la vérification.", false)
        }
        if !descriptor.environment.isRunning {
            return ("Lance le logiciel", "Ouvre \(backend.displayName) pour tester la connexion et la version.", false)
        }
        let critical: [DJCapability] = backend == .djay
            ? [.automix, .trackStateReading]
            : [.trackLoading, .playPause, .channelVolume]
        let pending = critical.filter { !descriptor.capabilities[$0].isVerifiedForLive }
        if pending.isEmpty {
            return ("Configuration prête", "Les fonctions critiques déclarées ont été validées pour cette configuration.", true)
        }
        return (
            "\(pending.count) test(s) à terminer",
            "MixPilot adaptera les transitions, mais le Live complet restera bloqué tant que les commandes critiques ne sont pas confirmées.",
            false
        )
    }

    private func productSubtitle(for backend: DJBackendIdentifier) -> String {
        switch backend {
        case .djay: "Autopilote natif et contrôle avancé"
        case .rekordbox: "Mode Performance et installations professionnelles"
        case .serato: "Contrôle MIDI avec configuration guidée"
        }
    }

    private func modeDescription(for backend: DJBackendIdentifier) -> String {
        switch backend {
        case .djay:
            "Mode Automix supervisé ou transitions MixPilot directes selon les commandes validées."
        case .rekordbox:
            "Import de bibliothèque, preset MIDI contrôlé et parcours Mode Performance."
        case .serato:
            "Contrôleur virtuel, mapping sauvegardé et validation commande par commande."
        }
    }

    private func symbol(for backend: DJBackendIdentifier) -> String {
        switch backend {
        case .djay: "wand.and.stars.inverse"
        case .rekordbox: "record.circle"
        case .serato: "music.note.list"
        }
    }

    private func color(for backend: DJBackendIdentifier) -> Color {
        switch backend {
        case .djay: .cyan
        case .rekordbox: .blue
        case .serato: .purple
        }
    }
}
#endif
