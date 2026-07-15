#if os(macOS)
import SwiftUI

@main
struct MixPilotAutopilotApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("MixPilot Autopilot") {
            AdvancedContentView(model: model)
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
}

private struct MixPilotWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
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
