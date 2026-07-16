#if os(macOS)
import AppKit
import MixPilotCore
import MixPilotSystem
import SwiftUI

@MainActor
final class MixPilotCloudCoordinator: ObservableObject {
    @Published private(set) var connectionState: MixPilotCloudConnectionState = .idle
    @Published private(set) var availableUpdate: MixPilotCloudRelease?
    @Published private(set) var lastHeartbeatAt: Date?
    @Published private(set) var statusDetail = "Le cloud démarrera avec MixPilot."

    private let service: MixPilotCloudService
    private var loopTask: Task<Void, Never>?
    private var liveMode = false
    private var heartbeatCounter = 0

    private let appVersion: String
    private let appBuild: Int

    init(service: MixPilotCloudService = MixPilotCloudService()) {
        self.service = service
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
        self.appBuild = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")
            ?? 1
    }

    func start(liveMode: Bool) {
        self.liveMode = liveMode
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func setLiveMode(_ value: Bool) {
        liveMode = value
        Task {
            try? await service.record(
                MixPilotTelemetryEvent(
                    category: "runtime",
                    name: value ? "live_started" : "live_stopped"
                )
            )
        }
    }

    func checkNow() {
        Task { [weak self] in
            await self?.checkForUpdate(showNoUpdateMessage: true)
        }
    }

    func openAvailableUpdate() {
        guard let availableUpdate else { return }
        NSWorkspace.shared.open(availableUpdate.preferredOpenURL)
    }

    func dismissUpdate() {
        guard availableUpdate?.mandatory != true else { return }
        availableUpdate = nil
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        Task { await service.closeSession() }
    }

    private func runLoop() async {
        var connected = false

        while !Task.isCancelled {
            do {
                if !connected {
                    connectionState = .connecting
                    statusDetail = "Authentification et enregistrement de ce Mac…"
                    _ = try await service.connect(
                        appVersion: appVersion,
                        appBuild: appBuild,
                        rekordboxVersion: detectRekordboxVersion(),
                        liveMode: liveMode
                    )
                    connected = true
                    connectionState = .connected
                    statusDetail = "Ce Mac transmet uniquement des diagnostics techniques filtrés."
                    await checkForUpdate(showNoUpdateMessage: false)
                    await processRemoteCommands()
                }

                try await service.heartbeat(
                    appVersion: appVersion,
                    appBuild: appBuild,
                    rekordboxVersion: detectRekordboxVersion(),
                    liveMode: liveMode
                )
                lastHeartbeatAt = Date()
                connectionState = .connected
                statusDetail = "Dernier contact cloud réussi."

                heartbeatCounter += 1
                if heartbeatCounter.isMultiple(of: 10) {
                    await checkForUpdate(showNoUpdateMessage: false)
                    await processRemoteCommands()
                }

                try await Task.sleep(for: .seconds(30))
            } catch is CancellationError {
                break
            } catch {
                connectionState = .offline(error.localizedDescription)
                statusDetail = error.localizedDescription
                connected = false
                do {
                    try await Task.sleep(for: .seconds(45))
                } catch {
                    break
                }
            }
        }
    }

    private func checkForUpdate(showNoUpdateMessage: Bool) async {
        do {
            let release = try await service.checkForUpdate(currentBuild: appBuild)
            availableUpdate = release
            if let release {
                statusDetail = "MixPilot \(release.version) (build \(release.build)) est disponible."
            } else if showNoUpdateMessage {
                statusDetail = "MixPilot est à jour."
            }
        } catch {
            if showNoUpdateMessage {
                statusDetail = "Vérification impossible : \(error.localizedDescription)"
            }
        }
    }

    private func processRemoteCommands() async {
        do {
            for command in try await service.pendingCommands() {
                let result: [String: String]
                let succeeded: Bool

                switch command.command {
                case "check_for_update":
                    await checkForUpdate(showNoUpdateMessage: false)
                    result = ["action": "update_checked"]
                    succeeded = true
                case "flush_telemetry":
                    try await service.heartbeat(
                        appVersion: appVersion,
                        appBuild: appBuild,
                        rekordboxVersion: detectRekordboxVersion(),
                        liveMode: liveMode
                    )
                    result = ["action": "telemetry_flushed"]
                    succeeded = true
                case "run_diagnostics":
                    try await service.record(
                        MixPilotTelemetryEvent(
                            category: "diagnostics",
                            name: "remote_check_requested",
                            severity: .info
                        )
                    )
                    result = ["action": "diagnostics_recorded"]
                    succeeded = true
                case "refresh_configuration":
                    await checkForUpdate(showNoUpdateMessage: false)
                    result = ["action": "configuration_refreshed"]
                    succeeded = true
                default:
                    result = ["error": "command_not_allowlisted"]
                    succeeded = false
                }

                try await service.completeCommand(
                    command,
                    succeeded: succeeded,
                    result: result
                )
            }
        } catch {
            try? await service.record(
                MixPilotTelemetryEvent(
                    category: "cloud",
                    name: "command_poll_failed",
                    severity: .warning,
                    payload: ["error_type": String(describing: type(of: error))]
                )
            )
        }
    }

    private func detectRekordboxVersion() -> String? {
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

struct MixPilotUpdateBanner: View {
    @ObservedObject var cloud: MixPilotCloudCoordinator

    var body: some View {
        if let release = cloud.availableUpdate {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.blue.opacity(0.2))
                    Image(systemName: release.mandatory
                          ? "exclamationmark.arrow.triangle.2.circlepath"
                          : "arrow.down.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(release.mandatory ? .orange : .cyan)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(release.mandatory ? "Mise à jour requise" : "Une mise à jour est disponible")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("MixPilot \(release.version) • build \(release.build)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer(minLength: 18)

                Button("Voir la mise à jour") {
                    cloud.openAvailableUpdate()
                }
                .buttonStyle(.borderedProminent)

                if !release.mandatory {
                    Button {
                        cloud.dismissUpdate()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(14)
            .foregroundStyle(.white)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.cyan.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        }
    }
}
#endif
