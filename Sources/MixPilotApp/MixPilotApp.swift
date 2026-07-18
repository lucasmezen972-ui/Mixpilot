#if os(macOS)
import AppKit
import MixPilotHelp
import MixPilotRemoteBridge
import SwiftUI

@main
struct MixPilotAutopilotApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var remoteBridge = MixPilotRemoteBridge()
    @StateObject private var cloud = MixPilotCloudCoordinator()
    @State private var mainSurface: MixPilotMainSurface = .home
    private let cloudBackendContextStore = MixPilotCloudBackendContextStore()

    private var insecureRemoteDevelopmentOverrideEnabled: Bool {
        MixPilotRemoteTransportSecurityPolicy.allowsCurrentDevelopmentTransport
    }

    var body: some Scene {
        WindowGroup("MixPilot") {
            MixPilotMainShellView(model: model, surface: $mainSurface, cloud: cloud)
                .frame(minWidth: 1_180, minHeight: 790)
                .onAppear {
                    let store = cloudBackendContextStore
                    cloud.configureBackendContextProvider {
                        await store.current()
                    }
                    publishCloudBackendContext()
                    cloud.start(liveMode: model.isLiveRunning)
                }
                .onChange(of: model.isLiveRunning) { _, isLiveRunning in
                    publishCloudBackendContext()
                    cloud.setLiveMode(isLiveRunning)
                }
                .onChange(of: model.selectedBackend) { _, _ in
                    publishCloudBackendContext()
                }
                .onChange(of: model.backendStatus) { _, _ in
                    publishCloudBackendContext()
                }
                .onChange(of: model.midiStatus) { _, _ in
                    publishCloudBackendContext()
                }
                .onChange(of: model.preflightReport.generatedAt) { _, _ in
                    publishCloudBackendContext()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1_380, height: 920)
        .commands {
            MixPilotWindowCommands(cloud: cloud)

            CommandMenu("MixPilot") {
                Button("Préparer") {
                    model.selectedSection = .studio
                    mainSurface = .workspace
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Vérifier") {
                    model.evaluatePreflight()
                    model.selectedSection = .preflight
                    mainSurface = .workspace
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Live") {
                    model.selectedSection = .live
                    mainSurface = .workspace
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Avancé") {
                    model.selectedSection = .feasibility
                    mainSurface = .workspace
                }
                .keyboardShortcut("4", modifiers: [.command])

                Divider()

                Button(remoteBridge.isRunning
                       ? "Désactiver la télécommande iPhone"
                       : insecureRemoteDevelopmentOverrideEnabled
                            ? "Activer la télécommande iPhone (développement)"
                            : "Télécommande iPhone indisponible (sécurité)") {
                    if remoteBridge.isRunning {
                        remoteBridge.stop()
                    } else if insecureRemoteDevelopmentOverrideEnabled {
                        remoteBridge.start(provider: model)
                        showPairingCode()
                    } else {
                        showRemoteSecurityWarning()
                    }
                }

                Button("Afficher un nouveau code d’appairage…") {
                    remoteBridge.rotatePairingCode()
                    showPairingCode()
                }
                .disabled(!remoteBridge.isRunning || !insecureRemoteDevelopmentOverrideEnabled)

                Divider()

                Button("Vérifier les mises à jour") {
                    cloud.checkNow()
                }
                .keyboardShortcut("u", modifiers: [.command, .option])

                Button("Exporter un diagnostic anonymisé…") {
                    model.exportDiagnostics()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Reprendre immédiatement la main", role: .destructive) {
                    model.takeManualControl()
                }
                .keyboardShortcut(.escape, modifiers: [.command])
            }
        }

        Window("Choisir le logiciel DJ", id: "dj-software") {
            DJSoftwareSettingsView(model: model)
        }
        .defaultSize(width: 1_100, height: 760)

        Window("Préparer un set rapidement", id: "quick-set") {
            QuickSetView(model: model)
        }
        .defaultSize(width: 650, height: 380)

        Window("Bibliothèque Spotify", id: "spotify-library") {
            SpotifyLibraryView(appModel: model)
        }
        .defaultSize(width: 1_360, height: 900)

        // Backend-specific tools remain registered for the contextual card in
        // the Advanced workspace. They are intentionally absent from the global
        // menu so rekordbox, Serato and djay do not create parallel navigation.
        Window("Outils rekordbox", id: "rekordbox-hub") {
            RekordboxHubView(appModel: model)
        }
        .defaultSize(width: 1_320, height: 880)

        Window("Inspection rekordbox", id: "rekordbox-compatibility") {
            RekordboxCompatibilityLabView(appModel: model)
        }
        .defaultSize(width: 1_080, height: 780)

        Window("Validation réelle rekordbox", id: "rekordbox-device-validation") {
            RekordboxDeviceValidationView(appModel: model)
        }
        .defaultSize(width: 1_240, height: 860)

        Window("Mapping rekordbox", id: "automatic-rekordbox-mapping") {
            AutomaticRekordboxMappingView(model: model)
        }
        .defaultSize(width: 1_020, height: 760)

        Window("Configuration Serato", id: "automatic-serato-mapping") {
            AutomaticSeratoMappingView(model: model)
        }
        .defaultSize(width: 1_020, height: 760)

        Window("Répétition des transitions", id: "rehearsal") {
            RehearsalWorkspace(model: model)
        }
        .defaultSize(width: 1_180, height: 780)

        Window("Inspecteur de transitions", id: "transition-inspector") {
            TransitionInspectorView(model: model)
        }
        .defaultSize(width: 1_120, height: 760)

        Window("Analyse audio de préparation", id: "preparation-analysis") {
            PreparationAnalysisView(model: model)
        }
        .defaultSize(width: 1_040, height: 720)

        Window("Centre de récupération", id: "recovery-center") {
            RecoveryCenterView()
        }
        .defaultSize(width: 820, height: 620)

        Window("Centre d’aide", id: "help-center") {
            MixPilotHelpCenterView()
        }
        .defaultSize(width: 1_080, height: 760)
    }

    private func publishCloudBackendContext() {
        let context = model.onlineBackendContext
        let store = cloudBackendContextStore
        Task {
            await store.update(context)
        }
    }

    private func showPairingCode() {
        let alert = NSAlert()
        guard remoteBridge.pairingCode != "------" else {
            alert.messageText = "Appairage indisponible"
            alert.informativeText = "MixPilot n’a pas pu générer un code cryptographiquement sûr. La télécommande reste désactivée."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        alert.messageText = "Appairer MixPilot Remote — développement"
        alert.informativeText = "Ce transport local n’est pas encore chiffré. Utilise-le uniquement sur un réseau de développement isolé. Sur l’iPhone, sélectionne ce Mac puis saisis le code \(remoteBridge.pairingCode). Il expire dans deux minutes."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "J’ai compris")
        alert.runModal()
    }

    private func showRemoteSecurityWarning() {
        let alert = NSAlert()
        alert.messageText = "Télécommande temporairement désactivée"
        alert.informativeText = "Le transport iPhone–Mac actuel n’est pas encore chiffré. MixPilot le bloque dans les builds normaux. Pour un test de développement sur un réseau isolé, lance l’application avec MIXPILOT_ALLOW_INSECURE_REMOTE=1."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private struct MixPilotWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var cloud: MixPilotCloudCoordinator

    private let helpCatalog = MixPilotHelpCatalog.shared
    private var helpLanguage: MixPilotHelpLanguage { .preferred() }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Choisir le logiciel DJ") {
                openWindow(id: "dj-software")
            }
            .keyboardShortcut(",", modifiers: [.command, .shift])

            Button("Préparer un set rapidement") {
                openWindow(id: "quick-set")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("Ouvrir la bibliothèque Spotify") {
                openWindow(id: "spotify-library")
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .help) {
            Button(helpCatalog.localized("help.center.title", language: helpLanguage)) {
                openWindow(id: "help-center")
            }
            .keyboardShortcut("?", modifiers: [.command])
        }

        CommandMenu("Avancé") {
            Button("Répéter une transition") {
                openWindow(id: "rehearsal")
            }
            Button("Inspecter les transitions") {
                openWindow(id: "transition-inspector")
            }
            Button("Analyser l’audio localement") {
                openWindow(id: "preparation-analysis")
            }
            Button("Ouvrir le centre de récupération") {
                openWindow(id: "recovery-center")
            }

            Divider()

            Button("Vérifier les services en ligne") {
                cloud.checkNow()
            }
        }
    }
}
#endif
