#if os(macOS)
import SwiftUI

@main
struct MixPilotAutopilotApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("MixPilot Autopilot") {
            ContentView(model: model)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1180, height: 780)
        .commands {
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

        WindowGroup("Inspecteur de transitions", id: "transition-inspector") {
            TransitionInspectorView(model: model)
        }
        .defaultSize(width: 1120, height: 760)

        WindowGroup("Analyse audio de préparation", id: "preparation-analysis") {
            PreparationAnalysisView(model: model)
        }
        .defaultSize(width: 1040, height: 720)

        WindowGroup("Centre de récupération", id: "recovery-center") {
            RecoveryCenterView()
        }
        .defaultSize(width: 820, height: 620)
    }
}
#endif
