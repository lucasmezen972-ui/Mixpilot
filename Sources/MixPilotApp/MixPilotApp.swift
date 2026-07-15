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
    }
}
#endif
