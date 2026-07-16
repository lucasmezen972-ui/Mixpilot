#if os(macOS)
import AppKit
import MixPilotCore
import MixPilotSystem
import SwiftUI

@MainActor
final class MixPilotCloudCoordinator: ObservableObject {
    @Published private(set) var connectionState: MixPilotCloudConnectionState = .idle
    @Published private(set) var availableUpdate: MixPilotCloudRelease?
    @Published private(set) var availableMapping: MixPilotRemoteMappingRelease?
    @Published private(set) var activeCompatibilityOverride: MixPilotCompatibilityOverride?
    @Published private(set) var stagedMapping: MixPilotRemoteMappingInstallResult?
    @Published private(set) var lastHeartbeatAt: Date?
    @Published private(set) var statusDetail = "Le cloud démarrera avec MixPilot."
    @Published private(set) var mappingStatus = "Aucun correctif de mapping en attente."

    private let service: MixPilotCloudService
    private let remoteMappingService: MixPilotRemoteMappingService
    private let mappingInstaller: MixPilotRemoteMappingInstaller
    private var loopTask: Task<Void, Never>?
    private var liveMode = false
    private var heartbeatCounter = 0

    private let appVersion: String
    private let appBuild: Int
    private let controllerName = RekordboxMIDIPresetGenerator.defaultControllerName

