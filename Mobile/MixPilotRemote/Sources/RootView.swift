import MixPilotRemoteProtocol
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
                macName: RemotePresentationCopy.statusTitle(connection.status),
                code: $pairingCode,
                error: connection.lastError,
                onPair: {
                    connection.pair(using: pairingCode)
                    pairingCode = ""
                },
                onCancel: {
                    connection.disconnect(reason: RemoteLocalizedCopy.text("remote.reason.pairing_cancelled"))
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
                            .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 96, height: 96)
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text(RemoteLocalizedCopy.text("remote.ui.supervise_title"))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text(RemoteLocalizedCopy.text("remote.ui.supervise_body"))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 18)

                StatusCard(status: connection.status, error: connection.lastError)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(RemoteLocalizedCopy.text("remote.ui.available_macs")).font(.headline)
                        Spacer()
                        if discovery.isSearching { ProgressView().controlSize(.small) }
                        Button {
                            discovery.stop()
                            discovery.start()
                        } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel(RemoteLocalizedCopy.text("remote.ui.refresh_search"))
                    }

                    if discovery.endpoints.isEmpty {
                        ContentUnavailableView(
                            RemoteLocalizedCopy.text("remote.ui.no_mac"),
                            systemImage: "laptopcomputer.slash",
                            description: Text(RemoteLocalizedCopy.text("remote.ui.no_mac_description"))
                        )
                        .frame(minHeight: 210)
                    } else {
                        ForEach(discovery.endpoints) { endpoint in
                            Button { connection.connect(to: endpoint) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "laptopcomputer")
                                        .font(.title2)
                                        .frame(width: 38, height: 38)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 11))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(endpoint.name).font(.headline)
                                        Text(RemoteLocalizedCopy.text("remote.ui.available_local"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button { connection.startDemo() } label: {
                    Label(RemoteLocalizedCopy.text("remote.ui.demo_button"), systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text(RemoteLocalizedCopy.text("remote.ui.demo_disclaimer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
                Text(RemotePresentationCopy.statusTitle(status)).font(.subheadline.weight(.semibold))
                Spacer()
            }
            if let detail = status.detail ?? humanError(error), !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func humanError(_ error: String?) -> String? {
        guard error != nil else { return nil }
        return RemoteLocalizedCopy.text("remote.ui.connection_generic_error")
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
                Text(RemoteLocalizedCopy.text("remote.ui.pairing_title"))
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text(macName).font(.subheadline).foregroundStyle(.secondary)

                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .onChange(of: code) { _, value in
                        code = String(value.filter(\.isNumber).prefix(6))
                    }

                if error != nil {
                    Text(RemoteLocalizedCopy.text("remote.ui.pairing_error"))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button(RemoteLocalizedCopy.text("remote.ui.pair_button"), action: onPair)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(code.count != 6)
                Button(RemoteLocalizedCopy.text("remote.ui.cancel"), role: .cancel, action: onCancel)
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
            VStack(spacing: 16) {
                connectionHeader
                if let backend = snapshot.backend { backendCard(backend) }
                if let alert = snapshot.alert { alertCard(alert) }
                nowPlayingCard
                nextTrackCard
                controls

                if let acknowledgement = connection.lastAcknowledgement {
                    Label(
                        acknowledgement.message,
                        systemImage: acknowledgement.accepted ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(acknowledgement.accepted ? .green : .red)
                    .padding(.horizontal, 4)
                }
            }
            .padding(18)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(RemoteLocalizedCopy.text("remote.ui.disconnect")) { connection.disconnect() }
            }
        }
        .confirmationDialog(
            RemoteLocalizedCopy.text("remote.ui.safe_fade_title"),
            isPresented: $confirmSafeFade,
            titleVisibility: .visible
        ) {
            Button(RemoteLocalizedCopy.text("remote.ui.safe_fade_action"), role: .destructive) {
                connection.sendCommand(.safeFade)
            }
            Button(RemoteLocalizedCopy.text("remote.ui.cancel"), role: .cancel) {}
        } message: {
            Text(RemoteLocalizedCopy.text("remote.ui.safe_fade_message"))
        }
        .confirmationDialog(
            RemoteLocalizedCopy.text("remote.ui.manual_title"),
            isPresented: $confirmManualControl,
            titleVisibility: .visible
        ) {
            Button(RemoteLocalizedCopy.text("remote.ui.manual_action"), role: .destructive) {
                connection.sendCommand(.takeManualControl)
            }
            Button(RemoteLocalizedCopy.text("remote.ui.cancel"), role: .cancel) {}
        } message: {
            Text(RemoteLocalizedCopy.text("remote.ui.manual_message"))
        }
    }

    private var connectionHeader: some View {
        HStack(spacing: 12) {
            Circle().fill(.green).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(RemotePresentationCopy.statusTitle(connection.status)).font(.subheadline.bold())
                Text(snapshot.setName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(modeLabel(snapshot.mode))
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.indigo.opacity(0.15), in: Capsule())
        }
    }

    private func backendCard(_ backend: RemoteBackendSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: backendSymbol(backend.identifier))
                    .font(.title2)
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text(backend.identifier.displayName).font(.headline)
                    Text([
                        backend.modeLabel,
                        backend.softwareVersion.map { RemoteLocalizedCopy.format("remote.ui.version", $0) }
                    ].compactMap { $0 }.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let activeDeck = snapshot.activeDeck {
                    Text(RemoteLocalizedCopy.format("remote.ui.deck", activeDeck))
                        .font(.caption2.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.indigo.opacity(0.12), in: Capsule())
                }
            }

            if let audio = snapshot.audioStatus {
                Label(audio, systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !backend.degradedCapabilities.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(RemoteLocalizedCopy.text("remote.ui.degraded"))
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Text(backend.degradedCapabilities.prefix(4).joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func alertCard(_ alert: String) -> some View {
        Label(alert, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(RemoteLocalizedCopy.text("remote.ui.now_playing"))
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let track = snapshot.currentTrack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title).font(.title2.bold())
                    Text(track.artist).font(.headline).foregroundStyle(.secondary)
                }
                ProgressView(value: progress).tint(.indigo)
                HStack {
                    Text(format(snapshot.elapsed))
                    Spacer()
                    if let bpm = track.bpm { Text("\(bpm, specifier: "%.0f") BPM") }
                    Spacer()
                    Text("−\(format(max(0, snapshot.duration - snapshot.elapsed)))")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            } else {
                Text(RemoteLocalizedCopy.text("remote.ui.no_track")).foregroundStyle(.secondary)
            }

            if let transition = snapshot.transitionLabel {
                HStack {
                    Label(transition, systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if let confidence = snapshot.transitionConfidence {
                        Text("\(confidence) %").font(.subheadline.bold())
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
                Text(RemoteLocalizedCopy.text("remote.ui.next"))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(snapshot.nextTrack?.title ?? RemoteLocalizedCopy.text("remote.ui.end_set")).font(.headline)
                if let artist = snapshot.nextTrack?.artist {
                    Text(artist).font(.subheadline).foregroundStyle(.secondary)
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
                    RemoteActionButton(
                        title: RemoteLocalizedCopy.text("remote.ui.pause"),
                        icon: "pause.fill"
                    ) { connection.sendCommand(.pauseAutopilot) }
                }
                if snapshot.canResume {
                    RemoteActionButton(
                        title: RemoteLocalizedCopy.text("remote.ui.resume"),
                        icon: "play.fill"
                    ) { connection.sendCommand(.resumeAutopilot) }
                }
                RemoteActionButton(
                    title: RemoteLocalizedCopy.text("remote.ui.change_transition"),
                    icon: "forward.fill",
                    disabled: !snapshot.canSkipTransition
                ) { connection.sendCommand(.skipTransition) }
            }

            HStack(spacing: 12) {
                RemoteActionButton(
                    title: RemoteLocalizedCopy.text("remote.ui.emergency_transition"),
                    icon: "waveform.path.ecg",
                    destructive: true,
                    disabled: !snapshot.canSafeFade
                ) { confirmSafeFade = true }

                RemoteActionButton(
                    title: RemoteLocalizedCopy.text("remote.ui.take_control"),
                    icon: "hand.raised.fill",
                    destructive: true,
                    disabled: !snapshot.canTakeManualControl
                ) { confirmManualControl = true }
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
        case .idle: RemoteLocalizedCopy.text("remote.mode.idle")
        case .preflight: RemoteLocalizedCopy.text("remote.mode.preflight")
        case .live: RemoteLocalizedCopy.text("remote.mode.live")
        case .paused: RemoteLocalizedCopy.text("remote.mode.paused")
        case .manualControl: RemoteLocalizedCopy.text("remote.mode.manual")
        case .recovery: RemoteLocalizedCopy.text("remote.mode.recovery")
        }
    }

    private func backendSymbol(_ identifier: RemoteDJBackendIdentifier) -> String {
        switch identifier {
        case .djay: "wand.and.stars.inverse"
        case .rekordbox: "record.circle"
        case .serato: "music.note.list"
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
                Image(systemName: icon).font(.title2)
                Text(title).font(.caption.bold()).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 78)
        }
        .buttonStyle(.bordered)
        .tint(destructive ? .red : .indigo)
        .disabled(disabled)
    }
}
