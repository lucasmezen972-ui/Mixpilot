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
            midiStatus = "Contrôleur virtuel actif"

            Task {
                let profile = (try? await store.load()) ?? .developmentDefault
                mappingProfile = profile
                let mapped = MappedMIDIController(controller: controller, profile: profile)
                mappedController = mapped

                let registry = DJBackendRegistry(
                    backends: [
                        DjayBackend(midi: mapped, validationStore: commandValidationStore),
                        RekordboxBackend(midi: mapped, validationStore: commandValidationStore),
                        SeratoBackend(midi: mapped, validationStore: commandValidationStore),
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

                midiStatus = "Contrôleur actif • \(Int(profile.completionRatio * 100)) % configuré"
                await refreshEnvironmentNow()
            }
        } catch {
            midiStatus = "Le contrôleur MIDI n’a pas pu être créé. Ferme les autres outils MIDI, puis réessaie."
            runtimeStatus = humanMessage(for: error)
            evaluatePreflight()
        }
    }

    func resetDefaultMapping() {
        mappingProfile = .developmentDefault
        Task {
            await mappedController?.replaceProfile(mappingProfile)
            _ = try? await mappingStore?.save(mappingProfile)
            midiStatus = "Profil par défaut chargé"
            await refreshEnvironmentNow()
        }
    }

    func saveMapping() {
        Task {
            do {
                _ = try await mappingStore?.save(mappingProfile)
                await mappedController?.replaceProfile(mappingProfile)
                midiStatus = "Mapping sauvegardé"
                await refreshEnvironmentNow()
            } catch {
                midiStatus = "Le mapping n’a pas pu être sauvegardé. Vérifie l’espace disponible, puis réessaie."
            }
        }
    }

    func testMapping(_ action: DJControlAction) {
        Task {
            do {
                guard let mappedController else {
                    throw DJBackendError.commandRejected(
                        "Le contrôleur MIDI n’est pas encore disponible."
                    )
                }
                if let mapping = mappingProfile[action], mapping.kind == .controlChange {
                    try await mappedController.set(action, value: 0.5)
                } else {
                    try await mappedController.trigger(action)
                }
                midiStatus = "Commande envoyée. Confirme maintenant la réaction du logiciel DJ."
            } catch {
                midiStatus = "La commande n’a pas pu être envoyée. Vérifie le mapping et la connexion MIDI."
                runtimeStatus = humanMessage(for: error)
            }
        }
    }

    func recordMappingValidation(_ action: DJControlAction, succeeded: Bool) {
        guard let selectedBackend else {
            midiStatus = "Choisis d’abord le logiciel DJ à tester."
            return
        }

        let environment = backendDescriptors
            .first { $0.identifier == selectedBackend }?
            .environment
        let key = DJCommandValidationKey(
            backend: selectedBackend,
            softwareVersion: environment?.softwareVersion,
            controllerName: "MixPilot Virtual Controller",
            mappingVersion: "profile-\(mappingProfile.schemaVersion)",
            action: action
        )
        let record = DJCommandValidationRecord(
            key: key,
            status: succeeded ? .automatedSuccess : .failed,
            evidence: succeeded ? .deviceConfirmed : .userRejected,
            detail: succeeded
                ? "Réaction confirmée par l’utilisateur sur le logiciel DJ actif."
                : "La réaction attendue n’a pas été observée."
        )

        Task {
            try? await commandValidationStore.record(record)
            midiStatus = succeeded
                ? "Commande confirmée avec \(selectedBackend.displayName)."
                : "Commande marquée comme non fonctionnelle. MixPilot ne l’utilisera pas en Live."
            await refreshEnvironmentNow()
        }
    }
}
#endif
