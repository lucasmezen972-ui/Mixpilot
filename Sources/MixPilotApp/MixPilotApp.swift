#if os(macOS)
import AppKit
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

            CommandMenu(AppLocalizedCopy.command("commands.menu.mixpilot")) {
                Button(AppLocalizedCopy.command("commands.prepare")) {
                    model.selectedSection = .studio
                    mainSurface = .workspace
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button(AppLocalizedCopy.command("commands.verify")) {
                    model.evaluatePreflight()
                    model.selectedSection = .preflight
                    mainSurface = .workspace
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button(AppLocalizedCopy.command("commands.live")) {
                    model.selectedSection = .live
                    mainSurface = .workspace
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button(AppLocalizedCopy.command("commands.advanced")) {
                    model.selectedSection = .feasibility
                    mainSurface = .workspace
                }
                .keyboardShortcut("4", modifiers: [.command])

                Divider()

                Button(remoteBridge.isRunning
                       ? AppLocalizedCopy.command("commands.remote.disable")
                       : insecureRemoteDevelopmentOverrideEnabled
                           ? AppLocalizedCopy.command("commands.remote.enable_development")
                           : AppLocalizedCopy.command("commands.remote.unavailable")) {
                    if remoteBridge.isRunning {
                        remoteBridge.stop()
                    } else if insecureRemoteDevelopmentOverrideEnabled {
                        remoteBridge.start(provider: model)
                        showPairingCode()
                    } else {
                        showRemoteSecurityWarning()
                    }
                }

                Button(AppLocalizedCopy.command("commands.remote.new_pairing_code")) {
                    remoteBridge.rotatePairingCode()
                    showPairingCode()
                }
                .disabled(!remoteBridge.isRunning || !insecureRemoteDevelopmentOverrideEnabled)

                Divider()

                Button(AppLocalizedCopy.command("commands.check_updates")) {
                    cloud.checkNow()
                }
                .keyboardShortcut("u", modifiers: [.command, .option])

                Button(AppLocalizedCopy.command("commands.export_diagnostics")) {
                    model.exportDiagnostics()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button(AppLocalizedCopy.command("commands.take_control_now"), role: .destructive) {
                    model.takeManualControl()
                }
                .keyboardShortcut(.escape, modifiers: [.command])
            }
        }

        Window(AppLocalizedCopy.command("commands.window.choose_software"), id: "dj-software") {
            DJSoftwareSettingsView(model: model)
        }
        .defaultSize(width: 1_100, height: 760)

        Window(AppLocalizedCopy.command("commands.window.quick_set"), id: "quick-set") {
            QuickSetView(model: model)
        }
        .defaultSize(width: 650, height: 380)

        // Backend-specific tools remain registered for the contextual card in
        // the Advanced workspace. They are intentionally absent from the global
        // menu so rekordbox, Serato and djay do not create parallel navigation.
        Window(AppLocalizedCopy.command("commands.window.rekordbox_tools"), id: "rekordbox-hub") {
            RekordboxHubView(appModel: model)
        }
        .defaultSize(width: 1_320, height: 880)

        Window(AppLocalizedCopy.command("commands.window.rekordbox_inspection"), id: "rekordbox-compatibility") {
            RekordboxCompatibilityLabView(appModel: model)
        }
        .defaultSize(width: 1_080, height: 780)

        Window(AppLocalizedCopy.command("commands.window.rekordbox_validation"), id: "rekordbox-device-validation") {
            RekordboxDeviceValidationView(appModel: model)
        }
        .defaultSize(width: 1_240, height: 860)

        Window(AppLocalizedCopy.command("commands.window.rekordbox_mapping"), id: "automatic-rekordbox-mapping") {
            AutomaticRekordboxMappingView(model: model)
        }
        .defaultSize(width: 1_020, height: 760)

        Window(AppLocalizedCopy.command("commands.window.serato_mapping"), id: "automatic-serato-mapping") {
            AutomaticSeratoMappingView(model: model)
        }
        .defaultSize(width: 1_020, height: 760)

        Window(AppLocalizedCopy.command("commands.window.rehearsal"), id: "rehearsal") {
            RehearsalWorkspace(model: model)
        }
        .defaultSize(width: 1_180, height: 780)

        Window(AppLocalizedCopy.command("commands.window.transition_inspector"), id: "transition-inspector") {
            TransitionInspectorView(model: model)
        }
        .defaultSize(width: 1_120, height: 760)

        Window(AppLocalizedCopy.command("commands.window.audio_analysis"), id: "preparation-analysis") {
            PreparationAnalysisView(model: model)
        }
        .defaultSize(width: 1_040, height: 720)

        Window(AppLocalizedCopy.command("commands.window.recovery"), id: "recovery-center") {
            RecoveryCenterView()
        }
        .defaultSize(width: 820, height: 620)

        Window(AppLocalizedCopy.command("commands.window.help"), id: "help-center") {
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
            alert.messageText = AppLocalizedCopy.command("commands.alert.pairing_unavailable.title")
            alert.informativeText = AppLocalizedCopy.command("commands.alert.pairing_unavailable.detail")
            alert.alertStyle = .critical
            alert.addButton(withTitle: AppLocalizedCopy.command("commands.alert.ok"))
            alert.runModal()
            return
        }

        alert.messageText = AppLocalizedCopy.command("commands.alert.pairing_development.title")
        alert.informativeText = AppLocalizedCopy.commandFormat(
            "commands.alert.pairing_development.detail_format",
            remoteBridge.pairingCode
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppLocalizedCopy.command("commands.alert.understood"))
        alert.runModal()
    }

    private func showRemoteSecurityWarning() {
        let alert = NSAlert()
        alert.messageText = AppLocalizedCopy.command("commands.alert.remote_disabled.title")
        alert.informativeText = AppLocalizedCopy.command("commands.alert.remote_disabled.detail")
        alert.alertStyle = .critical
        alert.addButton(withTitle: AppLocalizedCopy.command("commands.alert.ok"))
        alert.runModal()
    }
}

private struct MixPilotWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var cloud: MixPilotCloudCoordinator

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(AppLocalizedCopy.command("commands.choose_software")) {
                openWindow(id: "dj-software")
            }
            .keyboardShortcut(",", modifiers: [.command, .shift])

            Button(AppLocalizedCopy.command("commands.quick_set")) {
                openWindow(id: "quick-set")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .help) {
            Button(AppLocalizedCopy.text("help.center.title")) {
                openWindow(id: "help-center")
            }
            .keyboardShortcut("?", modifiers: [.command])
        }

        CommandMenu(AppLocalizedCopy.command("commands.advanced_menu")) {
            Button(AppLocalizedCopy.command("commands.rehearse_transition")) {
                openWindow(id: "rehearsal")
            }
            Button(AppLocalizedCopy.command("commands.inspect_transitions")) {
                openWindow(id: "transition-inspector")
            }
            Button(AppLocalizedCopy.command("commands.analyze_audio")) {
                openWindow(id: "preparation-analysis")
            }
            Button(AppLocalizedCopy.command("commands.open_recovery")) {
                openWindow(id: "recovery-center")
            }

            Divider()

            Button(AppLocalizedCopy.command("commands.check_online_services")) {
                cloud.checkNow()
            }
        }
    }
}
#endif
