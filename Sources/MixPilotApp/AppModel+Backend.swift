#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotRuntime

@MainActor
extension AppModel {
    func selectBackend(_ identifier: DJBackendIdentifier) {
        guard !isLiveRunning else {
            runtimeStatus = "Le logiciel DJ ne peut pas être changé pendant le Live. Reprends la main avant de changer."
            return
        }

        Task {
            do {
                guard let backendRegistry else {
                    throw DJBackendError.unavailable(identifier)
                }
                try await backendRegistry.select(identifier)
                selectedBackend = identifier
                DJSoftwareSelectionStore.selected = DJSoftware(identifier)
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
        let capabilities = descriptor?.capabilities ?? DJBackendCapabilities()
        let project = preparedProject
        let adaptations = project.map {
            TransitionCapabilityNegotiator().adaptSet($0.transitions, to: capabilities)
        } ?? []
        let fallbackCount = adaptations.filter { $0.usedFallback && $0.isExecutable }.count
        let blockedCount = adaptations.filter { !$0.isExecutable }.count

        preflightReport = PreflightEvaluator().evaluate(
            PreflightInput(
                backendIdentifier: selectedBackend,
                backendEnvironment: descriptor?.environment,
                backendCapabilities: capabilities,
                backendValidation: backendValidationReport,
                accessibilityGranted: accessibilityStatus == "Autorisée",
                midiAvailable: midiController != nil,
                mappingCompletion: mappingProfile.completionRatio,
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
            backendStatus = "Initialisation des logiciels DJ"
            backendValidationReport = nil
            evaluatePreflight()
            return
        }

        backendDescriptors = await backendRegistry.availableBackends()
        selectedBackend = await backendRegistry.selectedBackend()

        guard let selectedBackend,
              let descriptor = backendDescriptors.first(where: { $0.identifier == selectedBackend }) else {
            backendStatus = "Choisis djay Pro, rekordbox ou Serato DJ Pro"
            accessibilityStatus = "En attente du choix"
            libraryRowCount = 0
            backendValidationReport = nil
            runtimeCoordinator = nil
            evaluatePreflight()
            return
        }

        backendStatus = descriptor.environment.isRunning
            ? "\(descriptor.displayName) connecté\(descriptor.environment.softwareVersion.map { " • v\($0)" } ?? "")"
            : descriptor.environment.isInstalled
                ? "\(descriptor.displayName) est installé mais fermé"
                : "\(descriptor.displayName) n’est pas installé"

        let observation = accessibilityBridge.observe(backend: selectedBackend)
        accessibilityStatus = observation.accessibilityGranted ? "Autorisée" : "Action requise"
        audioStatus = audioMonitor.isRunning ? "Surveillance active" : "Surveillance arrêtée"
        libraryRowCount = observation.accessibilityGranted
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

        if observation.isRunning && observation.accessibilityGranted {
            runtimeStatus = "\(descriptor.displayName) observable"
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

    func legacySoftware(_ identifier: DJBackendIdentifier) -> DJSoftware {
        DJSoftware(identifier)
    }

    func humanMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let message = localized.errorDescription,
           !message.isEmpty {
            return message
        }
        return "Une étape n’a pas pu être terminée. Le Live reste arrêté et le contrôle manuel est disponible."
    }
}
#endif
