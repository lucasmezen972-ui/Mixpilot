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

                midiStatus = "Contrôleur actif • \(Int(profile.liveControlCoverageRatio * 100)) % des commandes critiques configurées"
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
                guard let selectedBackend else {
                    throw DJBackendError.commandRejected(
                        "Choisis d’abord Rekordbox, Serato ou djay."
                    )
                }
                guard let mappedController else {
                    throw DJBackendError.commandRejected(
                        "Le contrôleur MIDI n’est pas encore disponible."
                    )
                }
                guard mappingProfile[action] != nil else {
                    throw MIDIControllerError.missingMapping(action)
                }

                let environment = backendDescriptors
                    .first { $0.identifier == selectedBackend }?
                    .environment
                guard environment?.isRunning == true else {
                    throw DJBackendError.disconnected(selectedBackend)
                }

                try? accessibilityBridge.activate(selectedBackend)

                let expectedPlayback = action.expectedPlaybackState
                let beforeMotion: DJPlaybackMotion?
                if expectedPlayback != nil {
                    let beforeFirst = accessibilityBridge.observe(
                        backend: selectedBackend,
                        maxDepth: 9,
                        maximumStrings: 900
                    )
                    guard beforeFirst.accessibilityGranted else {
                        accessibilityBridge.requestAccessibilityPrompt()
                        throw DJBackendError.stateUnavailable(
                            "Autorise MixPilot à lire l’interface pour vérifier que PLAY agit réellement."
                        )
                    }
                    try await Task.sleep(for: .milliseconds(450))
                    let beforeSecond = accessibilityBridge.observe(
                        backend: selectedBackend,
                        maxDepth: 9,
                        maximumStrings: 900
                    )
                    beforeMotion = DJPlaybackTimecodeProbe().compare(
                        firstVisibleText: beforeFirst.visibleText,
                        secondVisibleText: beforeSecond.visibleText
                    ).motion
                } else {
                    beforeMotion = nil
                }

                if let mapping = mappingProfile[action], mapping.kind == .controlChange {
                    try await mappedController.set(action, value: 0.5)
                } else {
                    try await mappedController.trigger(action)
                }

                guard let expectedPlayback else {
                    midiStatus = "Commande MIDI envoyée à \(selectedBackend.displayName). Confirme sa réaction dans l’écran de validation."
                    return
                }

                let afterFirst = accessibilityBridge.observe(
                    backend: selectedBackend,
                    maxDepth: 9,
                    maximumStrings: 900
                )
                try await Task.sleep(for: .milliseconds(650))
                let afterSecond = accessibilityBridge.observe(
                    backend: selectedBackend,
                    maxDepth: 9,
                    maximumStrings: 900
                )
                let result = DJPlaybackTimecodeProbe().compare(
                    firstVisibleText: afterFirst.visibleText,
                    secondVisibleText: afterSecond.visibleText
                )

                if expectedPlayback,
                   beforeMotion != .moving,
                   result.motion == .moving {
                    midiStatus = "PLAY confirmé : le compteur du deck avance dans \(selectedBackend.displayName). Confirme maintenant la commande pour le Live."
                } else if !expectedPlayback,
                          beforeMotion == .moving,
                          result.motion == .stable {
                    midiStatus = "PAUSE confirmée : le compteur du deck s’est arrêté dans \(selectedBackend.displayName)."
                } else {
                    midiStatus = playbackFailureMessage(
                        action: action,
                        backend: selectedBackend,
                        beforeMotion: beforeMotion,
                        afterResult: result
                    )
                }
            } catch {
                midiStatus = "Test refusé : \(humanMessage(for: error))"
                runtimeStatus = humanMessage(for: error)
            }
        }
    }

    private func playbackFailureMessage(
        action: DJControlAction,
        backend: DJBackendIdentifier,
        beforeMotion: DJPlaybackMotion?,
        afterResult: DJPlaybackProbeResult
    ) -> String {
        if action.expectedPlaybackState == true, beforeMotion == .moving {
            return "Le deck semblait déjà jouer avant le test. Comme PLAY est un bouton bascule dans \(backend.displayName), MixPilot ne le valide pas à l’aveugle. Mets le deck en pause puis reteste."
        }

        let setup: String
        switch backend {
        case .rekordbox:
            setup = "importe le CSV MIDI MixPilot, sélectionne “MixPilot Virtual Controller”, puis charge un titre sur le deck"
        case .serato:
            setup = "réinstalle le mapping automatique MixPilot, relance Serato, puis charge un titre sur le deck"
        case .djay:
            setup = "importe ou apprends le mapping MIDI MixPilot, puis charge un titre sur le deck"
        }

        if afterResult.motion == .unavailable {
            return "Le message MIDI est parti, mais MixPilot ne voit aucun compteur de deck. Vérifie l’autorisation Accessibilité, puis \(setup)."
        }
        return "Le message MIDI est parti, mais aucune lecture réelle n’a été détectée. \(setup), puis reteste PLAY."
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
            mappingVersion: mappingProfile.validationIdentifier,
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
