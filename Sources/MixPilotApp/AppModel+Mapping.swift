#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotMIDI
import MixPilotSystem

@MainActor
extension AppModel {
    func configureMIDI() {
        guard midiController == nil else {
            evaluatePreflight()
            return
        }

        do {
            let controller = try CoreMIDIController()
            let store = MIDIMappingProfileStore()
            midiController = controller
            mappingStore = store
            midiStatus = AppLocalizedCopy.status("status.mapping.virtual_active")

            Task {
                let profile = (try? await store.load()) ?? .developmentDefault
                mappingProfile = profile
                let mapped = MappedMIDIController(controller: controller, profile: profile)
                mappedController = mapped

                let registry = DJBackendRegistry(
                    backends: [
                        StrictVerificationDJBackend(
                            DjayBackend(midi: mapped, validationStore: commandValidationStore)
                        ),
                        StrictVerificationDJBackend(
                            RekordboxBackend(midi: mapped, validationStore: commandValidationStore)
                        ),
                        StrictVerificationDJBackend(
                            SeratoBackend(midi: mapped, validationStore: commandValidationStore)
                        ),
                    ],
                    selectionStore: MigratingDJBackendSelectionStore()
                )
                backendRegistry = registry
                selectedBackend = await registry.restoreSelection()

                if selectedBackend != nil {
                    try? await rebuildRuntimeCoordinator()
                } else {
                    runtimeCoordinator = nil
                }

                midiStatus = AppLocalizedCopy.statusFormat(
                    "status.mapping.coverage",
                    Int(profile.liveControlCoverageRatio * 100)
                )
                await refreshEnvironmentNow()
            }
        } catch {
            midiStatus = AppLocalizedCopy.status("status.mapping.create_failed")
            runtimeStatus = humanMessage(for: error)
            evaluatePreflight()
        }
    }

    func resetDefaultMapping() {
        mappingProfile = .developmentDefault
        Task {
            await mappedController?.replaceProfile(mappingProfile)
            _ = try? await mappingStore?.save(mappingProfile)
            midiStatus = AppLocalizedCopy.status("status.mapping.default_loaded")
            await refreshEnvironmentNow()
        }
    }

    func saveMapping() {
        Task {
            do {
                _ = try await mappingStore?.save(mappingProfile)
                await mappedController?.replaceProfile(mappingProfile)
                midiStatus = AppLocalizedCopy.status("status.mapping.saved")
                await refreshEnvironmentNow()
            } catch {
                midiStatus = AppLocalizedCopy.status("status.mapping.save_failed")
            }
        }
    }

    func testMapping(_ action: DJControlAction) {
        Task {
            do {
                guard let mappedController else {
                    throw DJBackendError.commandRejected(
                        AppLocalizedCopy.status("status.mapping.controller_unavailable")
                    )
                }
                if let mapping = mappingProfile[action], mapping.kind == .controlChange {
                    try await mappedController.set(action, value: 0.5)
                } else {
                    try await mappedController.trigger(action)
                }
                midiStatus = AppLocalizedCopy.status("status.mapping.command_sent")
            } catch {
                midiStatus = AppLocalizedCopy.status("status.mapping.command_failed")
                runtimeStatus = humanMessage(for: error)
            }
        }
    }

    func recordMappingValidation(_ action: DJControlAction, succeeded: Bool) {
        guard let selectedBackend else {
            midiStatus = AppLocalizedCopy.status("status.mapping.choose_backend")
            return
        }

        let environment = backendDescriptors
            .first { $0.identifier == selectedBackend }?
            .environment
        let key = DJCommandValidationKey(
            backend: selectedBackend,
            softwareVersion: environment?.softwareVersion,
            controllerName: "MixPilot Virtual Controller",
            mappingVersion: mappingProfile.validationIdentifier,
            action: action
        )
        let record = DJCommandValidationRecord(
            key: key,
            status: succeeded ? .automatedSuccess : .failed,
            evidence: succeeded ? .deviceConfirmed : .userRejected,
            detail: AppLocalizedCopy.status(
                succeeded
                    ? "status.mapping.validation_confirmed_detail"
                    : "status.mapping.validation_rejected_detail"
            )
        )

        Task {
            try? await commandValidationStore.record(record)
            midiStatus = succeeded
                ? AppLocalizedCopy.statusFormat(
                    "status.mapping.command_confirmed",
                    selectedBackend.displayName
                )
                : AppLocalizedCopy.status("status.mapping.command_rejected")
            await refreshEnvironmentNow()
        }
    }
}
#endif
