#if os(macOS)
import MixPilotCore
import SwiftUI

struct QuickSetView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Préparer un set rapidement")
                .font(.largeTitle.bold())

            Text("Affiche la playlist dans le logiciel DJ choisi, puis lance la préparation.")
                .foregroundStyle(.secondary)

            Button("CAPTURER ET PRÉPARER LE SET") {
                model.captureSeratoPlaylist()
                model.lockPreparedProject()
                model.selectedSection = .preflight
                model.refreshEnvironment()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let project = model.preparedProject {
                Text("\(project.tracks.count) titres • \(project.transitions.count) transitions")
                    .font(.headline)
            }

            Spacer()
        }
        .padding(28)
        .frame(width: 620, height: 340)
    }
}
#endif
