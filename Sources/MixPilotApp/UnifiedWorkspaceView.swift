#if os(macOS)
import MixPilotCore
import SwiftUI

struct UnifiedWorkspaceView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var pendingCommandValidation: DJControlAction?

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()
            ScrollView {
                content
                    .padding(28)
                    .padding(.bottom, 110)
                    .frame(maxWidth: 1_180, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch primaryArea {
        case .prepare:
            prepareView
        case .verify:
            verifyView
        case .live:
            liveView
        case .advanced:
            advancedView
        }
    }

    private var primaryArea: PrimaryWorkspaceArea {
        switch model.selectedSection {
        case .live:
            .live
        case .preflight, .mapping:
            .verify
        case .feasibility, .diagnostics:
            .advanced
        case .onboarding, .dashboard, .studio:
            .prepare
        }
    }

    private var prepareView: some View {
        VStack(alignment: .leading, spacing: 22) {
            MixPilotSectionHero(
                eyebrow: "Préparer",
                title: "Construire un set fiable",
                subtitle: "Choisis ton logiciel DJ, importe une playlist, vérifie l’ordre et prépare des transitions adaptées aux capacités réellement disponibles.",
                symbol: "waveform.path.ecg",
                accent: .purple
            ) {
                Button("Choisir le logiciel") { openWindow(id: "dj-software") }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                Button("Set de démonstration") { model.createDemoProject() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                Button("Importer la playlist") { model.capturePlaylist() }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                    .disabled(model.selectedBackend == nil)
            }

            backendSummary

            if let project = model.preparedProject {
                projectSummary(project)
                transitionList(project)
                HStack(spacing: 10) {
                    Button(project.locked ? "Plan verrouillé" : "Verrouiller le plan") {
                        model.lockPreparedProject()
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: project.locked ? .green : .cyan))
                    .disabled(project.locked)

                    Button("Tester une transition") { openWindow(id: "rehearsal") }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    Button("Affiner l’analyse audio") { openWindow(id: "preparation-analysis") }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                    Button("Passer à Vérifier") {
                        model.evaluatePreflight()
                        model.selectedSection = .preflight
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                }
            } else {
                emptyCard(
                    title: "Aucun set préparé",
                    message: "Importe la playlist visible dans ton logiciel DJ ou utilise le set de démonstration. MixPilot ne lance aucune commande pendant cette étape.",
                    symbol: "music.note.list"
                )
            }
        }
    }

    private var verifyView: some View {
        VStack(alignment: .leading, spacing: 22) {
            MixPilotSectionHero(
                eyebrow: "Vérifier",
                title: "Contrôler le système avant le Live",
                subtitle: "Chaque blocage explique ce qui ne fonctionne pas, son impact et l’action à effectuer. Internet et les services en ligne ne bloquent jamais un set local déjà préparé.",
                symbol: "checkmark.shield.fill",
                accent: model.preflightReport.canStartLive ? .green : .orange
            ) {
                Button("Actualiser") { model.refreshEnvironment() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                Button("Configurer le logiciel") { openWindow(id: "dj-software") }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .cyan))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 14)], spacing: 14) {
                verificationTile("Logiciel DJ", model.backendStatus, "music.note.list", .purple)
                verificationTile("Commandes", model.midiStatus, "slider.horizontal.3", .blue)
                verificationTile("Lecture de l’état", model.accessibilityStatus, "eye.fill", .cyan)
                verificationTile("Audio", model.audioStatus, "waveform", .mint)
                verificationTile("Musique de secours", model.emergencyStatus, "lifepreserver.fill", .orange)
                verificationTile(
                    "Rapport final",
                    model.preflightReport.canStartLive ? "Prêt pour le Live" : "\(model.preflightReport.failedItems.count) blocage(s)",
                    "checkmark.seal.fill",
                    model.preflightReport.canStartLive ? .green : .red
                )
            }

            HStack(spacing: 10) {
                Button("Autoriser la lecture de l’interface") { model.requestAccessibility() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                Button(model.audioMonitor.isRunning ? "Audio actif" : "Démarrer la surveillance audio") {
                    model.startAudioMonitoring()
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                .disabled(model.audioMonitor.isRunning)
                Button("Choisir la musique de secours") { model.selectEmergencyAudio() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
            }

            criticalCommandTester

            VStack(spacing: 10) {
                ForEach(model.preflightReport.items) { item in
                    preflightRow(item)
                }
            }

            HStack {
                Spacer()
                Button("Ouvrir le Live") { model.selectedSection = .live }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                    .disabled(!model.preflightReport.canStartLive)
            }
        }
    }

    private var criticalCommandTester: some View {
        MixPilotGlassCard(accent: pendingCommandValidation == nil ? .blue : .orange) {
            VStack(alignment: .leading, spacing: 13) {
                MixPilotPanelTitle(
                    title: "Tests réels des commandes critiques",
                    symbol: "button.programmable",
                    subtitle: "Envoie une commande, observe le logiciel DJ, puis enregistre uniquement le résultat réellement constaté.",
                    accent: pendingCommandValidation == nil ? .blue : .orange
                )
                HStack(spacing: 10) {
                    commandTestButton("Tester Load", action: .loadA)
                    commandTestButton("Tester Play / Pause", action: .playA)
                    commandTestButton("Tester le volume", action: .volumeA)
                }
                if let action = pendingCommandValidation {
                    MixPilotNotice(
                        title: "Réaction à confirmer",
                        message: "Commande \(action.rawValue) envoyée. Vérifie le deck 1 dans \(model.selectedBackend?.displayName ?? "le logiciel DJ").",
                        kind: .warning
                    )
                    HStack(spacing: 10) {
                        Button("RÉACTION VALIDÉE") {
                            model.recordMappingValidation(action, succeeded: true)
                            pendingCommandValidation = nil
                        }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                        Button("ÉCHEC") {
                            model.recordMappingValidation(action, succeeded: false)
                            pendingCommandValidation = nil
                        }
                        .buttonStyle(MixPilotDangerButtonStyle())
                    }
                }
            }
        }
    }

    private func commandTestButton(_ title: String, action: DJControlAction) -> some View {
        Button(title) {
            model.testMapping(action)
            pendingCommandValidation = action
        }
        .buttonStyle(MixPilotSecondaryButtonStyle())
        .disabled(model.selectedBackend == nil || pendingCommandValidation != nil)
    }

    private var liveView: some View {
        VStack(alignment: .leading, spacing: 22) {
            MixPilotSectionHero(
                eyebrow: "Live",
                title: model.isLiveRunning ? "Autopilote en cours" : "Prêt à lancer le Live",
                subtitle: "Le Mac reste la source de vérité. Un problème de services en ligne ou de connexion iPhone ne coupe jamais la musique.",
                symbol: "play.circle.fill",
                accent: model.isLiveRunning ? .green : .cyan
            ) {
                Button(model.liveArmed ? "Désarmer" : "Armer le Live") { model.armLive() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                    .disabled(model.isLiveRunning || !model.preflightReport.canStartLive)
                Button("Lancer le Live") { model.startLive() }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                    .disabled(!model.liveArmed || model.isLiveRunning)
                Button("Reprendre la main", role: .destructive) { model.takeManualControl() }
                    .buttonStyle(MixPilotDangerButtonStyle())
                    .disabled(!model.isLiveRunning)
            }

            backendSummary

            HStack(alignment: .top, spacing: 16) {
                MixPilotGlassCard(accent: .green) {
                    VStack(alignment: .leading, spacing: 12) {
                        MixPilotPanelTitle(
                            title: "En cours",
                            symbol: "speaker.wave.2.fill",
                            subtitle: model.snapshot.statusMessage,
                            accent: .green
                        )
                        Text(model.snapshot.currentTrack?.title ?? "Aucun morceau")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                        Text(model.snapshot.currentTrack?.artist ?? "")
                            .foregroundStyle(.white.opacity(0.55))
                        ProgressView(value: model.snapshot.progress).tint(.green)
                        Text("Deck \(model.snapshot.activeDeck.rawValue) • \(model.snapshot.completedTransitions)/\(model.snapshot.totalTransitions) transitions")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                MixPilotGlassCard(accent: .cyan) {
                    VStack(alignment: .leading, spacing: 12) {
                        MixPilotPanelTitle(
                            title: "Ensuite",
                            symbol: "forward.end.fill",
                            subtitle: "Plan préparé sur le Mac",
                            accent: .cyan
                        )
                        Text(model.snapshot.nextTrack?.title ?? "Fin du set")
                            .font(.title2.bold())
                        Text(model.audioStatus)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.58))
                        Text(model.runtimeStatus)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
            }

            if !model.runtimeEvents.isEmpty {
                MixPilotGlassCard(accent: .orange) {
                    VStack(alignment: .leading, spacing: 8) {
                        MixPilotPanelTitle(
                            title: "Événements récents",
                            symbol: "list.bullet.rectangle",
                            subtitle: "Les données musicales restent locales.",
                            accent: .orange
                        )
                        ForEach(Array(model.runtimeEvents.suffix(8).enumerated()), id: \.offset) { _, event in
                            Text(event)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                }
            }
        }
    }

    private var advancedView: some View {
        VStack(alignment: .leading, spacing: 22) {
            MixPilotSectionHero(
                eyebrow: "Avancé",
                title: "Diagnostics et outils techniques",
                subtitle: "Ces outils ne sont pas nécessaires au parcours normal. Ils servent à valider une version, inspecter un mapping ou préparer un rapport technique.",
                symbol: "gearshape.2.fill",
                accent: .orange
            ) {
                Button("Exporter un diagnostic") { model.exportDiagnostics() }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .orange))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                advancedCard("Choix et capacités", "Comparer les trois backends officiels.", "music.note.house.fill") {
                    openWindow(id: "dj-software")
                }
                advancedCard("Répétition", "Mesurer et comparer les variantes de transition.", "repeat.circle.fill") {
                    openWindow(id: "rehearsal")
                }
                advancedCard("Inspecteur de transitions", "Voir les courbes, risques et recommandations.", "waveform.path") {
                    openWindow(id: "transition-inspector")
                }
                advancedCard("Analyse audio locale", "Affiner un morceau sans conserver l’audio brut.", "waveform.badge.magnifyingglass") {
                    openWindow(id: "preparation-analysis")
                }
                advancedCard("Centre de récupération", "Examiner le dernier checkpoint sans reprise aveugle.", "arrow.counterclockwise.circle.fill") {
                    openWindow(id: "recovery-center")
                }
                backendAdvancedCard
            }

            MixPilotGlassCard(accent: .blue) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Simulation du moteur")
                            .font(.headline)
                        Text("Une simulation valide le code et les scénarios de panne. Elle ne remplace jamais un test sur le logiciel et le matériel réels.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Button(model.isRunningSimulation ? "Simulation…" : "Simuler 50 titres") {
                        model.runSimulation()
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .blue))
                    .disabled(model.isRunningSimulation)
                }
            }
        }
    }

    private var backendSummary: some View {
        MixPilotGlassCard(accent: .cyan) {
            HStack(spacing: 14) {
                Image(systemName: "music.note.house.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.selectedBackend?.displayName ?? "Aucun logiciel DJ sélectionné")
                        .font(.headline)
                    Text(model.backendStatus)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Button("Changer") { openWindow(id: "dj-software") }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                    .disabled(model.isLiveRunning)
            }
        }
    }

    private var backendAdvancedCard: some View {
        Group {
            switch model.selectedBackend {
            case .rekordbox:
                advancedCard("Outils rekordbox", "CSV MIDI, validation réelle et provenance.", "record.circle") {
                    openWindow(id: "rekordbox-hub")
                }
            case .serato:
                advancedCard("Configuration Serato", "Installation, sauvegarde et restauration du mapping.", "slider.horizontal.3") {
                    openWindow(id: "automatic-serato-mapping")
                }
            case .djay:
                advancedCard("Inspection djay", "Observer Automix et l’interface validée sans inventer de commande.", "wand.and.stars") {
                    model.selectedSection = .feasibility
                }
            case nil:
                advancedCard("Backend non sélectionné", "Choisis le logiciel DJ avant d’ouvrir ses outils.", "questionmark.circle") {
                    openWindow(id: "dj-software")
                }
            }
        }
    }

    private func projectSummary(_ project: SetProject) -> some View {
        MixPilotGlassCard(accent: project.locked ? .green : .purple) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.name).font(.title2.bold())
                    Text("\(project.tracks.count) morceaux • \(project.transitions.count) transitions • \(project.reviewTransitionCount) à revoir")
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                MixPilotStatusBadge(
                    title: project.locked ? "Plan verrouillé" : "Brouillon",
                    symbol: project.locked ? "lock.fill" : "lock.open",
                    accent: project.locked ? .green : .orange
                )
            }
        }
    }

    private func transitionList(_ project: SetProject) -> some View {
        MixPilotGlassCard(accent: .cyan) {
            VStack(alignment: .leading, spacing: 10) {
                MixPilotPanelTitle(
                    title: "Plan des transitions",
                    symbol: "arrow.left.arrow.right",
                    subtitle: "Le moteur choisira uniquement des variantes exécutables.",
                    accent: .cyan
                )
                ForEach(Array(project.transitions.prefix(12).enumerated()), id: \.element.id) { index, transition in
                    HStack {
                        Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.cyan).frame(width: 24)
                        Text(transition.kind.rawValue).font(.callout.bold())
                        Spacer()
                        Text("\(transition.bars) mesures • confiance \(transition.confidence) %")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    private func verificationTile(
        _ title: String,
        _ value: String,
        _ symbol: String,
        _ accent: Color
    ) -> some View {
        MixPilotGlassCard(cornerRadius: 16, padding: 15, accent: accent) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol).foregroundStyle(accent)
                Text(title).font(.caption.bold()).foregroundStyle(.white.opacity(0.48))
                Text(value).font(.headline).lineLimit(3)
            }
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        }
    }

    private func preflightRow(_ item: PreflightItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: preflightSymbol(item.status))
                .foregroundStyle(preflightColor(item.status))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline)
                Text(item.detail).font(.callout).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private func advancedCard(
        _ title: String,
        _ detail: String,
        _ symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MixPilotGlassCard(cornerRadius: 17, padding: 16, accent: .orange) {
                HStack(spacing: 13) {
                    Image(systemName: symbol).font(.title2).foregroundStyle(.orange).frame(width: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline)
                        Text(detail).font(.caption).foregroundStyle(.white.opacity(0.52)).multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            }
        }
        .buttonStyle(.plain)
    }

    private func emptyCard(title: String, message: String, symbol: String) -> some View {
        MixPilotGlassCard(accent: .purple) {
            VStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 46)).foregroundStyle(.purple)
                Text(title).font(.title2.bold())
                Text(message).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center).frame(maxWidth: 580)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        }
    }

    private func preflightSymbol(_ status: PreflightItemStatus) -> String {
        switch status {
        case .passed: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .notTested: "questionmark.circle.fill"
        }
    }

    private func preflightColor(_ status: PreflightItemStatus) -> Color {
        switch status {
        case .passed: .green
        case .warning: .orange
        case .failed: .red
        case .notTested: .gray
        }
    }
}

enum PrimaryWorkspaceArea: String, CaseIterable, Identifiable {
    case prepare = "Préparer"
    case verify = "Vérifier"
    case live = "Live"
    case advanced = "Avancé"

    var id: String { rawValue }
}
#endif
