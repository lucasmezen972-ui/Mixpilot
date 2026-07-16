#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotSystem

@MainActor
final class AutomaticSeratoMappingSession: ObservableObject {
    @Published private(set) var status = "Vérification du preset Serato…"
    @Published private(set) var detail = "Aucune action manuelle commande par commande n’est nécessaire."
    @Published private(set) var isWorking = false
    @Published private(set) var installationState: SeratoMappingInstallationState = .notInstalled
    @Published private(set) var lastResult: SeratoMappingInstallationResult?

    private let installer: SeratoMappingInstaller
    private let generator = SeratoXMLPresetGenerator()

    init(installer: SeratoMappingInstaller = SeratoMappingInstaller()) {
        self.installer = installer
    }

    var installationDirectory: String { installer.installationDirectory.path }

    func refresh(profile: MIDIMappingProfile) {
        let preset = generator.generate(profile: profile)
        installationState = installer.inspect(expectedPreset: preset)
        switch installationState {
        case .notInstalled:
            status = "Mapping automatique non installé"
            detail = "Un clic suffit : MixPilot fermera Serato, sauvegardera l’existant, installera le preset et relancera Serato."
        case .installed(let version, _):
            status = "Preset MixPilot \(version) installé"
            detail = "Fichiers vérifiés sur le disque. Réaction réelle de Serato : REQUIRES_SERATO_VALIDATION."
        case .updateAvailable(let installedVersion, let expectedVersion):
            status = "Mise à jour du mapping disponible"
            detail = "Version installée : \(installedVersion ?? "inconnue") • attendue : \(expectedVersion)."
        case .damaged(let reason):
            status = "Mapping à réparer"
            detail = reason
        }
    }

    func install(
        profile: MIDIMappingProfile,
        onInstalled: @escaping @MainActor () -> Void
    ) {
        guard !isWorking else { return }
        isWorking = true
        status = "Préparation de l’installation…"
        detail = "Ne ferme rien : MixPilot s’occupe de Serato automatiquement."

        Task { @MainActor in
            let runningApplication = runningSeratoApplication()
            let applicationURL = runningApplication?.bundleURL

            if let runningApplication {
                status = "Fermeture de Serato…"
                runningApplication.terminate()
                let closed = await waitUntilSeratoStops()
                guard closed else {
                    status = "Impossible de fermer Serato"
                    detail = "Ferme Serato manuellement puis reclique sur Installer. Aucun fichier n’a été modifié."
                    isWorking = false
                    return
                }
            }

            do {
                status = "Installation du mapping…"
                let preset = generator.generate(profile: profile)
                let result = try installer.install(preset: preset, seratoRunning: false)
                MIDIMappingProfile.recordAutomaticPresetInstallation(
                    supportedActions: preset.supportedActions,
                    version: preset.version
                )
                lastResult = result
                onInstalled()

                if let applicationURL {
                    status = "Relance de Serato…"
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.activates = true
                    _ = try await NSWorkspace.shared.openApplication(
                        at: applicationURL,
                        configuration: configuration
                    )
                }

                status = "Mapping installé automatiquement"
                let unsupported = result.unsupportedActions.map(\.rawValue).joined(separator: ", ")
                detail = unsupported.isEmpty
                    ? "Preset installé et Serato relancé. Validation réelle encore requise."
                    : "Preset installé et Serato relancé. Fonctions volontairement non devinées : \(unsupported). Les transitions utilisent les volumes comme solution de secours."
                refresh(profile: profile)
            } catch {
                status = "Installation impossible"
                detail = error.localizedDescription
            }
            isWorking = false
        }
    }

    func rollback(
        profile: MIDIMappingProfile,
        onRolledBack: @escaping @MainActor () -> Void
    ) {
        guard !isWorking else { return }
        isWorking = true
        status = "Préparation du retour arrière…"

        Task { @MainActor in
            let runningApplication = runningSeratoApplication()
            let applicationURL = runningApplication?.bundleURL
            if let runningApplication {
                runningApplication.terminate()
                guard await waitUntilSeratoStops() else {
                    status = "Impossible de fermer Serato"
                    detail = "Aucun fichier n’a été modifié."
                    isWorking = false
                    return
                }
            }

            do {
                let restoredPath = try installer.rollback(seratoRunning: false)
                MIDIMappingProfile.clearAutomaticPresetInstallation()
                onRolledBack()
                if let applicationURL {
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.activates = true
                    _ = try await NSWorkspace.shared.openApplication(
                        at: applicationURL,
                        configuration: configuration
                    )
                }
                status = "Ancien mapping restauré"
                detail = "Sauvegarde restaurée depuis \(restoredPath)."
                refresh(profile: profile)
            } catch {
                status = "Retour arrière impossible"
                detail = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func runningSeratoApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { application in
            let name = application.localizedName?.lowercased() ?? ""
            return name.contains("serato dj pro") || name == "serato dj"
        }
    }

    private func waitUntilSeratoStops() async -> Bool {
        for _ in 0..<24 {
            if runningSeratoApplication() == nil { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return runningSeratoApplication() == nil
    }
}
#endif