    init(
        service: MixPilotCloudService = MixPilotCloudService(),
        remoteMappingService: MixPilotRemoteMappingService = MixPilotRemoteMappingService(),
        mappingInstaller: MixPilotRemoteMappingInstaller = MixPilotRemoteMappingInstaller()
    ) {
        self.service = service
        self.remoteMappingService = remoteMappingService
        self.mappingInstaller = mappingInstaller
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
            if !value {
                await refreshRemoteCompatibility(showNoUpdateMessage: false)
            }
        }
    }

    func checkNow() {
        Task { [weak self] in
            guard let self else { return }
            await self.checkForUpdate(showNoUpdateMessage: true)
            await self.refreshRemoteCompatibility(showNoUpdateMessage: true)
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

    func installAvailableMapping() {
        guard let release = availableMapping else { return }
        guard !liveMode else {
            mappingStatus = "Installation refusée pendant le Live. Arrête le Live puis réessaie."
            return
        }
        Task { [weak self] in
            await self?.stageMapping(release)
        }
    }

    func dismissAvailableMapping() {
        guard let release = availableMapping, !release.mandatory else { return }
        Task {
            try? await remoteMappingService.recordInstallation(
                release: release,
                status: .dismissed,
                details: ["source": "user"]
            )
        }
        availableMapping = nil
        mappingStatus = "Correctif de mapping ignoré."
    }

    func revealStagedPreset() {
        guard let stagedMapping else { return }
        NSWorkspace.shared.activateFileViewerSelecting([stagedMapping.presetURL])
    }

    func rollbackMapping() {
        guard !liveMode else {
            mappingStatus = "Rollback refusé pendant le Live."
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.mappingInstaller.rollback(controllerName: self.controllerName)
                self.mappingStatus = "Ancien mapping restauré pour le prochain lancement."
                if let release = self.availableMapping {
                    try? await self.remoteMappingService.recordInstallation(
                        release: release,
                        status: .rolledBack,
                        previousProfileSHA256: result.previousProfileSHA256,
                        appliedProfileSHA256: result.appliedProfileSHA256,
                        details: ["preset_sha256": result.presetSHA256]
                    )
                }
                self.stagedMapping = result
                NSWorkspace.shared.activateFileViewerSelecting([result.presetURL])
            } catch {
                self.mappingStatus = "Rollback impossible : \(error.localizedDescription)"
            }
        }
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
                    await refreshRemoteCompatibility(showNoUpdateMessage: false)
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
                    await refreshRemoteCompatibility(showNoUpdateMessage: false)
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

    private func refreshRemoteCompatibility(showNoUpdateMessage: Bool) async {
        let rekordboxVersion = detectRekordboxVersion()
        do {
            activeCompatibilityOverride = try await remoteMappingService.activeCompatibilityOverride(
                currentAppBuild: appBuild,
                rekordboxVersion: rekordboxVersion,
                controllerName: controllerName
            )

            let release = try await remoteMappingService.checkForMappingUpdate(
                currentAppBuild: appBuild,
                rekordboxVersion: rekordboxVersion,
                controllerName: controllerName
            )
            if let release,
               let localState = try? await mappingInstaller.currentState(),
               localState.releaseID == release.id {
                availableMapping = nil
                if showNoUpdateMessage {
                    mappingStatus = "Le mapping distant v\(release.mappingVersion) est déjà installé."
                }
                return
            }

            availableMapping = release
            guard let release else {
                if showNoUpdateMessage {
                    mappingStatus = "Aucun nouveau mapping compatible."
                }
                return
            }

            mappingStatus = "Mapping rekordbox v\(release.mappingVersion) disponible."
            try? await remoteMappingService.recordInstallation(
                release: release,
                status: .discovered,
                details: [
                    "app_build": String(appBuild),
                    "rekordbox_version": rekordboxVersion ?? "unknown"
                ]
            )

            if release.applyMode != .notify, !liveMode {
                await stageMapping(release)
            }
        } catch {
            if showNoUpdateMessage {
                mappingStatus = "Catalogue de mapping indisponible : \(error.localizedDescription)"
            }
        }
    }

    private func stageMapping(_ release: MixPilotRemoteMappingRelease) async {
        guard !liveMode else {
            mappingStatus = "Le correctif attendra la fin du Live."
            return
        }
        do {
            mappingStatus = "Validation et sauvegarde du mapping actuel…"
            let result = try await mappingInstaller.stage(
                release: release,
                currentAppBuild: appBuild,
                rekordboxVersion: detectRekordboxVersion(),
                controllerName: controllerName
            )
            stagedMapping = result
            mappingStatus = "Mapping v\(release.mappingVersion) prêt. Redémarre MixPilot puis importe le CSV dans rekordbox."
            try? await remoteMappingService.recordInstallation(
                release: release,
                status: .staged,
                previousProfileSHA256: result.previousProfileSHA256,
                appliedProfileSHA256: result.appliedProfileSHA256,
                details: [
                    "preset_sha256": result.presetSHA256,
                    "apply_mode": release.applyMode.rawValue
                ]
            )
            try? await service.record(
                MixPilotTelemetryEvent(
                    category: "mapping",
                    name: "remote_mapping_staged",
                    payload: [
                        "mapping_version": String(release.mappingVersion),
                        "apply_mode": release.applyMode.rawValue
                    ]
                )
            )
        } catch {
            mappingStatus = "Mapping refusé : \(error.localizedDescription)"
            try? await remoteMappingService.recordInstallation(
                release: release,
                status: .failed,
                errorCode: String(describing: type(of: error)),
                details: ["stage": "local_validation"]
            )
            try? await service.record(
                MixPilotTelemetryEvent(
                    category: "mapping",
                    name: "remote_mapping_rejected",
                    severity: .error,
                    payload: ["error_type": String(describing: type(of: error))]
                )
            )
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
                    await refreshRemoteCompatibility(showNoUpdateMessage: false)
                    result = ["action": "updates_checked"]
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
                    await refreshRemoteCompatibility(showNoUpdateMessage: false)
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

                Button("Voir la mise à jour") { cloud.openAvailableUpdate() }
                    .buttonStyle(.borderedProminent)

                if !release.mandatory {
                    Button { cloud.dismissUpdate() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .modifier(MixPilotCloudBannerStyle(accent: .cyan))
        }
    }
}

struct MixPilotRemoteMappingBanner: View {
    @ObservedObject var cloud: MixPilotCloudCoordinator

    var body: some View {
        if let staged = cloud.stagedMapping {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mapping distant prêt pour le prochain lancement")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("Version \(staged.mappingVersion) • ancien profil sauvegardé • import rekordbox requis")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 18)
                Button("Afficher le CSV") { cloud.revealStagedPreset() }
                    .buttonStyle(.borderedProminent)
                Button("Rollback") { cloud.rollbackMapping() }
                    .buttonStyle(.bordered)
            }
            .modifier(MixPilotCloudBannerStyle(accent: .green))
        } else if let release = cloud.availableMapping {
            HStack(spacing: 14) {
                Image(systemName: release.mandatory ? "exclamationmark.shield.fill" : "slider.horizontal.3")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(release.mandatory ? .orange : .purple)
                VStack(alignment: .leading, spacing: 3) {
                    Text(release.mandatory ? "Correctif de mapping requis" : "Nouveau mapping compatible")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("Mapping v\(release.mappingVersion) • \(release.applyMode.displayName)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 18)
                Button("Installer au prochain lancement") { cloud.installAvailableMapping() }
                    .buttonStyle(.borderedProminent)
                if !release.mandatory {
                    Button { cloud.dismissAvailableMapping() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .modifier(MixPilotCloudBannerStyle(accent: release.mandatory ? .orange : .purple))
        }
    }
}

struct MixPilotCompatibilityWarningBanner: View {
    @ObservedObject var cloud: MixPilotCloudCoordinator

    var body: some View {
        if let rule = cloud.activeCompatibilityOverride,
           rule.blockLive || !rule.warnings.isEmpty || !rule.disabledActions.isEmpty {
            HStack(spacing: 14) {
                Image(systemName: rule.blockLive ? "hand.raised.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(rule.blockLive ? .red : .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.blockLive ? "Compatibilité Live suspendue" : "Ajustement de compatibilité")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text((rule.warnings.first ?? "Certaines commandes nécessitent une nouvelle validation.")
                        + (rule.disabledActions.isEmpty ? "" : " • \(rule.disabledActions.count) action(s) concernée(s)"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
                Spacer()
            }
            .modifier(MixPilotCloudBannerStyle(accent: rule.blockLive ? .red : .orange))
        }
    }
}

private struct MixPilotCloudBannerStyle: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .padding(14)
            .foregroundStyle(.white)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
    }
}
#endif
