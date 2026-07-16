#if os(macOS)
import AppKit
import SwiftUI

@MainActor
enum MixPilotBrandAssets {
    static let logo: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MixPilotLogo", withExtension: "jpg") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
}

@MainActor
struct MixPilotBrandLogoView: View {
    var size: CGFloat = 170
    var cornerRadius: CGFloat = 24

    var body: some View {
        Group {
            if let logo = MixPilotBrandAssets.logo {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.quaternary)
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 20, y: 10)
        .accessibilityLabel("Logo MixPilot by Lucas Mezen")
    }
}

@MainActor
struct MixPilotSidebarBrand: View {
    var body: some View {
        HStack(spacing: 10) {
            MixPilotBrandLogoView(size: 46, cornerRadius: 11)
            VStack(alignment: .leading, spacing: 1) {
                Text("MixPilot")
                    .font(.headline)
                Text("by Lucas Mezen")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
#endif
