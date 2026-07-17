#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotRuntime

@MainActor
extension AppModel {
    func selectBackend(_ identifier: DJBackendIdentifier) {
        guard !isLiveRunning else {
            runtimeStatus = AppLocalizedCopy.status("status.backend.change_live_forbidden")
            return
        }

        Task {
            do {
                guard let backendRegistry else {
                    throw DJBackendError.unavailable(identifier)
                }
                try await backendRegistry.select(identifier)
                selectedBackend = identifier
                try await associatePreparedProject(with: identifier)
                try await rebuildRuntimeCoordinator()
                await refreshEnvironmentNow()
            } catch {
                runtimeStatus = humanMessage(for: error)
            }
        }
    }

    func refreshEnvironment() {
        powerStatus = powerProbe.read()
        Task { await refreshEnvironmentNow() }
    }

    func requestAccessibility() {
        accessibilityBridge.requestAccessibilityPrompt()
        refreshEnvironment()
    }

    func evaluatePreflight() {
        let descriptor = selectedBackend.flatMap { identifier in
            backendDescriptors.first { $0.identifier == identifier }
        }
        let rawCapabilities = descriptor?.capabilities ?? DJBackendCapabilities()
        let capabilities = rawCapabilities.applyingRuntimeAvailability(
            accessibilityGranted: accessibilityGranted
        )
        let liveCapabilities = capabilities.confirmedForLiveOnly()
        let project = preparedProject
        let adaptations = project.map {
            TransitionCapabilityNegotiator().adaptSet($0.transitions, to: liveCapabilities)
        } ?? []
        let fallbackCount = adaptations.filter { $0.usedFallback && $0.isExecutable }.count
        let blockedCount = adaptations.filter { !$0.isExecutable }.count
        let projectBackendMatches = project == nil || project?.backend == selectedBackend

        preflightReport = PreflightEvaluator().evaluate(
            PreflightInput(
                backendIdentifier: projectBackendMatches ? selectedBackend : nil,
                backendEnvironment: descriptor?.environment,
                backendCapabilities: capabilities,
                backendValidation: backendValidationReport,
                accessibilityGranted: accessibilityGranted,
                midiAvailable: midiController != nil,
                mappingCompletion: mappingProfile.liveControlCoverageRatio,
                audioMonitorRunning: audioMonitor.isRunning,
                internetAvailable: connectivityStatus.isAvailable,
                internetRequiredForPreparedSet: false,
                onlineServicesAvailable: connectivityStatus.isAvailable,
                connectedToPower: powerStatus.connectedToPower,
                batteryLevel: powerStatus.batteryLevel,
                emergencyAudioReady: emergencyDuration >= 1_800,
                emergencyDuration: emergencyDuration,
                projectPrepared: project != nil,
                projectLocked: project?.locked == true,
                trackCount: project?.tracks.count ?? 0,
                transitionCount: project?.transitions.count ?? 0,
                lowConfidenceTransitionCount: project?.reviewTransitionCount ?? 0,
                fallbackTransitionCount: fallbackCount,
                blockedTransitionCount: blockedCount
            )
        )
    }

    func refreshEnvironmentNow() async {
        guard let backendRegistry else {
            backendStatus = AppLocalizedCopy.status("status.backend.initializing")
            accessibilityGranted = false
            backendValidationReport = nil
            evaluatePreflight()
            return
        }

        backendDescriptors = await backendRegistry.availableBackends()
        selectedBackend = await backendRegistry.selectedBackend()

        guard let selectedBackend,
              let descriptor = backendDescriptors.first(where: { $0.identifier == selectedBackend }) else {
            backendStatus = AppLocalizedCopy.status("status.backend.choose_three")
            accessibilityGranted = false
            accessibilityStatus = AppLocalizedCopy.status("status.backend.accessibility_waiting")
            libraryRowCount = 0
            backendValidationReport = nil
            runtimeCoordinator = nil
            evaluatePreflight()
            return
        }

        if descriptor.environment.isRunning {
            if let version = descriptor.environment.softwareVersion {
                backendStatus = AppLocalizedCopy.statusFormat(
                    "status.backend.connected_version",
                    descriptor.displayName,
                    version
                )
            } else {
                backendStatus = AppLocalizedCopy.statusFormat(
                    "status.backend.connected",
                    descriptor.displayName
                )
            }
        } else if descriptor.environment.isInstalled {
            backendStatus = AppLocalizedCopy.statusFormat(
                "status.backend.installed_closed",
                descriptor.displayName
            )
        } else {
            backendStatus = AppLocalizedCopy.statusFormat(
                "status.backend.not_installed",
                descriptor.displayName
            )
        }

        let observation = accessibilityBridge.observe(backend: selectedBackend)
        accessibilityGranted = observation.accessibilityGranted
        accessibilityStatus = AppLocalizedCopy.status(
            accessibilityGranted
                ? "status.backend.accessibility_authorized"
                : "status.backend.accessibility_required"
        )
        audioStatus = AppLocalizedCopy.status(
            audioMonitor.isRunning
                ? "status.backend.audio_active"
                : "status.backend.audio_stopped"
        )
        libraryRowCount = accessibilityGranted
            ? accessibilityBridge.libraryRows(
                backend: selectedBackend,
                maxRows: 1_000
            ).count
            : 0

        if let backend = try? await backendRegistry.activeBackend() {
            backendValidationReport = await backend.validateConfiguration()
        } else {
            backendValidationReport = nil
        }

        if observation.isRunning && accessibilityGranted {
            runtimeStatus = AppLocalizedCopy.statusFormat(
                "status.backend.observable",
                descriptor.displayName
            )
        }

        if !isLiveRunning {
            try? await rebuildRuntimeCoordinator()
        }
        evaluatePreflight()
    }

    func rebuildRuntimeCoordinator() async throws {
        guard !isLiveRunning else { throw DJBackendError.liveChangeForbidden }
        guard let backendRegistry else { return }
        let backend = try await backendRegistry.activeBackend()
        runtimeCoordinator = LiveAutopilotCoordinator(backend: backend)
    }

    private func associatePreparedProject(
        with identifier: DJBackendIdentifier
    ) async throws {
        guard var project = preparedProject else { return }
        guard project.backend != identifier else { return }

        project.selectBackend(identifier)
        preparedProject = project
        liveArmed = false
        _ = try await projectStore.save(project)
        runtimeStatus = AppLocalizedCopy.statusFormat(
            "status.backend.project_associated",
            identifier.displayName
        )
    }

    func legacySoftware(_ identifier: DJBackendIdentifier) -> DJSoftware {
        DJSoftware(identifier)
    }

    func humanMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let message = localized.errorDescription,
           !message.isEmpty {
            return message
        }
        return AppLocalizedCopy.status("status.backend.generic_failure")
    }
}
#endif
