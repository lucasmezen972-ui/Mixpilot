#if os(macOS)
import AppKit
import MixPilotRemoteBridge
import SwiftUI

@main
struct MixPilotAutopilotApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var remoteBridge = MixPilotRemoteBridge()

    var body: some Scene {
        WindowGroup("MixPilot Autopilot") {
            BrandedRootView(model: model)
                .frame(minWidth: 1_180, minHeight: 760)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1_360, height: 900)
        .commands {
            MixPilotWindowCommands()
            CommandMenu("MixPilot") {
                Button("Ouvrir le Studio") {
                    model.selectedSection = .studio
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Ouvrir le Préflight") {
                    model.selectedSection = .preflight
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Ouvrir le Live") {
                    model.selectedSection = .live
                }
                .keyboardShortcut("3", modifiers: [.command])

                Divider()

                Button(remoteBridge.isRunning
                       ? "Désactiver la télécommande iPhone"
                       : "Activer la télécommande iPhone") {
                    if remoteBridge.isRunning {
                        remoteBridge.stop()
                    } else {
                        remoteBridge.start(provider: model)
                        showPairingCode()
                    }
                }

                Button("Afficher un nouveau code d’appairage…") {
                    remoteBridge.rotatePairingCode()
                    showPairingCode()
                }
                .disabled(!remoteBridge.isRunning)

                Button("État : \(remoteBridge.status)") {}
                    .disabled(true)

                Divider()

                Button("Exporter un diagnostic…") {
                    model.exportDiagnostics()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Reprendre immédiatement le contrôle", role: .destructive) {
                    model.takeManualControl()
                }
                .keyboardShortcut(.escape, modifiers: [.command])
            }
        }

        Window("Choisir le logiciel DJ", id: "dj-software") {
            DJSoftwareSettingsView(model: model)
        }
        .defaultSize(width: 680, height: 430)

        Window("Préparer un set rapidement", id: "quick-set") {
            QuickSetView(model: model)
        }
        .defaultSize(width: 650, height: 380)

        Window("Contrôle rekordbox", id: "rekordbox-compatibility") {
            RekordboxCompatibilityLabView(appModel: model)
        }
        .defaultSize(width: 1_080, height: 780)

        Window("Mapping rekordbox automatique", id: "automatic-rekordbox-mapping") {
            AutomaticRekordboxMappingView(model: model)
        }
        .defaultSize(width: 1_020, height: 760)

        Window("Mapping Serato automatique", id: "automatic-serato-mapping") {
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
    }

    private func showPairingCode() {
        let alert = NSAlert()
        alert.messageText = "Appairer MixPilot Remote"
        alert.informativeText = "Sur l’iPhone, sélectionne ce Mac puis saisis le code \(remoteBridge.pairingCode). Il expire dans deux minutes."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private struct MixPilotWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Choisir Serato, djay ou rekordbox") {
                openWindow(id: "dj-software")
            }
            .keyboardShortcut(",", modifiers: [.command, .shift])

            Button("Préparer un set rapidement") {
                openWindow(id: "quick-set")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("Contrôler et inspecter rekordbox") {
                openWindow(id: "rekordbox-compatibility")
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Button("Générer le mapping rekordbox") {
                openWindow(id: "automatic-rekordbox-mapping")
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])

            Divider()

            Button("Installer le mapping Serato automatiquement") {
                openWindow(id: "automatic-serato-mapping")
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Divider()

            Button("Ouvrir la répétition des transitions") {
                openWindow(id: "rehearsal")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Ouvrir l’inspecteur de transitions") {
                openWindow(id: "transition-inspector")
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Ouvrir l’analyse audio de préparation") {
                openWindow(id: "preparation-analysis")
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button("Ouvrir le centre de récupération") {
                openWindow(id: "recovery-center")
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
        }
    }
}
#endif
