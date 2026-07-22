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
        onlineDiagnosticsEnabled = diagnosticsPreferences.isEnabled
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        appBuild = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 1
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
        heartbeatCounter = 0
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func setLiveMode(_ value: Bool) {
        liveMode = value
        Task { [weak self] in
            guard let self else { return }
            do {
                try await service.record(
                    MixPilotTelemetryEvent(
                        category: "runtime",
                        name: value ? "live_started" : "live_stopped"
                    )
                )
            } catch {
                statusDetail = "Le changement de mode Live reste local : l’événement n’a pas pu être transmis."
            }
            if !value, identityState.isSignedIn {
                _ = await refreshRemoteCompatibility(showNoUpdateMessage: false)
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
                let message = humanIdentityMessage(error)
                identityState = .failed(message: message)
                statusDetail = message
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
                let message = humanIdentityMessage(error)
                identityState = .failed(message: message)
                statusDetail = message
            }
        }
    }

    func signOut() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await service.signOut()
            } catch {
                // Local session cleanup remains the priority; server logout is best-effort.
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
            _ = await checkForUpdate(showNoUpdateMessage: true)
            _ = await refreshRemoteCompatibility(showNoUpdateMessage: true)
        }
    }

    func openAvailableUpdate() {
        guard let availableUpdate else { return }
        if !NSWorkspace.shared.open(availableUpdate.preferredOpenURL) {
            statusDetail = "La page de mise à jour n’a pas pu être ouverte."
        }
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
        availableMapping = nil
        mappingStatus = "Correctif ignoré. La configuration locale actuelle reste inchangée."
        Task { [weak self] in
            guard let self else { return }
            do {
                try await remoteMappingService.recordInstallation(
                    release: release,
                    status: .dismissed,
                    details: ["source": "user"]
                )
            } catch {
                mappingStatus += " L’accusé de réception en ligne n’a pas été transmis."
            }
        }
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
                    do {
                        try await remoteMappingService.recordInstallation(
                            release: release,
                            status: .rolledBack,
                            previousProfileSHA256: result.previousProfileSHA256,
                            appliedProfileSHA256: result.appliedProfileSHA256,
                            details: details
                        )
                    } catch {
                        mappingStatus += " La restauration locale est confirmée, mais le cloud n’a pas reçu l’accusé."
                    }
                }
                if let url = result.generatedArtifactURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                mappingStatus = "L’ancien mapping n’a pas pu être restauré. La configuration actuelle n’a pas été modifiée : \(humanCloudError(error))"
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
                // Preserve the useful confirmation while the user opens the e-mail.
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
        defer { loopTask = nil }
        var connected = false
        while !Task.isCancelled {
            do {
                guard let account = try await service.accountIfAvailable() else {
                    if case .linkSent = identityState {
                        // Keep the confirmation while the callback is pending.
                    } else {
                        identityState = .signedOut
                    }
                    connectionState = .idle
                    statusDetail = "Connecte ton compte MixPilot pour activer les services en ligne facultatifs."
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
                    _ = await checkForUpdate(showNoUpdateMessage: false)
                    _ = await refreshRemoteCompatibility(showNoUpdateMessage: false)
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
                    _ = await checkForUpdate(showNoUpdateMessage: false)
                    _ = await refreshRemoteCompatibility(showNoUpdateMessage: false)
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
            } catch MixPilotCloudError.authenticationUnavailable {
                connectionState = .offline("Services en ligne désactivés")
                statusDetail = "L’authentification en ligne est désactivée côté service. Le Live et les mappings locaux restent disponibles."
                break
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

    @discardableResult
    private func checkForUpdate(showNoUpdateMessage: Bool) async -> Bool {
        guard identityState.isSignedIn else { return false }
        do {
            availableUpdate = try await service.checkForUpdate(currentBuild: appBuild)
            if let release = availableUpdate {
                statusDetail = "MixPilot \(release.version) est disponible."
            } else if showNoUpdateMessage {
                statusDetail = "MixPilot est à jour."
            }
            return true
        } catch {
            if showNoUpdateMessage {
                statusDetail = "La mise à jour n’a pas pu être vérifiée. Le Live local n’est pas affecté."
            }
            return false
        }
    }

    @discardableResult
    private func refreshRemoteCompatibility(showNoUpdateMessage: Bool) async -> Bool {
        guard identityState.isSignedIn else { return false }
        guard let backend = await backendContextProvider() else {
            availableMapping = nil
            activeCompatibilityOverride = nil
            if showNoUpdateMessage {
                mappingStatus = "Choisis un logiciel DJ pour rechercher un correctif compatible."
            }
            return false
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

            if let release {
                do {
                    if let local = try await mappingInstaller.currentState(),
                       local.releaseID == release.id,
                       local.backend == nil || local.backend == backend.identifier {
                        availableMapping = nil
                        if showNoUpdateMessage {
                            mappingStatus = "Le correctif \(backend.identifier.displayName) v\(release.mappingVersion) est déjà installé."
                        }
                        return true
                    }
                } catch {
                    availableMapping = release
                    mappingStatus = "L’état du correctif local est illisible. L’installation automatique est suspendue ; une installation manuelle reste proposée."
                    return false
                }
            }

            availableMapping = release
            guard let release else {
                if showNoUpdateMessage {
                    mappingStatus = "Aucun nouveau correctif compatible avec cette version de \(backend.identifier.displayName)."
                }
                return true
            }

            mappingStatus = "Correctif \(backend.identifier.displayName) v\(release.mappingVersion) disponible."
            do {
                try await remoteMappingService.recordInstallation(
                    release: release,
                    status: .discovered,
                    details: [
                        "app_build": String(appBuild),
                        "software_version": backend.softwareVersion ?? "unknown",
                        "dj_backend": backend.identifier.rawValue
                    ]
                )
            } catch {
                mappingStatus += " Le catalogue n’a pas reçu l’accusé de découverte."
            }
            if release.applyMode != .notify, !liveMode {
                await stageMapping(release)
            }
            return true
        } catch {
            if showNoUpdateMessage {
                mappingStatus = "Le catalogue de correctifs n’a pas pu être consulté. La configuration locale reste disponible."
            }
            return false
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
            do {
                try await remoteMappingService.recordInstallation(
                    release: release,
                    status: .staged,
                    previousProfileSHA256: result.previousProfileSHA256,
                    appliedProfileSHA256: result.appliedProfileSHA256,
                    details: details
                )
            } catch {
                mappingStatus += " Le cloud n’a pas reçu la confirmation d’installation."
            }
            do {
                try await service.record(MixPilotTelemetryEvent(
                    category: "mapping",
                    name: "remote_mapping_staged",
                    payload: [
                        "mapping_version": String(release.mappingVersion),
                        "dj_backend": backend.identifier.rawValue,
                        "artifact_kind": result.artifactKind.rawValue
                    ]
                ))
            } catch {
                statusDetail = "Le correctif est prêt localement, mais sa télémétrie n’a pas été transmise."
            }
        } catch {
            mappingStatus = "Le correctif n’a pas été installé et le mapping actuel reste intact : \(humanCloudError(error))"
            do {
                try await remoteMappingService.recordInstallation(
                    release: release,
                    status: .failed,
                    errorCode: String(describing: type(of: error)),
                    details: ["stage": "local_validation"]
                )
            } catch {
                mappingStatus += " L’échec n’a pas pu être enregistré en ligne."
            }
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
            let commands = try await service.pendingCommands()
            for command in commands {
                let outcome = await executeRemoteCommand(command)
                do {
                    try await service.completeCommand(
                        command,
                        succeeded: outcome.succeeded,
                        result: outcome.result
                    )
                } catch {
                    statusDetail = "Une commande distante a été traitée localement mais son accusé de réception n’a pas pu être envoyé."
                    break
                }
            }
        } catch {
            statusDetail = "Les commandes distantes n’ont pas pu être consultées. Le contrôle local reste prioritaire."
            do {
                try await service.record(MixPilotTelemetryEvent(
                    category: "online_services",
                    name: "command_poll_failed",
                    severity: .warning,
                    payload: ["error_type": String(describing: type(of: error))]
                ))
            } catch {
                // The local UI already reports the polling failure. A telemetry
                // failure must never recurse or affect the local runtime.
            }
        }
    }

    private func executeRemoteCommand(
        _ command: MixPilotCloudCommand
    ) async -> (succeeded: Bool, result: [String: String]) {
        do {
            switch command.command {
            case "check_for_update", "refresh_configuration":
                let updateSucceeded = await checkForUpdate(showNoUpdateMessage: false)
                let mappingSucceeded = await refreshRemoteCompatibility(showNoUpdateMessage: false)
                return (
                    updateSucceeded && mappingSucceeded,
                    ["action": updateSucceeded && mappingSucceeded
                        ? "configuration_refreshed"
                        : "configuration_refresh_incomplete"]
                )

            case "flush_telemetry":
                let backend = await backendContextProvider()
                try await service.heartbeat(
                    appVersion: appVersion,
                    appBuild: appBuild,
                    backend: backend,
                    liveMode: liveMode,
                    telemetryEnabled: diagnosticsPreferences.isEnabled
                )
                return (
                    true,
                    ["action": diagnosticsPreferences.isEnabled
                        ? "diagnostics_flushed"
                        : "diagnostics_disabled"]
                )

            case "run_diagnostics":
                if diagnosticsPreferences.isEnabled {
                    try await service.record(MixPilotTelemetryEvent(
                        category: "diagnostics",
                        name: "remote_check_requested"
                    ))
                    return (true, ["action": "diagnostics_recorded"])
                }
                return (true, ["action": "diagnostics_disabled"])

            default:
                return (false, ["error": "command_not_allowlisted"])
            }
        } catch {
            return (
                false,
                [
                    "error": "command_execution_failed",
                    "error_type": String(describing: type(of: error))
                ]
            )
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

    private func humanCloudError(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return "erreur technique non identifiée"
    }
}
#endif
