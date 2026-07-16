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

            Text(modeDescription)
                .font(.headline)

            Text(validationDescription)
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Ouvrir le Studio") {
                model.selectedSection = .studio
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(28)
        .frame(width: 660, height: 410)
    }

    private var modeDescription: String {
        switch selection {
        case .serato:
            "Mode actuel : contrôle direct des decks via MIDI."
        case .djay:
            "Mode initial : playlist visible et Automix, sans mapping MIDI obligatoire."
        case .rekordbox:
            "Mode initial : playlist visible et contrôle direct préparé pour le MIDI."
        }
    }

    private var validationDescription: String {
        switch selection {
        case .serato:
            "Le mapping automatique existe, mais la réaction réelle de Serato doit être validée sur le Mac cible."
        case .djay:
            "La file Automix reste en lecture seule tant que son arbre Accessibilité réel n’a pas été validé."
        case .rekordbox:
            "La lecture des playlists et les contrôles rekordbox restent REQUIRES_DEVICE_VALIDATION."
        }
    }
}
#endif
