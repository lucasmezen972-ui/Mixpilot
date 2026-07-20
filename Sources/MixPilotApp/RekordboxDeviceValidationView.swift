#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotSystem
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class RekordboxDeviceValidationSession: ObservableObject {
    @Published private(set) var plan: RekordboxDeviceValidationPlan?
    @Published private(set) var report: RekordboxDeviceValidationReport?
    @Published private(set) var installedVersion: String?
    @Published private(set) var status = "Préparation de la validation…"
    @Published private(set) var lastSentCommandID: String?
    @Published var selectedCommandID: String?
    @Published var note = ""
    @Published var commandsArmed = false

    private let store: RekordboxDeviceValidationStore

    init() {
        let supportRoot = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        store = RekordboxDeviceValidationStore(
            directory: supportRoot
                .appendingPathComponent("MixPilot Autopilot", isDirectory: true)
                .appendingPathComponent("Rekordbox Validation", isDirectory: true)
        )
    }

    func refresh(profile: MIDIMappingProfile) {
        installedVersion = detectVersion()
        do {
            let plan = try RekordboxDeviceValidationPlanBuilder().make(
                profile: profile,
                installedVersion: installedVersion
            )
            var report = try store.load(for: plan.target)
                ?? RekordboxDeviceValidationReport(plan: plan)
            report.synchronize(with: plan)
            _ = try store.save(report)
            self.plan = plan
            self.report = report
            if selectedCommandID == nil || !plan.commands.contains(where: { $0.id == selectedCommandID }) {
                selectedCommandID = nextCommandID(in: plan, report: report)
                    ?? plan.commands.first?.id
            }
            synchronizeNote()
            status = installedVersion.map { "rekordbox v\($0) • certificat \(plan.target.presetSignature.prefix(8))" }
                ?? "Version rekordbox non détectée • le certificat sera lié au preset uniquement"
        } catch {
            plan = nil
            report = nil
            selectedCommandID = nil
            status = "Validation indisponible : \(error.localizedDescription)"
        }
    }

    var selectedCommand: RekordboxDeviceValidationCommand? {
        guard let plan, let selectedCommandID else { return nil }
        return plan.commands.first { $0.id == selectedCommandID }
    }

    var completionRatio: Double {
        guard let plan, let report else { return 0 }
        return report.completionRatio(for: plan)
    }

    var passedRatio: Double {
        guard let plan, let report else { return 0 }
        return report.passedRatio(for: plan)
    }

    var criticalReady: Bool {
        guard let plan, let report else { return false }
        return report.criticalCommandsPassed(in: plan)
    }

    var testedCount: Int { report?.testedCount ?? 0 }
    var totalAvailableCount: Int { plan?.commands.filter(\.isAvailableForInstalledVersion).count ?? 0 }

    func outcome(for command: RekordboxDeviceValidationCommand) -> RekordboxDeviceValidationOutcome {
        report?.outcome(for: command) ?? .untested
    }

    func select(_ command: RekordboxDeviceValidationCommand) {
        selectedCommandID = command.id
        lastSentCommandID = nil
        synchronizeNote()
    }

    func markSent(_ command: RekordboxDeviceValidationCommand) {
        lastSentCommandID = command.id
        status = "Commande \(command.csvName) envoyée. Confirme maintenant la réaction visible ou audible dans rekordbox."
    }

    func record(_ outcome: RekordboxDeviceValidationOutcome) {
        guard let plan, var report, let command = selectedCommand else { return }
        report.record(outcome, for: command.id, note: note)
        do {
            _ = try store.save(report)
            self.report = report
            lastSentCommandID = nil
            status = "\(command.title) : \(outcome.displayName.lowercased())."
            if let next = nextCommandID(after: command.id, in: plan, report: report) {
                selectedCommandID = next
                synchronizeNote()
            }
        } catch {
            status = "Impossible d’enregistrer le résultat : \(error.localizedDescription)"
        }
    }

    func reset() {
        guard let plan else { return }
        let fresh = RekordboxDeviceValidationReport(plan: plan)
        do {
            _ = try store.save(fresh)
            report = fresh
            selectedCommandID = nextCommandID(in: plan, report: fresh) ?? plan.commands.first?.id
            lastSentCommandID = nil
            note = ""
            status = "Certificat réinitialisé pour rekordbox \(plan.target.rekordboxVersion)."
        } catch {
            status = "Réinitialisation impossible : \(error.localizedDescription)"
        }
    }

    func exportReport() {
        guard let plan, let report else { return }
        let panel = NSSavePanel()
        panel.title = "Exporter le certificat de compatibilité rekordbox"
        panel.nameFieldStringValue = "MixPilot-rekordbox-validation-\(plan.target.rekordboxVersion).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(report).write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            status = "Certificat exporté : \(url.lastPathComponent)"
        } catch {
            status = "Export impossible : \(error.localizedDescription)"
        }
    }

    private func synchronizeNote() {
        guard let selectedCommandID else {
            note = ""
            return
        }
        note = report?[selectedCommandID].note ?? ""
    }

    private func nextCommandID(
        in plan: RekordboxDeviceValidationPlan,
        report: RekordboxDeviceValidationReport
    ) -> String? {
        plan.commands.first {
            $0.isAvailableForInstalledVersion && report[$0.id].outcome == .untested
        }?.id
    }

    private func nextCommandID(
        after currentID: String,
        in plan: RekordboxDeviceValidationPlan,
        report: RekordboxDeviceValidationReport
    ) -> String? {
        guard let index = plan.commands.firstIndex(where: { $0.id == currentID }) else {
            return nextCommandID(in: plan, report: report)
        }
        let ordered = Array(plan.commands.dropFirst(index + 1)) + Array(plan.commands.prefix(index + 1))
        return ordered.first {
            $0.isAvailableForInstalledVersion && report[$0.id].outcome == .untested
        }?.id
    }

    private func detectVersion() -> String? {
        let application = NSWorkspace.shared.runningApplications.first { app in
            RekordboxApplicationMatcher.matches(
                name: app.localizedName,
                bundleIdentifier: app.bundleIdentifier
            )
        }
        guard let bundleURL = application?.bundleURL,
              let bundle = Bundle(url: bundleURL) else {
            return nil
        }
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}

