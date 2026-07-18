#if os(macOS)
import AppKit
import MixPilotCore
import MixPilotSystem

@MainActor
final class MixPilotCloudCoordinator: ObservableObject {
    @Published private(set) var connectionState: MixPilotCloudConnectionState = .idle
    @Published private(set) var identityState: MixPilotCloudIdentityState = .checking
    @Published private(set) var availableUpdate: MixPilotCloudRelease?
    @Published private(set) var availableMapping: MixPilotRemoteMappingRelease?
    @Published private(set) var activeCompatibilityOverride: MixPilotCompatibilityOverride?
    @Published private(set) var stagedMapping: MixPilotRemoteMappingInstallResult?
    @Published private(set) var lastHeartbeatAt: Date?
    @Published private(set) var statusDetail = "Les services en ligne sont facultatifs."
    @Published private(set) var mappingStatus = "Aucun correctif de compatibilité en attente."
    @Published private(set) var onlineDiagnosticsEnabled: Bool

    private let service: MixPilotCloudService
    private let remoteMappingService: MixPilotRemoteMappingService
    private let mappingInstaller: MixPilotRemoteMappingInstaller
    private let diagnosticsPreferences: MixPilotOnlineDiagnosticsPreferences
    private var loopTask: Task<Void, Never>?
    private var liveMode = false
    private var heartbeatCounter = 0
    private var backendContextProvider: @Sendable () async -> MixPilotCloudBackendContext? = { nil }

    private let appVersion: String
    private let appBuild: Int

    init(
        service: MixPilotCloudService = MixPilotCloudService(),
        remoteMappingService: MixPilotRemoteMappingService = MixPilotRemoteMappingService(),
        mappingInstaller: MixPilotRemoteMappingInstaller = MixPilotRemoteMappingInstaller(),
        diagnosticsPreferences: MixPilotOnlineDiagnosticsPreferences = MixPilotOnlineDiagnosticsPreferences()
    ) {
        self.service = service
        self.remoteMappingService = remoteMappingService
        self.mappingInstaller = mappingInstaller
        self.diagnosticsPreferences = diagnosticsPreferences
        self.onlineDiagnosticsEnabled = diagnosticsPreferences.isEnabled
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        self.appBuild = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 1
    }

    func configureBackendContextProvider(
        _ provider: @escaping @Sendable () async -> MixPilotCloudBackendContext?
    ) {
        backendContextProvider = provider
    }

