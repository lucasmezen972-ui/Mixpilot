#if os(macOS)
import Foundation
import MixPilotCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(SidebarSection.allCases) { section in
                    Button {
                        model.selectedSection = section
                    } label: {
                        Label(section.rawValue, systemImage: section.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("MixPilot")
        } detail: {
            switch model.selectedSection {
            case .dashboard:
                DashboardView(model: model)
            case .studio:
                PlaceholderView(title: "Studio", message: "Préparation de playlist et génération des transitions.", symbol: "waveform.path.ecg")
            case .live:
                LiveView(snapshot: model.snapshot)
            case .feasibility:
                FeasibilityView(model: model)
            case .diagnostics:
                DiagnosticsView(model: model)
            }
        }
    }
}

private struct DashboardView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MixPilot Autopilot")
                            .font(.largeTitle.bold())
                        Text("Préparer, vérifier et exécuter un set autonome dans Serato DJ Pro.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Actualiser") { model.refreshEnvironment() }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 16)], spacing: 16) {
                    StatusCard(title: "Serato", value: model.seratoStatus, symbol: "music.note.list")
                    StatusCard(title: "MIDI", value: model.midiStatus, symbol: "slider.horizontal.3")
                    StatusCard(title: "Accessibilité", value: model.accessibilityStatus, symbol: "hand.raised")
                    StatusCard(title: "Audio", value: model.audioStatus, symbol: "waveform")
                }

                GroupBox("Simulation autonome") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Le simulateur utilise la même machine à états que le futur mode réel et vérifie un set de 50 titres avec incidents injectés.")
                            .foregroundStyle(.secondary)
                        ProgressView(value: model.snapshot.progress) {
                            Text(model.snapshot.statusMessage)
                        }
                        HStack {
                            Button(model.isRunningSimulation ? "Simulation en cours…" : "Lancer le test 50 titres") {
                                model.runSimulation()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isRunningSimulation)

                            if let report = model.report {
                                Label(
                                    report.succeeded ? "Test réussi" : "Test à corriger",
                                    systemImage: report.succeeded ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                                )
                                Text("\(report.completedTransitions)/\(report.transitionCount) transitions")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                LiveSummary(snapshot: model.snapshot)
            }
            .padding(28)
        }
        .navigationTitle("Tableau de bord")
    }
}

private struct LiveView: View {
    let snapshot: LiveSnapshot

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                VStack(alignment: .leading) {
                    Text("AUTOPILOT")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(snapshot.state.rawValue.uppercased())
                        .font(.title.bold())
                }
                Spacer()
                ProgressView(value: snapshot.progress)
                    .frame(width: 240)
            }

            HStack(spacing: 18) {
                DeckCard(title: "DECK \(snapshot.activeDeck.rawValue)", track: snapshot.currentTrack, status: "EN COURS")
                DeckCard(title: "DECK \(snapshot.activeDeck.opposite.rawValue)", track: snapshot.nextTrack, status: "PROCHAIN")
            }

            GroupBox("État") {
                LiveSummary(snapshot: snapshot)
                    .padding(6)
            }

            HStack {
                Button("Pause automatique") {}
                Button("Passer") {}
                Button("Prolonger") {}
                Spacer()
                Button("REPRENDRE LE CONTRÔLE") {}
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding(28)
        .navigationTitle("Live")
    }
}

private struct FeasibilityView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Feasibility Lab")
                    .font(.largeTitle.bold())
                Text("Les validations simulées et réelles restent volontairement séparées.")
                    .foregroundStyle(.secondary)

                FeasibilityRow(name: "Port MIDI virtuel", status: model.midiStatus, isReal: model.midiStatus.contains("actif"))
                FeasibilityRow(name: "Détection de Serato", status: model.seratoStatus, isReal: model.seratoStatus.contains("détecté"))
                FeasibilityRow(name: "Permission Accessibilité", status: model.accessibilityStatus, isReal: model.accessibilityStatus.contains("Autorisée"))
                FeasibilityRow(name: "Capture audio", status: "REQUIRES_SERATO_VALIDATION", isReal: false)
                FeasibilityRow(name: "Secours local", status: "REQUIRES_HUMAN_ACTION", isReal: false)

                Button("Relancer les vérifications") {
                    model.refreshEnvironment()
                    model.configureMIDI()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
        }
    }
}

private struct DiagnosticsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Environnement") {
                LabeledContent("Serato", value: model.seratoStatus)
                LabeledContent("MIDI", value: model.midiStatus)
                LabeledContent("Accessibilité", value: model.accessibilityStatus)
                LabeledContent("Audio", value: model.audioStatus)
            }
            Section("Validation") {
                LabeledContent("Moteur Autopilot", value: "SIMULATED")
                LabeledContent("Contrôle Serato", value: "REQUIRES_SERATO_VALIDATION")
                LabeledContent("Streaming Spotify", value: "Géré uniquement par Serato")
            }
        }
        .formStyle(.grouped)
        .padding(22)
        .navigationTitle("Diagnostics")
    }
}

private struct StatusCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        GroupBox {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.headline)
                }
                Spacer()
            }
            .padding(6)
        }
    }
}

private struct DeckCard: View {
    let title: String
    let track: Track?
    let status: String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    Text(status).font(.caption.bold())
                }
                Text(track?.title ?? "Aucun titre")
                    .font(.title2.bold())
                Text(track?.artist ?? "—")
                    .foregroundStyle(.secondary)
                HStack {
                    Label(track.map { String(format: "%.1f BPM", $0.bpm) } ?? "— BPM", systemImage: "metronome")
                    Spacer()
                    Text(track?.profile.rawValue ?? "—")
                }
                .font(.callout)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LiveSummary: View {
    let snapshot: LiveSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(snapshot.statusMessage, systemImage: "dot.radiowaves.left.and.right")
                Spacer()
                Text("\(snapshot.completedTransitions) / \(snapshot.totalTransitions) transitions")
                    .foregroundStyle(.secondary)
            }
            if let incident = snapshot.incidents.last {
                Label(incident.message, systemImage: incident.recovered ? "checkmark.shield" : "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FeasibilityRow: View {
    let name: String
    let status: String
    let isReal: Bool

    var body: some View {
        HStack {
            Image(systemName: isReal ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                .font(.title2)
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(status).foregroundStyle(.secondary)
            }
            Spacer()
            Text(isReal ? "REAL" : "À VALIDER")
                .font(.caption.bold())
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PlaceholderView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
    }
}
#endif