struct RekordboxDeviceValidationView: View {
    @ObservedObject var appModel: AppModel
    @StateObject private var session = RekordboxDeviceValidationSession()

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            VStack(spacing: 0) {
                header
                Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
                HStack(spacing: 0) {
                    commandList
                    Rectangle().fill(.white.opacity(0.09)).frame(width: 1)
                    detail
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1_160, minHeight: 790)
        .onAppear { session.refresh(profile: appModel.mappingProfile) }
    }

    private var header: some View {
        VStack(spacing: 15) {
            MixPilotSectionHero(
                eyebrow: "Validation matérielle",
                title: "Certifier rekordbox commande par commande",
                subtitle: "Chaque résultat est lié à la version installée et à l’empreinte exacte du preset MIDI.",
                symbol: "checkmark.seal.fill",
                accent: .cyan
            ) {
                Button("Actualiser") { session.refresh(profile: appModel.mappingProfile) }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                Button("Exporter") { session.exportReport() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
                Button("Réinitialiser", role: .destructive) { session.reset() }
                    .buttonStyle(MixPilotDangerButtonStyle())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                MixPilotMetricTile(
                    title: "Version",
                    value: session.plan?.target.rekordboxVersion ?? "Inconnue",
                    symbol: "app.badge.checkmark",
                    accent: .blue
                )
                MixPilotMetricTile(
                    title: "Progression",
                    value: "\(session.testedCount)/\(session.totalAvailableCount)",
                    symbol: "chart.bar.fill",
                    accent: .purple
                )
                MixPilotMetricTile(
                    title: "Réussite",
                    value: "\(Int(session.passedRatio * 100)) %",
                    symbol: "checkmark.circle.fill",
                    accent: session.passedRatio >= 0.95 ? .green : .cyan
                )
                MixPilotMetricTile(
                    title: "Live critique",
                    value: session.criticalReady ? "CERTIFIÉ" : "À VALIDER",
                    symbol: session.criticalReady ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                    accent: session.criticalReady ? .green : .orange
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.black.opacity(0.14))
    }

    private var commandList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("COMMANDES")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.36))
                Spacer()
                Text("\(Int(session.completionRatio * 100)) %")
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
            }
            ProgressView(value: session.completionRatio).tint(.cyan)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(session.plan?.commands ?? []) { command in
                        commandRow(command)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Toggle("Armer l’envoi MIDI", isOn: $session.commandsArmed)
                .toggleStyle(.switch)
                .tint(.orange)

            Text(session.status)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 300)
        .background(.black.opacity(0.16))
    }

    private func commandRow(_ command: RekordboxDeviceValidationCommand) -> some View {
        let outcome = session.outcome(for: command)
        let selected = session.selectedCommandID == command.id
        return Button {
            session.select(command)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: outcomeSymbol(outcome, available: command.isAvailableForInstalledVersion))
                    .foregroundStyle(outcomeColor(outcome, available: command.isAvailableForInstalledVersion))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(command.title)
                            .font(.caption.bold())
                            .lineLimit(1)
                        if command.isCritical {
                            Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    Text("\(command.csvName) • \(command.midiHex)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.38))
                }
                Spacer()
            }
            .padding(10)
            .background(selected ? .white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 11))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 11).stroke(.cyan.opacity(0.28), lineWidth: 1)
                }
            }
            .opacity(command.isAvailableForInstalledVersion ? 1 : 0.48)
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        ScrollView {
            if let command = session.selectedCommand {
                VStack(alignment: .leading, spacing: 20) {
                    commandHero(command)
                    testPanel(command)
                    evidencePanel(command)
                }
                .padding(26)
                .frame(maxWidth: 940, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    "Aucune commande disponible",
                    systemImage: "slider.horizontal.3",
                    description: Text("Génère d’abord un profil MIDI rekordbox compatible.")
                )
                .frame(maxWidth: .infinity, minHeight: 480)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func commandHero(_ command: RekordboxDeviceValidationCommand) -> some View {
        MixPilotGlassCard(accent: command.isCritical ? .orange : .cyan) {
            HStack(alignment: .top, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill((command.isCritical ? Color.orange : Color.cyan).opacity(0.14))
                    Image(systemName: command.controlType == .button ? "button.programmable" : "slider.horizontal.3")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(command.isCritical ? .orange : .cyan)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    Text(command.category.uppercased())
                        .font(.caption2.bold())
                        .tracking(1.5)
                        .foregroundStyle(.cyan)
                    Text(command.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("\(command.csvName) • \(scopeText(command.scope)) • MIDI \(command.midiHex)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                MixPilotStatusBadge(
                    title: session.outcome(for: command).displayName,
                    symbol: outcomeSymbol(session.outcome(for: command), available: command.isAvailableForInstalledVersion),
                    accent: outcomeColor(session.outcome(for: command), available: command.isAvailableForInstalledVersion)
                )
            }
        }
    }

    private func testPanel(_ command: RekordboxDeviceValidationCommand) -> some View {
        MixPilotGlassCard(accent: .blue) {
            VStack(alignment: .leading, spacing: 16) {
                MixPilotPanelTitle(
                    title: "Test réel",
                    symbol: "paperplane.fill",
                    subtitle: "Observe rekordbox avant de confirmer le résultat.",
                    accent: .blue
                )

                if !command.isAvailableForInstalledVersion {
                    Label(
                        "Cette commande exige rekordbox \(command.minimumVersion.map { "≥ \($0)" } ?? "plus récent"). Elle est exclue du certificat actuel.",
                        systemImage: "nosign"
                    )
                    .foregroundStyle(.orange)
                }

                if let warning = command.warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                TextField("Remarque facultative", text: $session.note, axis: .vertical)
                    .lineLimit(2...4)
                    .mixPilotInputStyle()

                HStack(spacing: 10) {
                    Button("ENVOYER LE TEST") {
                        Task { @MainActor in
                            let result = await appModel.testMapping(command.action)
                            if case .sent = result {
                                session.markSent(command)
                            }
                        }
                    }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .blue))
                    .disabled(!session.commandsArmed || !command.isAvailableForInstalledVersion)

                    Button("RÉACTION VALIDÉE") { session.record(.passed) }
                        .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                        .disabled(session.lastSentCommandID != command.id)

                    Button("ÉCHEC") { session.record(.failed) }
                        .buttonStyle(MixPilotDangerButtonStyle())
                        .disabled(session.lastSentCommandID != command.id)

                    Button("IGNORER") { session.record(.skipped) }
                        .buttonStyle(MixPilotSecondaryButtonStyle())
                        .disabled(!command.isAvailableForInstalledVersion)
                }

                Text("L’envoi d’un message ne constitue jamais une validation. Seule ta confirmation après observation de rekordbox crée une preuve locale.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
    }

    private func evidencePanel(_ command: RekordboxDeviceValidationCommand) -> some View {
        let record = session.report?[command.id]
        return MixPilotGlassCard(accent: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                MixPilotPanelTitle(
                    title: "Preuve enregistrée",
                    symbol: "doc.badge.clock",
                    subtitle: "Cette preuve n’est valable que pour la version et le preset affichés en haut.",
                    accent: .purple
                )
                HStack {
                    evidenceValue("Résultat", record?.outcome.displayName ?? "À tester")
                    evidenceValue("Testé le", record?.testedAt?.formatted(date: .abbreviated, time: .standard) ?? "—")
                    evidenceValue("Critique Live", command.isCritical ? "Oui" : "Non")
                    evidenceValue("Version minimale", command.minimumVersion ?? "—")
                }
                if let note = record?.note {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.62))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func evidenceValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(.caption2.bold()).foregroundStyle(.white.opacity(0.36))
            Text(value).font(.caption.bold()).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scopeText(_ scope: RekordboxMIDIScope) -> String {
        switch scope {
        case .global: return "Global"
        case .deckA: return "Deck 1"
        case .deckB: return "Deck 2"
        }
    }

    private func outcomeSymbol(_ outcome: RekordboxDeviceValidationOutcome, available: Bool) -> String {
        guard available else { return "nosign" }
        switch outcome {
        case .untested: return "circle.dotted"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .skipped: return "minus.circle.fill"
        }
    }

    private func outcomeColor(_ outcome: RekordboxDeviceValidationOutcome, available: Bool) -> Color {
        guard available else { return Color.secondary }
        switch outcome {
        case .untested: return Color.orange
        case .passed: return Color.green
        case .failed: return Color.red
        case .skipped: return Color.secondary
        }
    }
}
#endif
