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
            RehearsalWindowCommands()
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
    }
}

private struct RehearsalWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Ouvrir la répétition des transitions") {
                openWindow(id: "rehearsal")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
#endif
