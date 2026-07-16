#if os(macOS)
import MixPilotCore
import SwiftUI

struct DJSoftwareSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selection = DJSoftwareSelectionStore.current

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Logiciel DJ")
                .font(.largeTitle.bold())

            Text("MixPilot conserve le même moteur. Choisis l’application qui lit le set.")
                .foregroundStyle(.secondary)

            Picker("Application", selection: $selection) {
                ForEach(DJSoftware.allCases) { software in
                    Text(software.displayName).tag(software)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selection) { _, newValue in
                DJSoftwareSelectionStore.current = newValue
                model.refreshEnvironment()
                model.evaluatePreflight()
            }

            Text(selection == .djay
                 ? "Mode initial : playlist visible et Automix, sans mapping MIDI obligatoire."
                 : "Mode actuel : contrôle direct des decks via MIDI.")
                .font(.headline)

            Button("Ouvrir le Studio") {
                model.selectedSection = .studio
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(28)
        .frame(width: 600, height: 360)
    }
}
#endif
