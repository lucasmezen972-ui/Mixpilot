#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotSystem
import SwiftUI
import UniformTypeIdentifiers

private struct RekordboxRowExport: Codable {
    var index: Int
    var fields: [String]
}

private struct RekordboxCompatibilityExport: Codable {
    var generatedAt: Date
    var applicationRunning: Bool
    var processIdentifier: Int32?
    var applicationName: String?
    var bundleIdentifier: String?
    var accessibilityGranted: Bool
    var windowTitle: String?
    var visibleText: [String]
    var rows: [RekordboxRowExport]
    var actionableElements: [RekordboxActionableElement]
}

@MainActor
final class RekordboxCompatibilityLabModel: ObservableObject {
    @Published private(set) var environment: RekordboxEnvironmentStatus?
    @Published private(set) var observation: SeratoWindowObservation?
    @Published private(set) var rows: [SeratoLibraryRow] = []
    @Published private(set) var actionableElements: [RekordboxActionableElement] = []
    @Published private(set) var status = "Aucune inspection effectuée"
    @Published private(set) var isInspecting = false

    private let environmentProbe = RekordboxEnvironmentProbe()
    private let accessibilityBridge = SeratoAccessibilityBridge()
    private let actionBridge = RekordboxAccessibilityActionBridge()

    func inspect() {
        isInspecting = true
        defer { isInspecting = false }

        let environment = environmentProbe.probe()
        self.environment = environment

        guard environment.isRunning else {
            observation = nil
            rows = []
            actionableElements = []
            status = "rekordbox n’est pas lancé."
            return
        }

        let observation = accessibilityBridge.observe(
            software: .rekordbox,
            maxDepth: 8,
            maximumStrings: 1_000
        )
        self.observation = observation

        guard observation.accessibilityGranted else {
            rows = []
            actionableElements = []
            status = "Permission Accessibilité requise."
            return
        }

        rows = accessibilityBridge.libraryRows(software: .rekordbox, maxRows: 1_500)
        do {
            actionableElements = try actionBridge.inspect()
        } catch {
            actionableElements = []
            status = error.localizedDescription
            return
        }

        status = "\(rows.count) ligne(s) et \(actionableElements.count) contrôle(s) actionnable(s) détectés."
    }

    func requestAccessibility() {
        accessibilityBridge.requestAccessibilityPrompt()
        inspect()
    }

    func activateRekordbox() {
        _ = accessibilityBridge.activate(.rekordbox)
    }

    func perform(element: RekordboxActionableElement, action: String) {
        var allowDestructive = false
        if element.isPotentiallyDestructive {
            let alert = NSAlert()
            alert.messageText = "Confirmer l’action rekordbox"
            alert.informativeText = "Le contrôle « \(element.displayName) » peut modifier ou supprimer des données. MixPilot exécutera uniquement l’action \(action)."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Exécuter")
            alert.addButton(withTitle: "Annuler")
            guard alert.runModal() == .alertFirstButtonReturn else {
                status = "Action annulée."
                return
            }
            allowDestructive = true
        }

        do {
            try actionBridge.perform(
                element: element,
                action: action,
                allowPotentiallyDestructive: allowDestructive
            )
            status = "Action \(action) envoyée à « \(element.displayName) »."
            inspect()
        } catch {
            status = "Action refusée : \(error.localizedDescription)"
        }
    }

    func exportJSON() {
        guard let environment, let observation else {
            status = "Effectue d’abord une inspection."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Exporter le diagnostic rekordbox"
        panel.nameFieldStringValue = "MixPilot-rekordbox-compatibility.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let export = RekordboxCompatibilityExport(
            generatedAt: Date(),
            applicationRunning: environment.isRunning,
            processIdentifier: environment.processIdentifier,
            applicationName: environment.applicationName,
            bundleIdentifier: environment.bundleIdentifier,
            accessibilityGranted: observation.accessibilityGranted,
            windowTitle: observation.windowTitle,
            visibleText: observation.visibleText,
            rows: rows.map { RekordboxRowExport(index: $0.index, fields: $0.fields) },
            actionableElements: actionableElements
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(export).write(to: url, options: .atomic)
            status = "Diagnostic exporté : \(url.lastPathComponent)"
        } catch {
            status = "Échec export : \(error.localizedDescription)"
        }
    }
}

