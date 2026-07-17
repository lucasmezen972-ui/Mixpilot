#if os(macOS)
import AppKit
import Foundation
import MixPilotCore
import MixPilotMIDI
import MixPilotSystem

@MainActor
final class AutomaticSeratoMappingSession: ObservableObject {
    @Published private(set) var status = "Vérification du preset Serato…"
    @Published private(set) var detail = "Aucune action manuelle commande par commande n’est nécessaire."
    @Published private(set) var isWorking = false
    @Published private(set) var installationState: SeratoMappingInstallationState = .notInstalled
    @Published private(set) var lastResult: SeratoMappingInstallationResult?
    @Published private(set) var midiDiagnostic: MIDIPublicationDiagnostic?
    @Published private(set) var detectedSeratoVersion = "Non détectée"
    @Published private(set) var seratoRelaunched = false

    private let installer: SeratoMappingInstaller
    private let generator = SeratoXMLPresetGenerator()

    init(installer: SeratoMappingInstaller = SeratoMappingInstaller()) {
        self.installer = installer
    }

    var installationDirectory: String { installer.installationDirectory.path }

    func refresh(profile: MIDIMappingProfile) {
        refreshMIDIDiagnostic()
        let applicationURL = runningSeratoApplication()?.bundleURL ?? installedSeratoApplicationURL()
        detectedSeratoVersion = seratoVersion(at: applicationURL)
        let preset = generator.generate(
            profile: profile,
            seratoApplicationVersion: xmlApplicationVersion(at: applicationURL)
        )
        installationState = installer.inspect(expectedPreset: preset)
        switch installationState {
        case .notInstalled:
            status = "Mapping automatique non installé"
            detail = midiDiagnostic?.isReadyForSerato == true
                ? "Un clic suffit : MixPilot ferme Serato, sauvegarde l’existant, installe le preset et relance Serato."
                : "Le preset est prêt, mais le contrôleur CoreMIDI doit d’abord être publié correctement."
        case .installed(let version, _):
            status = "Preset MixPilot \(version) installé"
            detail = midiDiagnostic?.isReadyForSerato == true
                ? "Fichiers vérifiés et contrôleur CoreMIDI publié. Détection réelle par Serato : REQUIRES_SERATO_VALIDATION."
                : "Fichiers vérifiés, mais le contrôleur CoreMIDI n’est pas complètement publié."
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
        seratoRelaunched = false
        status = "Publication du contrôleur MIDI…"
        detail = "Ne ferme rien : MixPilot s’occupe du contrôleur, du preset et de Serato."

        Task { @MainActor in
            do {
                let controller = try CoreMIDIController()
                midiDiagnostic = try controller.requirePublishedControllerPair()
            } catch {
                status = "Contrôleur MIDI indisponible"
                detail = error.localizedDescription
                isWorking = false
                return
            }

            let runningApplication = runningSeratoApplication()
            let applicationURL = runningApplication?.bundleURL ?? installedSeratoApplicationURL()
            detectedSeratoVersion = seratoVersion(at: applicationURL)

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
                let preset = generator.generate(
                    profile: profile,
                    seratoApplicationVersion: xmlApplicationVersion(at: applicationURL)
                )
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
                    seratoRelaunched = await waitUntilSeratoStarts()
                }

                refreshMIDIDiagnostic()
                status = "Mapping et contrôleur installés"
                let unsupported = result.unsupportedActions.map(\.rawValue).joined(separator: ", ")
                if applicationURL == nil {
                    detail = "Preset installé et contrôleur publié. Serato n’a pas été trouvé dans Applications ; ouvre-le normalement."
                } else if !seratoRelaunched {
                    detail = "Preset installé et contrôleur publié, mais la relance de Serato n’a pas été confirmée."
                } else if unsupported.isEmpty {
                    detail = "Preset installé, contrôleur publié et Serato relancé. Validation réelle encore requise."
                } else {
                    detail = "Preset installé, contrôleur publié et Serato relancé. Fonctions volontairement non devinées : \(unsupported). Les transitions utilisent les volumes comme solution de secours."
                }
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
            let applicationURL = runningApplication?.bundleURL ?? installedSeratoApplicationURL()
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
                    seratoRelaunched = await waitUntilSeratoStarts()
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

    private func refreshMIDIDiagnostic() {
        do {
            let controller = try CoreMIDIController()
            midiDiagnostic = controller.publicationDiagnostic()
        } catch {
            midiDiagnostic = nil
        }
    }

    private func runningSeratoApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { application in
            let name = application.localizedName?.lowercased() ?? ""
            return name.contains("serato dj pro") || name == "serato dj"
        }
    }

    private func installedSeratoApplicationURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            URL(fileURLWithPath: "/Applications/Serato DJ Pro.app"),
            URL(fileURLWithPath: "/Applications/Serato DJ.app"),
            home.appendingPathComponent("Applications/Serato DJ Pro.app"),
            home.appendingPathComponent("Applications/Serato DJ.app"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func seratoVersion(at applicationURL: URL?) -> String {
        guard let applicationURL,
              let bundle = Bundle(url: applicationURL) else { return "Non détectée" }
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "Inconnue"
    }

    private func xmlApplicationVersion(at applicationURL: URL?) -> String {
        let version = seratoVersion(at: applicationURL)
        return version == "Non détectée" || version == "Inconnue" ? " 4.0.0" : " \(version)"
    }

    private func waitUntilSeratoStops() async -> Bool {
        for _ in 0..<24 {
            if runningSeratoApplication() == nil { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return runningSeratoApplication() == nil
    }

    private func waitUntilSeratoStarts() async -> Bool {
        for _ in 0..<40 {
            if runningSeratoApplication() != nil { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return runningSeratoApplication() != nil
    }
}
#endif
