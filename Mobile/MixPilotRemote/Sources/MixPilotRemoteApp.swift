import MixPilotHelp
import SwiftUI

@main
struct MixPilotRemoteApp: App {
    @State private var showsHelp = false
    private let helpCatalog = MixPilotHelpCatalog.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        showsHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 25, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(18)
                    .accessibilityLabel(
                        helpCatalog.localized(
                            "help.center.title",
                            language: .preferred()
                        )
                    )
                }
                .sheet(isPresented: $showsHelp) {
                    RemoteHelpCenterView()
                }
        }
    }
}