private enum RekordboxControlSection: String, CaseIterable, Identifiable {
    case midi = "Live MIDI"
    case interface = "Interface"
    case playlist = "Playlist"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .midi: "slider.horizontal.3"
        case .interface: "cursorarrow.click"
        case .playlist: "list.bullet.rectangle"
        }
    }
}

struct RekordboxCompatibilityLabView: View {
    @ObservedObject var appModel: AppModel
    @StateObject private var model = RekordboxCompatibilityLabModel()
    @State private var actionsArmed = false
    @State private var selectedElementID: String?
    @State private var section: RekordboxControlSection = .midi

    var body: some View {
        ZStack {
            MixPilotPremiumBackground()

            VStack(spacing: 0) {
                header
                Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
                HStack(spacing: 0) {
                    controlSidebar
                    Rectangle().fill(.white.opacity(0.09)).frame(width: 1)
                    detail
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1_080, minHeight: 760)
        .onAppear { model.inspect() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 17)
                    .fill(LinearGradient(colors: [.blue, .purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "record.circle")
                    .font(.system(size: 28, weight: .semibold))
            }
            .frame(width: 58, height: 58)
            .shadow(color: .blue.opacity(0.25), radius: 16, y: 7)

            VStack(alignment: .leading, spacing: 4) {
                Text("REKORDBOX CONTROL")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(.cyan)
                Text("Contrôle et compatibilité")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("Inspection, tests MIDI et actions Accessibilité protégées sur l’interface réelle.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            MixPilotStatusBadge(
                title: "Device validation",
                symbol: "exclamationmark.shield.fill",
                accent: .orange
            )

            Button("Inspecter") { model.inspect() }
                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .blue))
                .disabled(model.isInspecting)
            Button("Afficher rekordbox") { model.activateRekordbox() }
                .buttonStyle(MixPilotSecondaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
        .background(.black.opacity(0.13))
    }

    private var controlSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ESPACES")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.34))

            ForEach(RekordboxControlSection.allCases) { item in
                Button {
                    withAnimation(.snappy(duration: 0.22)) { section = item }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.symbol)
                            .frame(width: 22)
                            .foregroundStyle(section == item ? .cyan : .white.opacity(0.42))
                        Text(item.rawValue)
                            .font(.caption.bold())
                        Spacer()
                        if section == item { Circle().fill(.cyan).frame(width: 6, height: 6) }
                    }
                    .padding(11)
                    .background(section == item ? .white.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
            }

            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)

            Toggle("Armer les actions", isOn: $actionsArmed)
                .toggleStyle(.switch)
                .tint(.orange)

            Text("Les boutons MIDI et les actions Accessibilité restent bloqués jusqu’à l’armement manuel.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))

            Button("Autoriser l’Accessibilité") { model.requestAccessibility() }
                .buttonStyle(MixPilotSecondaryButtonStyle())
            Button("Exporter le JSON") { model.exportJSON() }
                .buttonStyle(MixPilotSecondaryButtonStyle())
                .disabled(model.observation == nil)

            Spacer()

            MixPilotGlassCard(cornerRadius: 14, padding: 12, accent: environmentColor) {
                VStack(alignment: .leading, spacing: 8) {
                    MixPilotStatusBadge(
                        title: model.environment?.isRunning == true ? "Connecté" : "Hors ligne",
                        symbol: model.environment?.isRunning == true ? "checkmark.circle.fill" : "circle.dashed",
                        accent: environmentColor
                    )
                    Text(model.status)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(5)
                    if model.isInspecting { ProgressView().controlSize(.small).tint(.cyan) }
                }
            }
        }
        .padding(18)
        .frame(width: 245)
        .background(.black.opacity(0.15))
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                    MixPilotMetricTile(title: "Application", value: model.environment?.isRunning == true ? "Détectée" : "Absente", symbol: "app.badge.checkmark", accent: environmentColor)
                    MixPilotMetricTile(title: "Accessibilité", value: model.observation?.accessibilityGranted == true ? "Autorisée" : "Non autorisée", symbol: "hand.raised.fill", accent: model.observation?.accessibilityGranted == true ? .green : .orange)
                    MixPilotMetricTile(title: "Lignes", value: "\(model.rows.count)", symbol: "list.bullet.rectangle", accent: .purple)
                    MixPilotMetricTile(title: "Contrôles", value: "\(model.actionableElements.count)", symbol: "cursorarrow.click", accent: .cyan)
                    MixPilotMetricTile(title: "Mapping MIDI", value: "\(Int(appModel.mappingProfile.completionRatio * 100)) %", symbol: "slider.horizontal.3", accent: .blue)
                }

                switch section {
                case .midi: midiControls
                case .interface: accessibilityControls
                case .playlist: playlistRows
                }

                MixPilotGlassCard(accent: .orange) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.orange)
                        Text("Le Live utilise des intentions de haut niveau, mais rekordbox doit apprendre les messages du contrôleur virtuel. Les actions potentiellement destructrices demandent toujours une confirmation séparée.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.52))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1_080, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private var midiControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            MixPilotSectionHero(
                eyebrow: "Commandes réelles",
                title: "Live MIDI",
                subtitle: "Chaque bouton envoie un message par le port virtuel uniquement lorsque les actions sont armées.",
                symbol: "slider.horizontal.3",
                accent: .blue
            ) { EmptyView() }

