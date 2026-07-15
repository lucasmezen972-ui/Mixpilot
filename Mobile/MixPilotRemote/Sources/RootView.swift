import SwiftUI

struct RootView: View {
    @StateObject private var discovery = BonjourDiscovery()
    @StateObject private var connection = RemoteConnection()
    @State private var pairingCode = ""

    var body: some View {
        NavigationStack {
            Group {
                if connection.status.isAuthenticated, let snapshot = connection.snapshot {
                    LiveRemoteView(connection: connection, snapshot: snapshot)
                } else {
                    DiscoveryView(discovery: discovery, connection: connection)
                }
            }
            .navigationTitle("MixPilot Remote")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $connection.pairingRequired) {
            PairingView(
                macName: connection.status.title,
                code: $pairingCode,
                error: connection.lastError,
                onPair: {
                    connection.pair(using: pairingCode)
                    pairingCode = ""
                },
                onCancel: {
                    connection.disconnect(reason: "Appairage annulé")
                }
            )
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
    }
}

private struct DiscoveryView: View {
    @ObservedObject var discovery: BonjourDiscovery
    @ObservedObject var connection: RemoteConnection

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text("Pilote ton set sans rester devant le Mac")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("L’iPhone envoie des commandes sécurisées. Le moteur Mac garde la main sur Serato, le MIDI et les protections Live.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 18)

                StatusCard(status: connection.status, error: connection.lastError)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Mac disponibles")
                            .font(.headline)
                        Spacer()
                        if discovery.isSearching {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button {
                            discovery.stop()
                            discovery.start()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Relancer la recherche")
                    }

                    if discovery.endpoints.isEmpty {
                        ContentUnavailableView(
                            "Aucun Mac détecté",
                            systemImage: "laptopcomputer.slash",
                            description: Text("Le bridge MixPilot doit être lancé sur le Mac et les deux appareils doivent utiliser le même réseau local.")
                        )
                        .frame(minHeight: 210)
                    } else {
                        ForEach(discovery.endpoints) { endpoint in
                            Button {
                                connection.connect(to: endpoint)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "laptopcomputer")
                                        .font(.title2)
                                        .frame(width: 36, height: 36)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(endpoint.name)
                                            .font(.headline)
                                        Text("\(endpoint.host):\(endpoint.port)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    connection.startDemo()
                } label: {
                    Label("Essayer le mode démo", systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Le mode démo ne commande aucun appareil.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }
}

private struct StatusCard: View {
    let status: RemoteConnectionStatus
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Circle()
                    .fill(status.isAuthenticated ? Color.green : Color.orange)
                    .frame(width: 9, height: 9)
                Text(status.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            if let error, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PairingView: View {
    let macName: String
    @Binding var code: String
    let error: String?
    let onPair: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 46))
                    .foregroundStyle(.indigo)

                Text("Entre le code affiché sur le Mac")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text(macName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter { $0.isNumber }.prefix(6))
                    }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Appairer l’iPhone", action: onPair)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(code.count != 6)

                Button("Annuler", role: .cancel, action: onCancel)
            }
            .padding(24)
        }
    }
}

private struct LiveRemoteView: View {
    @ObservedObject var connection: RemoteConnection
    let snapshot: RemoteSnapshot

    @State private var confirmSafeFade = false
    @State private var confirmManualControl = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                connectionHeader

                if let alert = snapshot.alert {
                    Label(alert, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                }

                nowPlayingCard
                nextTrackCard
                controls

                if let ack = connection.lastAcknowledgement {
                    Label(
                        ack.message,
                        systemImage: ack.accepted ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(ack.accepted ? .green : .red)
                }
            }
            .padding(18)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Déconnecter") {
                    connection.disconnect()
                }
            }
        }
        .confirmationDialog(
            "Déclencher un Safe Fade ?",
            isPresented: $confirmSafeFade,
            titleVisibility: .visible
        ) {
            Button("Déclencher le Safe Fade", role: .destructive) {
                connection.sendCommand(.safeFade)
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le Mac décidera si la commande peut être exécutée sans créer de blanc.")
        }
        .confirmationDialog(
            "Reprendre le contrôle manuel ?",
            isPresented: $confirmManualControl,
            titleVisibility: .visible
        ) {
            Button("Arrêter les automatisations", role: .destructive) {
                connection.sendCommand(.takeManualControl)
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action demande au Mac de stopper immédiatement l’autopilote et de rendre la main au DJ.")
        }
    }

    private var connectionHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.status.title)
                    .font(.subheadline.bold())
                Text(snapshot.setName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(modeLabel(snapshot.mode))
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.indigo.opacity(0.15), in: Capsule())
        }
    }

    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EN COURS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let track = snapshot.currentTrack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.title2.bold())
                    Text(track.artist)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .tint(.indigo)

                HStack {
                    Text(format(snapshot.elapsed))
                    Spacer()
                    if let bpm = track.bpm {
                        Text("\(bpm, specifier: "%.0f") BPM")
                    }
                    Spacer()
                    Text("−\(format(max(0, snapshot.duration - snapshot.elapsed)))")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            } else {
                Text("Aucun titre en lecture")
                    .foregroundStyle(.secondary)
            }

            if let transition = snapshot.transitionLabel {
                HStack {
                    Label(transition, systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if let confidence = snapshot.transitionConfidence {
                        Text("\(confidence) %")
                            .font(.subheadline.bold())
                    }
                }
                .font(.subheadline)
                .padding(12)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var nextTrackCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "forward.end.fill")
                .font(.title2)
                .frame(width: 42, height: 42)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("ENSUITE")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(snapshot.nextTrack?.title ?? "Fin du set")
                    .font(.headline)
                if let artist = snapshot.nextTrack?.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if snapshot.canPause {
                    RemoteActionButton(title: "Pause", icon: "pause.fill") {
                        connection.sendCommand(.pauseAutopilot)
                    }
                }
                if snapshot.canResume {
                    RemoteActionButton(title: "Reprendre", icon: "play.fill") {
                        connection.sendCommand(.resumeAutopilot)
                    }
                }
                RemoteActionButton(
                    title: "Transition suivante",
                    icon: "forward.fill",
                    disabled: !snapshot.canSkipTransition
                ) {
                    connection.sendCommand(.skipTransition)
                }
            }

            HStack(spacing: 12) {
                RemoteActionButton(
                    title: "Safe Fade",
                    icon: "waveform.path.ecg",
                    destructive: true,
                    disabled: !snapshot.canSafeFade
                ) {
                    confirmSafeFade = true
                }

                RemoteActionButton(
                    title: "Contrôle manuel",
                    icon: "hand.raised.fill",
                    destructive: true,
                    disabled: !snapshot.canTakeManualControl
                ) {
                    confirmManualControl = true
                }
            }
        }
    }

    private var progress: Double {
        guard snapshot.duration > 0 else { return 0 }
        return min(max(snapshot.elapsed / snapshot.duration, 0), 1)
    }

    private func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func modeLabel(_ mode: RemoteMode) -> String {
        switch mode {
        case .idle: return "INACTIF"
        case .preflight: return "PRÉFLIGHT"
        case .live: return "LIVE"
        case .paused: return "PAUSE"
        case .manualControl: return "MANUEL"
        case .recovery: return "SECOURS"
        }
    }
}

private struct RemoteActionButton: View {
    let title: String
    let icon: String
    var destructive = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 78)
        }
        .buttonStyle(.bordered)
        .tint(destructive ? .red : .indigo)
        .disabled(disabled)
    }
}
