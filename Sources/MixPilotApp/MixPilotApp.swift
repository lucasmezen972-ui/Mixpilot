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
    }
}
#endif
