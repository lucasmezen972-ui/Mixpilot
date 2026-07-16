#if os(macOS)
import SwiftUI

struct BrandedRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                MixPilotBrandLogoView(size: 72, cornerRadius: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text("MixPilot Autopilot")
                        .font(.title2.bold())
                    Text("by Lucas Mezen • Contrôle autonome de Serato DJ Pro")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(model.isLiveRunning ? "AUTOPILOT ACTIF" : "PRÊT")
                        .font(.caption.bold())
                    Text(model.runtimeStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider()

            AdvancedContentView(model: model)
        }
    }
}
#endif