            HStack(alignment: .top, spacing: 16) {
                deckControls(title: "Deck A", accent: .purple, play: .playA, pause: .pauseA, sync: .syncA, load: .loadA)
                deckControls(title: "Deck B", accent: .cyan, play: .playB, pause: .pauseB, sync: .syncB, load: .loadB)
            }

            MixPilotGlassCard(accent: .blue) {
                VStack(alignment: .leading, spacing: 13) {
                    MixPilotPanelTitle(title: "Navigation et mixeur", symbol: "dial.medium.fill", subtitle: "Commandes globales du contrôleur virtuel.", accent: .blue)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 10)], spacing: 10) {
                        actionButton("Focus navigateur", action: .browserFocus, symbol: "rectangle.and.hand.point.up.left.fill")
                        actionButton("Titre suivant", action: .browserDown, symbol: "arrow.down")
                        actionButton("Crossfader centre", action: .crossfader, symbol: "arrow.left.arrow.right")
                        actionButton("Volume A 50 %", action: .volumeA, symbol: "speaker.wave.2.fill")
                        actionButton("Volume B 50 %", action: .volumeB, symbol: "speaker.wave.2.fill")
                    }
                }
            }
        }
    }

    private var accessibilityControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            MixPilotSectionHero(
                eyebrow: "Arbre Accessibilité",
                title: "Contrôles d’interface",
                subtitle: "MixPilot n’exécute que les actions allowlistées et revérifie l’élément avant chaque action.",
                symbol: "cursorarrow.click",
                accent: .cyan
            ) { EmptyView() }

            if model.actionableElements.isEmpty {
                MixPilotGlassCard(accent: .orange) {
                    ContentUnavailableView(
                        "Aucun contrôle actionnable",
                        systemImage: "cursorarrow.slash",
                        description: Text("Affiche le panneau souhaité dans rekordbox, puis relance l’inspection.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    MixPilotGlassCard(accent: .cyan) {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(model.actionableElements) { element in
                                    Button {
                                        selectedElementID = element.id
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: element.isPotentiallyDestructive ? "exclamationmark.triangle.fill" : "cursorarrow.click")
                                                .foregroundStyle(element.isPotentiallyDestructive ? .orange : .cyan)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(element.displayName).font(.caption.bold()).lineLimit(1)
                                                Text("\(element.role) • \(element.actions.joined(separator: ", "))")
                                                    .font(.caption2.monospaced())
                                                    .foregroundStyle(.white.opacity(0.4))
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .padding(9)
                                        .background(selectedElementID == element.id ? .white.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(minHeight: 360)
                    }

                    MixPilotGlassCard(accent: selectedElement?.isPotentiallyDestructive == true ? .orange : .purple) {
                        VStack(alignment: .leading, spacing: 13) {
                            if let selectedElement {
                                MixPilotPanelTitle(
                                    title: selectedElement.displayName,
                                    symbol: selectedElement.isPotentiallyDestructive ? "exclamationmark.triangle.fill" : "cursorarrow.click",
                                    subtitle: selectedElement.role,
                                    accent: selectedElement.isPotentiallyDestructive ? .orange : .purple
                                )
                                Text(selectedElement.fingerprint)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.white.opacity(0.42))
                                    .textSelection(.enabled)
                                ForEach(selectedElement.actions, id: \.self) { action in
                                    Button("EXÉCUTER \(action.uppercased())") {
                                        model.perform(element: selectedElement, action: action)
                                    }
                                    .buttonStyle(selectedElement.isPotentiallyDestructive ? AnyButtonStyle(MixPilotDangerButtonStyle()) : AnyButtonStyle(MixPilotPrimaryButtonStyle(accent: .purple)))
                                    .disabled(!actionsArmed)
                                }
                            } else {
                                Text("Sélectionne un contrôle rekordbox.")
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            Spacer()
                        }
                        .frame(width: 280, minHeight: 360, alignment: .topLeading)
                    }
                }
            }
        }
    }

    private var playlistRows: some View {
        VStack(alignment: .leading, spacing: 16) {
            MixPilotSectionHero(
                eyebrow: "Observation",
                title: "Playlist visible",
                subtitle: "Les lignes sont capturées en lecture seule depuis l’interface rekordbox.",
                symbol: "list.bullet.rectangle",
                accent: .purple
            ) { EmptyView() }

            if model.rows.isEmpty {
                MixPilotGlassCard(accent: .orange) {
                    ContentUnavailableView(
                        "Aucune ligne détectée",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Affiche une playlist dans rekordbox puis relance l’inspection.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            } else {
                MixPilotGlassCard(accent: .purple) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("LIGNE").frame(width: 70, alignment: .leading)
                            Text("CONTENU").frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.36))
                        .padding(.bottom, 8)

                        ForEach(Array(model.rows.prefix(300))) { row in
                            Rectangle().fill(.white.opacity(0.07)).frame(height: 1)
                            HStack(alignment: .top) {
                                Text("#\(row.index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.purple)
                                    .frame(width: 70, alignment: .leading)
                                Text(row.displayText)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }

    private var selectedElement: RekordboxActionableElement? {
        guard let selectedElementID else { return nil }
        return model.actionableElements.first { $0.id == selectedElementID }
    }

    private func deckControls(
        title: String,
        accent: Color,
        play: SeratoAction,
        pause: SeratoAction,
        sync: SeratoAction,
        load: SeratoAction
    ) -> some View {
        MixPilotGlassCard(accent: accent) {
            VStack(alignment: .leading, spacing: 13) {
                MixPilotPanelTitle(title: title, symbol: "record.circle", subtitle: "Tests MIDI réels", accent: accent)
                actionButton("Charger", action: load, symbol: "arrow.down.to.line")
                actionButton("Lecture", action: play, symbol: "play.fill")
                actionButton("Pause", action: pause, symbol: "pause.fill")
                actionButton("Sync", action: sync, symbol: "arrow.triangle.2.circlepath")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(_ title: String, action: SeratoAction, symbol: String) -> some View {
        Button {
            appModel.testMapping(action)
        } label: {
            HStack {
                Image(systemName: symbol).frame(width: 20)
                Text(title).font(.caption.bold())
                Spacer()
                Image(systemName: "paperplane.fill").font(.caption2)
            }
            .padding(10)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(!actionsArmed)
        .opacity(actionsArmed ? 1 : 0.4)
    }

    private var environmentColor: Color {
        model.environment?.isRunning == true ? .green : .orange
    }
}

private struct AnyButtonStyle: ButtonStyle {
    private let makeBodyClosure: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        makeBodyClosure = { configuration in AnyView(style.makeBody(configuration: configuration)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        makeBodyClosure(configuration)
    }
}
#endif