    func setOnlineDiagnosticsEnabled(_ enabled: Bool) {
        diagnosticsPreferences.isEnabled = enabled
        onlineDiagnosticsEnabled = enabled
        statusDetail = enabled
            ? "Les diagnostics en ligne sont activés. Les données musicales et l’audio restent locaux."
            : "Les diagnostics en ligne sont désactivés. Les mises à jour restent disponibles."
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
            if !value, identityState.isSignedIn {
                await refreshRemoteCompatibility(showNoUpdateMessage: false)
            }
        }
    }

    func refreshIdentity() {
        Task { [weak self] in
            guard let self else { return }
            await updateIdentityFromStoredSession()
        }
    }

    func requestMagicLink(email: String) {
        identityState = .checking
        statusDetail = "Envoi du lien de connexion…"
        Task { [weak self] in
            guard let self else { return }
            do {
                let normalized = try await service.requestMagicLink(email: email)
                identityState = .linkSent(email: normalized)
                statusDetail = "Un lien de connexion a été envoyé à \(normalized). Ouvre-le sur ce Mac."
            } catch {
                identityState = .failed(message: humanIdentityMessage(error))
                statusDetail = humanIdentityMessage(error)
            }
        }
    }

    func handleAuthenticationCallback(_ url: URL) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let account = try await service.handleAuthenticationCallback(url)
                identityState = .signedIn(account)
                statusDetail = account.email.map { "Compte connecté • \($0)" } ?? "Compte MixPilot connecté."
                restartLoopAfterIdentityChange()
            } catch {
                identityState = .failed(message: humanIdentityMessage(error))
                statusDetail = humanIdentityMessage(error)
            }
        }
    }

    func signOut() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await service.signOut()
            } catch {
                // The SDK clears the local session before best-effort server logout.
            }
            identityState = .signedOut
            connectionState = .idle
            statusDetail = "Compte déconnecté • le Live local reste disponible."
            availableUpdate = nil
            availableMapping = nil
            activeCompatibilityOverride = nil
            lastHeartbeatAt = nil
            restartLoopAfterIdentityChange()
        }
    }

    func checkNow() {
        guard identityState.isSignedIn else {
            statusDetail = "Connecte ton compte MixPilot pour vérifier les mises à jour en ligne."
            return
        }
        Task { [weak self] in
            guard let self else { return }
            await checkForUpdate(showNoUpdateMessage: true)
            await refreshRemoteCompatibility(showNoUpdateMessage: true)
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
            mappingStatus = "Le correctif attendra la fin du Live."
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
        mappingStatus = "Correctif ignoré. La configuration locale actuelle reste inchangée."
    }

    func revealStagedPreset() {
        guard let url = stagedMapping?.generatedArtifactURL else {
            mappingStatus = "Ce correctif ne génère pas de fichier à importer. Le profil MixPilot est déjà préparé localement."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func rollbackMapping() {
        guard !liveMode else {
            mappingStatus = "La restauration attendra la fin du Live."
            return
        }

        Task { [weak self] in
            guard let self else { return }
            guard let backend = await backendContextProvider() else {
                mappingStatus = "Choisis le logiciel DJ concerné avant de restaurer le mapping."
                return
            }
            do {
                let result = try await mappingInstaller.rollback(
                    backend: backend.identifier,
                    controllerName: controllerName(for: backend)
                )
                stagedMapping = result
                mappingStatus = "L’ancien mapping de \(backend.identifier.displayName) a été restauré pour le prochain lancement."
                if let release = availableMapping {
                    var details = ["artifact_kind": result.artifactKind.rawValue]
                    if let hash = result.generatedArtifactSHA256 {
                        details["artifact_sha256"] = hash
                    }
                    try? await remoteMappingService.recordInstallation(
                        release: release,
                        status: .rolledBack,
                        previousProfileSHA256: result.previousProfileSHA256,
                        appliedProfileSHA256: result.appliedProfileSHA256,
                        details: details
                    )
                }
                if let url = result.generatedArtifactURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                mappingStatus = "L’ancien mapping n’a pas pu être restauré. La configuration actuelle n’a pas été modifiée."
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        Task { await service.closeSession() }
    }

    private func updateIdentityFromStoredSession() async {
        do {
            if let account = try await service.accountIfAvailable() {
                identityState = .signedIn(account)
            } else if case .linkSent = identityState {
                // Preserve the useful confirmation while the user opens the email.
            } else {
                identityState = .signedOut
            }
        } catch {
            identityState = .failed(message: humanIdentityMessage(error))
        }
    }

    private func restartLoopAfterIdentityChange() {
        loopTask?.cancel()
        loopTask = nil
        heartbeatCounter = 0
        start(liveMode: liveMode)
    }

    private func runLoop() async {
        var connected = false
        while !Task.isCancelled {
            do {
                guard let account = try await service.accountIfAvailable() else {
                    if case .linkSent = identityState {
                        // Keep link-sent state until the callback or a new request.
                    } else {
                        identityState = .signedOut
                    }
                    connectionState = .idle
                    statusDetail = "Connecte ton compte MixPilot pour activer les services en ligne facultatifs."
                    connected = false
                    try await Task.sleep(for: .seconds(30))
                    continue
                }

                identityState = .signedIn(account)
                let backend = await backendContextProvider()
                let diagnosticsEnabled = diagnosticsPreferences.isEnabled
                onlineDiagnosticsEnabled = diagnosticsEnabled

                if !connected {
                    connectionState = .connecting
                    statusDetail = "Connexion aux services en ligne…"
                    _ = try await service.connect(
                        appVersion: appVersion,
                        appBuild: appBuild,
                        backend: backend,
                        liveMode: liveMode,
                        telemetryEnabled: diagnosticsEnabled
                    )
                    connected = true
                    connectionState = .connected
                    statusDetail = diagnosticsEnabled
                        ? "Services en ligne disponibles • diagnostics autorisés."
                        : "Services en ligne disponibles • diagnostics désactivés."
                    await checkForUpdate(showNoUpdateMessage: false)
                    await refreshRemoteCompatibility(showNoUpdateMessage: false)
                    await processRemoteCommands()
                }

                try await service.heartbeat(
                    appVersion: appVersion,
                    appBuild: appBuild,
                    backend: backend,
                    liveMode: liveMode,
                    telemetryEnabled: diagnosticsEnabled
                )
                lastHeartbeatAt = Date()
                connectionState = .connected

                heartbeatCounter += 1
                if heartbeatCounter.isMultiple(of: 10) {
                    await checkForUpdate(showNoUpdateMessage: false)
                    await refreshRemoteCompatibility(showNoUpdateMessage: false)
                    await processRemoteCommands()
                }
                try await Task.sleep(for: .seconds(30))
            } catch is CancellationError {
                break
            } catch let error as MixPilotCloudIdentityError where error == .signedOut {
                identityState = .signedOut
                connectionState = .idle
                statusDetail = error.localizedDescription
                connected = false
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    break
                }
            } catch {
                connectionState = .offline("Services en ligne indisponibles")
                statusDetail = "Les services en ligne sont temporairement indisponibles. Le Live local peut continuer normalement."
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
        guard identityState.isSignedIn else { return }
        do {
            availableUpdate = try await service.checkForUpdate(currentBuild: appBuild)
            if let release = availableUpdate {
                statusDetail = "MixPilot \(release.version) est disponible."
            } else if showNoUpdateMessage {
                statusDetail = "MixPilot est à jour."
            }
        } catch {
            if showNoUpdateMessage {
                statusDetail = "La mise à jour n’a pas pu être vérifiée. Le Live local n’est pas affecté."
            }
        }
    }

    private func refreshRemoteCompatibility(showNoUpdateMessage: Bool) async {
        guard identityState.isSignedIn else { return }
        guard let backend = await backendContextProvider() else {
            availableMapping = nil
            activeCompatibilityOverride = nil
            if showNoUpdateMessage {
                mappingStatus = "Choisis un logiciel DJ pour rechercher un correctif compatible."
            }
            return
        }

        let controller = controllerName(for: backend)
        do {
            activeCompatibilityOverride = try await remoteMappingService.activeCompatibilityOverride(
                currentAppBuild: appBuild,
                backend: backend.identifier,
                softwareVersion: backend.softwareVersion,
                controllerName: controller
            )
            let release = try await remoteMappingService.checkForMappingUpdate(
                currentAppBuild: appBuild,
                backend: backend.identifier,
                softwareVersion: backend.softwareVersion,
                controllerName: controller
            )

            if let release,
               let local = try? await mappingInstaller.currentState(),
               local.releaseID == release.id,
               local.backend == nil || local.backend == backend.identifier {
                availableMapping = nil
                if showNoUpdateMessage {
                    mappingStatus = "Le correctif \(backend.identifier.displayName) v\(release.mappingVersion) est déjà installé."
                }
                return
            }

            availableMapping = release
            guard let release else {
                if showNoUpdateMessage {
                    mappingStatus = "Aucun nouveau correctif compatible avec cette version de \(backend.identifier.displayName)."
                }
                return
            }

            mappingStatus = "Correctif \(backend.identifier.displayName) v\(release.mappingVersion) disponible."
            try? await remoteMappingService.recordInstallation(
                release: release,
                status: .discovered,
                details: [
                    "app_build": String(appBuild),
                    "software_version": backend.softwareVersion ?? "unknown",
                    "dj_backend": backend.identifier.rawValue
                ]
            )
            if release.applyMode != .notify, !liveMode {
                await stageMapping(release)
            }
        } catch {
            if showNoUpdateMessage {
                mappingStatus = "Le catalogue de correctifs n’a pas pu être consulté. La configuration locale reste disponible."
            }
        }
    }

    private func stageMapping(_ release: MixPilotRemoteMappingRelease) async {
        guard !liveMode else {
            mappingStatus = "Le correctif attendra la fin du Live."
            return
        }
        guard let backend = await backendContextProvider(),
              release.backendIdentifier == backend.identifier else {
            mappingStatus = "Ce correctif ne correspond pas au logiciel DJ actif et ne sera pas installé."
            return
        }

        do {
            mappingStatus = "Vérification du correctif et sauvegarde du mapping actuel…"
            let result = try await mappingInstaller.stage(
                release: release,
                currentAppBuild: appBuild,
                backend: backend.identifier,
                softwareVersion: backend.softwareVersion,
                controllerName: controllerName(for: backend)
            )
            stagedMapping = result
            switch result.artifactKind {
            case .rekordboxCSV:
                mappingStatus = "Correctif v\(release.mappingVersion) prêt. Redémarre MixPilot puis importe le CSV dans rekordbox."
            case .profile:
                mappingStatus = "Correctif v\(release.mappingVersion) prêt pour \(backend.identifier.displayName). Redémarre MixPilot pour l’appliquer."
            }

            var details = [
                "artifact_kind": result.artifactKind.rawValue,
                "apply_mode": release.applyMode.rawValue
            ]
            if let hash = result.generatedArtifactSHA256 {
                details["artifact_sha256"] = hash
            }
            try? await remoteMappingService.recordInstallation(
                release: release,
                status: .staged,
                previousProfileSHA256: result.previousProfileSHA256,
                appliedProfileSHA256: result.appliedProfileSHA256,
                details: details
            )
            try? await service.record(MixPilotTelemetryEvent(
                category: "mapping",
                name: "remote_mapping_staged",
                payload: [
                    "mapping_version": String(release.mappingVersion),
                    "dj_backend": backend.identifier.rawValue,
                    "artifact_kind": result.artifactKind.rawValue
                ]
            ))
        } catch {
            mappingStatus = "Le correctif n’a pas été installé et le mapping actuel reste intact."
            try? await remoteMappingService.recordInstallation(
                release: release,
                status: .failed,
                errorCode: String(describing: type(of: error)),
                details: ["stage": "local_validation"]
            )
        }
    }

    private func controllerName(for backend: MixPilotCloudBackendContext) -> String {
        if let controllerName = backend.controllerName, !controllerName.isEmpty {
            return controllerName
        }
        return backend.identifier == .rekordbox
            ? RekordboxMIDIPresetGenerator.defaultControllerName
            : "MixPilot Virtual Controller"
    }

    private func processRemoteCommands() async {
        guard identityState.isSignedIn else { return }
        do {
            for command in try await service.pendingCommands() {
                let result: [String: String]
                let succeeded: Bool
                switch command.command {
                case "check_for_update", "refresh_configuration":
                    await checkForUpdate(showNoUpdateMessage: false)
                    await refreshRemoteCompatibility(showNoUpdateMessage: false)
                    result = ["action": "configuration_refreshed"]
                    succeeded = true
                case "flush_telemetry":
                    let backend = await backendContextProvider()
                    try await service.heartbeat(
                        appVersion: appVersion,
                        appBuild: appBuild,
                        backend: backend,
                        liveMode: liveMode,
                        telemetryEnabled: diagnosticsPreferences.isEnabled
                    )
                    result = ["action": diagnosticsPreferences.isEnabled ? "diagnostics_flushed" : "diagnostics_disabled"]
                    succeeded = true
                case "run_diagnostics":
                    try await service.record(MixPilotTelemetryEvent(
                        category: "diagnostics",
                        name: "remote_check_requested"
                    ))
                    result = ["action": diagnosticsPreferences.isEnabled ? "diagnostics_recorded" : "diagnostics_disabled"]
                    succeeded = true
                default:
                    result = ["error": "command_not_allowlisted"]
                    succeeded = false
                }
                try await service.completeCommand(command, succeeded: succeeded, result: result)
            }
        } catch {
            try? await service.record(MixPilotTelemetryEvent(
                category: "online_services",
                name: "command_poll_failed",
                severity: .warning,
                payload: ["error_type": String(describing: type(of: error))]
            ))
        }
    }

    private func humanIdentityMessage(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let message = localized.errorDescription,
           !message.isEmpty {
            return message
        }
        return "La connexion au compte MixPilot n’a pas pu être terminée. Le Live local reste disponible."
    }
}
#endif
