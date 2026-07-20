#if os(macOS)
import MixPilotCore
import SwiftUI

struct UnifiedWorkspaceView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var pendingCommandValidation: PendingCommandValidation?
    @State private var mappingTestResult: MappingTestResult?
    @State private var warningsAcceptedForSession = false

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

    private var liveReadiness: LiveReadiness {
        let blockers = model.preflightReport.items.compactMap { item -> LiveBlocker? in
            guard case .failed = item.status else { return nil }
            return LiveBlocker(title: item.title, detail: item.detail)
        }
        if !blockers.isEmpty {
            return .blocked(blockers)
        }

        let warnings = model.preflightReport.items.compactMap { item -> LiveWarning? in
            switch item.status {
            case .warning, .notTested:
                return LiveWarning(title: item.title, detail: item.detail)
            case .passed, .failed:
                return nil
            }
        }
        return warnings.isEmpty ? .ready : .readyWithWarnings(warnings)
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
                title: "Préparer et diagnostiquer le Live",
                subtitle: "Les vérifications expliquent les limites du système. Elles ne ferment jamais l’onglet Live et les avertissements n’empêchent pas le mode automatique supervisé.",
                symbol: "checkmark.shield.fill",
                accent: readinessAccent
            ) {
                Button("Actualiser l’observation") { model.refreshEnvironment() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                Button("Configurer le logiciel") { openWindow(id: "dj-software") }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .cyan))
                Button("Ouvrir le Live") { model.selectedSection = .live }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
            }

            readinessSummary

            verificationSection(
                title: "ESSENTIEL",
                symbol: "exclamationmark.octagon.fill",
                items: essentialItems,
                emptyMessage: "Aucun blocage absolu détecté."
            )

            verificationSection(
                title: "RECOMMANDÉ",
                symbol: "exclamationmark.triangle.fill",
                items: recommendedItems,
                emptyMessage: "Aucun avertissement restant."
            )

            observationSection

            HStack(spacing: 10) {
                Button("Autoriser la lecture de l’interface") { model.requestAccessibility() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                Button(model.audioMonitor.isRunning ? "Audio actif" : "Redémarrer l’audio") {
                    model.startAudioMonitoring()
                }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                .disabled(model.audioMonitor.isRunning)
                Button("Choisir la musique de secours") { model.selectEmergencyAudio() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                Button("Réinitialiser le contrôleur MIDI") { model.resetDefaultMapping() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
            }

            criticalCommandTester

            HStack {
                Spacer()
                switch liveReadiness {
                case .ready, .readyWithWarnings:
                    Button("Continuer en mode automatique supervisé") {
                        warningsAcceptedForSession = true
                        model.selectedSection = .live
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                case .blocked:
                    Button("Ouvrir le Live pour consulter le diagnostic") {
                        model.selectedSection = .live
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .orange))
                }
            }
        }
    }

    private var readinessSummary: some View {
        MixPilotGlassCard(accent: readinessAccent) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: readinessSymbol)
                    .font(.title2)
                    .foregroundStyle(readinessAccent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(readinessTitle).font(.headline)
                    Text(readinessDetail)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.58))
                    if warningsAcceptedForSession {
                        Text("Avertissements acceptés pour cette session — les sécurités d’arrêt et la reprise manuelle restent actives.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Spacer()
            }
        }
    }

    private var essentialItems: [PreflightItem] {
        model.preflightReport.items.filter {
            if case .failed = $0.status { return true }
            return false
        }
    }

    private var recommendedItems: [PreflightItem] {
        model.preflightReport.items.filter {
            switch $0.status {
            case .warning, .notTested: true
            case .passed, .failed: false
            }
        }
    }

    private var observationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("OBSERVATION EN DIRECT", systemImage: "dot.radiowaves.left.and.right")
                .font(.headline)
                .foregroundStyle(.cyan)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 14)], spacing: 14) {
                verificationTile("Logiciel DJ", model.backendStatus, "music.note.list", .purple)
                verificationTile("Commandes MIDI", model.midiStatus, "slider.horizontal.3", .blue)
                verificationTile("Accessibilité", model.accessibilityStatus, "eye.fill", .cyan)
                verificationTile("Audio", model.audioStatus, "waveform", .mint)
                verificationTile("Musique de secours", model.emergencyStatus, "lifepreserver.fill", .orange)
                verificationTile("Runtime", model.runtimeStatus, "clock.arrow.circlepath", .green)
            }
        }
    }

    private func verificationSection(
        title: String,
        symbol: String,
        items: [PreflightItem],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(title == "ESSENTIEL" ? .red : .orange)
            if items.isEmpty {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(items) { item in preflightRow(item) }
            }
        }
    }

    private var criticalCommandTester: some View {
        MixPilotGlassCard(accent: pendingCommandValidation == nil ? .blue : .orange) {
            VStack(alignment: .leading, spacing: 13) {
                MixPilotPanelTitle(
                    title: "Tests réels des commandes critiques",
                    symbol: "button.programmable",
                    subtitle: "La confirmation n’est proposée qu’après un envoi MIDI réellement réussi.",
                    accent: pendingCommandValidation == nil ? .blue : .orange
                )
                HStack(spacing: 10) {
                    commandTestButton("Tester Load", action: .loadA)
                    commandTestButton("Tester Play / Pause", action: .playA)
                    commandTestButton("Tester le volume", action: .volumeA)
                }

                if mappingTestResult == .sending {
                    HStack(spacing: 9) {
                        ProgressView()
                        Text("Envoi de la commande MIDI…")
                    }
                    .font(.callout)
                }

                if case .some(.failed(let error)) = mappingTestResult {
                    MixPilotNotice(
                        title: "Commande non envoyée",
                        message: error,
                        kind: .warning
                    )
                }

                if let pending = pendingCommandValidation {
                    MixPilotNotice(
                        title: "Réaction à confirmer",
                        message: "Commande \(pending.action.rawValue) envoyée à \(pending.sentAt.formatted(date: .omitted, time: .standard)). Vérifie le deck 1 dans \(model.selectedBackend?.displayName ?? "le logiciel DJ").",
                        kind: .warning
                    )
                    HStack(spacing: 10) {
                        Button("RÉACTION VALIDÉE") {
                            recordPendingValidation(pending, succeeded: true)
                        }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                        Button("ÉCHEC") {
                            recordPendingValidation(pending, succeeded: false)
                        }
                        .buttonStyle(MixPilotDangerButtonStyle())
                    }
                }
            }
        }
    }

    private func commandTestButton(_ title: String, action: DJControlAction) -> some View {
        Button(title) {
            Task { @MainActor in
                pendingCommandValidation = nil
                mappingTestResult = .sending
                let result = await model.testMapping(action)
                mappingTestResult = result
                if case .sent(let commandID, let sentAt) = result {
                    pendingCommandValidation = PendingCommandValidation(
                        action: action,
                        commandID: commandID,
                        sentAt: sentAt
                    )
                }
            }
        }
        .buttonStyle(MixPilotSecondaryButtonStyle())
        .disabled(model.selectedBackend == nil || pendingCommandValidation != nil || mappingTestResult == .sending)
    }

    private func recordPendingValidation(_ pending: PendingCommandValidation, succeeded: Bool) {
        model.recordMappingValidation(
            pending.action,
            commandID: pending.commandID,
            sentAt: pending.sentAt,
            succeeded: succeeded
        )
        pendingCommandValidation = nil
        mappingTestResult = nil
    }

    private var liveView: some View {
        VStack(alignment: .leading, spacing: 22) {
            MixPilotSectionHero(
                eyebrow: "Live",
                title: model.isLiveRunning ? "Autopilote en cours" : "Live automatique supervisé",
                subtitle: "Le Live reste accessible en mode dégradé. Les limitations d’observation sont visibles mais ne remplacent jamais les sécurités d’arrêt ni la reprise manuelle.",
                symbol: "play.circle.fill",
                accent: model.isLiveRunning ? .green : .cyan
            ) {
                Button(model.liveArmed ? "Désarmer" : "Armer le Live") { model.armLive() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                    .disabled(model.isLiveRunning)
                Button("Lancer le Live") { model.startLive() }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                    .disabled(!model.liveArmed || model.isLiveRunning)
                Button("Reprendre la main", role: .destructive) { model.takeManualControl() }
                    .buttonStyle(MixPilotDangerButtonStyle())
                    .disabled(!model.isLiveRunning)
            }

            if case .blocked(let blockers) = liveReadiness {
                MixPilotGlassCard(accent: .red) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Démarrage actuellement impossible").font(.headline)
                        ForEach(blockers) { blocker in
                            Text("• \(blocker.title) — \(blocker.detail)")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                }
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
                subtitle: "Ces outils servent à valider une version, inspecter un mapping ou préparer un rapport technique.",
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
                        Text("Simulation du moteur").font(.headline)
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

    private var readinessAccent: Color {
        switch liveReadiness {
        case .ready: .green
        case .readyWithWarnings: .orange
        case .blocked: .red
        }
    }

    private var readinessSymbol: String {
        switch liveReadiness {
        case .ready: "checkmark.circle.fill"
        case .readyWithWarnings: "exclamationmark.triangle.fill"
        case .blocked: "xmark.octagon.fill"
        }
    }

    private var readinessTitle: String {
        switch liveReadiness {
        case .ready: "Prêt pour le Live"
        case .readyWithWarnings: "Prêt avec avertissements"
        case .blocked: "Blocage réel détecté"
        }
    }

    private var readinessDetail: String {
        switch liveReadiness {
        case .ready:
            "Les fonctions essentielles sont disponibles."
        case .readyWithWarnings(let warnings):
            "\(warnings.count) avertissement(s) limitent la supervision sans empêcher l’accès au Live."
        case .blocked(let blockers):
            "\(blockers.count) problème(s) empêchent actuellement l’exécution, mais le tableau Live reste consultable."
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

struct LiveWarning: Identifiable, Equatable, Sendable {
    var title: String
    var detail: String
    var id: String { "warning|\(title)|\(detail)" }
}

struct LiveBlocker: Identifiable, Equatable, Sendable {
    var title: String
    var detail: String
    var id: String { "blocker|\(title)|\(detail)" }
}

enum LiveReadiness: Equatable, Sendable {
    case ready
    case readyWithWarnings([LiveWarning])
    case blocked([LiveBlocker])
}

private struct PendingCommandValidation: Equatable {
    var action: DJControlAction
    var commandID: UUID
    var sentAt: Date
}

enum PrimaryWorkspaceArea: String, CaseIterable, Identifiable {
    case prepare = "Préparer"
    case verify = "Vérifier"
    case live = "Live"
    case advanced = "Avancé"

    var id: String { rawValue }
}
#endif
