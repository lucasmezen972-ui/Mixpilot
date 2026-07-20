#if os(macOS)
import MixPilotCore
import MixPilotSystem
import SwiftUI

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
                    sidebar
                    Rectangle().fill(.white.opacity(0.09)).frame(width: 1)
                    content
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
                Text("Inspection, tests MIDI et actions Accessibilité protégées.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
            MixPilotStatusBadge(title: "Device validation", symbol: "exclamationmark.shield.fill", accent: .orange)
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

    private var sidebar: some View {
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
                        Text(item.rawValue).font(.caption.bold())
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

            Text("Les commandes restent bloquées jusqu’à l’armement manuel.")
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

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                metrics
                switch section {
                case .midi: midiPanel
                case .interface: interfacePanel
                case .playlist: playlistPanel
                }
                warningCard
            }
            .padding(24)
            .frame(maxWidth: 1_080, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
            MixPilotMetricTile(title: "Application", value: model.environment?.isRunning == true ? "Détectée" : "Absente", symbol: "app.badge.checkmark", accent: environmentColor)
            MixPilotMetricTile(title: "Accessibilité", value: model.observation?.accessibilityGranted == true ? "Autorisée" : "Non autorisée", symbol: "hand.raised.fill", accent: model.observation?.accessibilityGranted == true ? .green : .orange)
            MixPilotMetricTile(title: "Lignes", value: "\(model.rows.count)", symbol: "list.bullet.rectangle", accent: .purple)
            MixPilotMetricTile(title: "Contrôles", value: "\(model.actionableElements.count)", symbol: "cursorarrow.click", accent: .cyan)
            MixPilotMetricTile(title: "Mapping MIDI", value: "\(Int(appModel.mappingProfile.completionRatio * 100)) %", symbol: "slider.horizontal.3", accent: .blue)
        }
    }

    private var midiPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            MixPilotSectionHero(
                eyebrow: "Commandes réelles",
                title: "Live MIDI",
                subtitle: "Les messages sont envoyés par le contrôleur virtuel uniquement quand les actions sont armées.",
                symbol: "slider.horizontal.3",
                accent: .blue
            ) { EmptyView() }

            HStack(alignment: .top, spacing: 16) {
                deckCard("Deck A", accent: .purple, load: .loadA, play: .playA, pause: .pauseA, sync: .syncA)
                deckCard("Deck B", accent: .cyan, load: .loadB, play: .playB, pause: .pauseB, sync: .syncB)
            }

            MixPilotGlassCard(accent: .blue) {
                VStack(alignment: .leading, spacing: 13) {
                    MixPilotPanelTitle(title: "Navigation et mixeur", symbol: "dial.medium.fill", subtitle: "Commandes globales", accent: .blue)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 10)], spacing: 10) {
                        midiButton("Focus navigateur", .browserFocus, "rectangle.and.hand.point.up.left.fill")
                        midiButton("Titre suivant", .browserDown, "arrow.down")
                        midiButton("Crossfader centre", .crossfader, "arrow.left.arrow.right")
                        midiButton("Volume A 50 %", .volumeA, "speaker.wave.2.fill")
                        midiButton("Volume B 50 %", .volumeB, "speaker.wave.2.fill")
                    }
                }
            }
        }
    }

    private var interfacePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            MixPilotSectionHero(
                eyebrow: "Arbre Accessibilité",
                title: "Contrôles d’interface",
                subtitle: "Les éléments sont revérifiés avant chaque action.",
                symbol: "cursorarrow.click",
                accent: .cyan
            ) { EmptyView() }

            if model.actionableElements.isEmpty {
                emptyCard("Aucun contrôle actionnable", "Affiche le panneau souhaité dans rekordbox, puis relance l’inspection.", "cursorarrow.slash")
            } else {
                HStack(alignment: .top, spacing: 16) {
                    MixPilotGlassCard(accent: .cyan) {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(model.actionableElements) { element in
                                    elementRow(element)
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
                                    interfaceActionButton(selectedElement, action: action)
                                }
                            } else {
                                Text("Sélectionne un contrôle rekordbox.")
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            Spacer()
                        }
                        .frame(width: 280, alignment: .topLeading)
                        .frame(minHeight: 360, alignment: .topLeading)
                    }
                }
            }
        }
    }

    private var playlistPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            MixPilotSectionHero(
                eyebrow: "Observation",
                title: "Playlist visible",
                subtitle: "Capture en lecture seule depuis l’interface rekordbox.",
                symbol: "list.bullet.rectangle",
                accent: .purple
            ) { EmptyView() }

            if model.rows.isEmpty {
                emptyCard("Aucune ligne détectée", "Affiche une playlist dans rekordbox puis relance l’inspection.", "list.bullet.rectangle")
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

    private var warningCard: some View {
        MixPilotGlassCard(accent: .orange) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.orange)
                Text("Les commandes réelles demandent un mapping validé. Toute action sensible exige une confirmation distincte.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
    }

    private func deckCard(_ title: String, accent: Color, load: SeratoAction, play: SeratoAction, pause: SeratoAction, sync: SeratoAction) -> some View {
        MixPilotGlassCard(accent: accent) {
            VStack(alignment: .leading, spacing: 13) {
                MixPilotPanelTitle(title: title, symbol: "record.circle", subtitle: "Tests MIDI réels", accent: accent)
                midiButton("Charger", load, "arrow.down.to.line")
                midiButton("Lecture", play, "play.fill")
                midiButton("Pause", pause, "pause.fill")
                midiButton("Sync", sync, "arrow.triangle.2.circlepath")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func midiButton(_ title: String, _ action: SeratoAction, _ symbol: String) -> some View {
        Button {
            Task { @MainActor in
                _ = await appModel.testMapping(action)
            }
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

    private func elementRow(_ element: RekordboxActionableElement) -> some View {
        Button { selectedElementID = element.id } label: {
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

    @ViewBuilder
    private func interfaceActionButton(_ element: RekordboxActionableElement, action: String) -> some View {
        if element.isPotentiallyDestructive {
            Button("EXÉCUTER \(action.uppercased())") { model.perform(element: element, action: action) }
                .buttonStyle(MixPilotDangerButtonStyle())
                .disabled(!actionsArmed)
        } else {
            Button("EXÉCUTER \(action.uppercased())") { model.perform(element: element, action: action) }
                .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                .disabled(!actionsArmed)
        }
    }

    private func emptyCard(_ title: String, _ description: String, _ symbol: String) -> some View {
        MixPilotGlassCard(accent: .orange) {
            ContentUnavailableView(title, systemImage: symbol, description: Text(description))
                .frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    private var selectedElement: RekordboxActionableElement? {
        guard let selectedElementID else { return nil }
        return model.actionableElements.first { $0.id == selectedElementID }
    }

    private var environmentColor: Color {
        model.environment?.isRunning == true ? .green : .orange
    }
}
#endif
