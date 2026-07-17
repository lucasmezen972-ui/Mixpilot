#if os(macOS)
import SwiftUI

struct MixPilotUpdateBanner: View {
    @ObservedObject var cloud: MixPilotCloudCoordinator

    var body: some View {
        if let release = cloud.availableUpdate {
            HStack(spacing: 14) {
                Image(systemName: release.mandatory ? "exclamationmark.arrow.triangle.2.circlepath" : "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(release.mandatory ? .orange : .cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text(release.mandatory ? "Mise à jour requise" : "Une mise à jour est disponible")
                        .font(.headline)
                    Text("MixPilot \(release.version) • build \(release.build)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Button("Voir la mise à jour") { cloud.openAvailableUpdate() }
                    .buttonStyle(MixPilotPrimaryButtonStyle())
                if !release.mandatory {
                    Button { cloud.dismissUpdate() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                }
            }
            .modifier(OnlineServiceBannerStyle(accent: .cyan))
        }
    }
}

struct MixPilotRemoteMappingBanner: View {
    @ObservedObject var cloud: MixPilotCloudCoordinator

    var body: some View {
        if let staged = cloud.stagedMapping {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Correctif prêt pour le prochain lancement").font(.headline)
                    Text("Version \(staged.mappingVersion) • ancien mapping sauvegardé • import rekordbox requis")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Button("Afficher le CSV") { cloud.revealStagedPreset() }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .green))
                Button("Restaurer") { cloud.rollbackMapping() }
                    .buttonStyle(MixPilotSecondaryButtonStyle())
            }
            .modifier(OnlineServiceBannerStyle(accent: .green))
        } else if let release = cloud.availableMapping {
            HStack(spacing: 14) {
                Image(systemName: release.mandatory ? "exclamationmark.shield.fill" : "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(release.mandatory ? .orange : .purple)
                VStack(alignment: .leading, spacing: 3) {
                    Text(release.mandatory ? "Correctif requis" : "Nouveau correctif compatible")
                        .font(.headline)
                    Text("Version \(release.mappingVersion) • \(release.applyMode.displayName)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Button("Préparer le correctif") { cloud.installAvailableMapping() }
                    .buttonStyle(MixPilotPrimaryButtonStyle(accent: .purple))
                if !release.mandatory {
                    Button { cloud.dismissAvailableMapping() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                }
            }
            .modifier(OnlineServiceBannerStyle(accent: release.mandatory ? .orange : .purple))
        }
    }
}

struct MixPilotCompatibilityWarningBanner: View {
    @ObservedObject var cloud: MixPilotCloudCoordinator

    var body: some View {
        if let rule = cloud.activeCompatibilityOverride,
           rule.blockLive || !rule.warnings.isEmpty || !rule.disabledActions.isEmpty {
            HStack(spacing: 14) {
                Image(systemName: rule.blockLive ? "hand.raised.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(rule.blockLive ? .red : .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.blockLive ? "Live suspendu pour ta sécurité" : "Configuration adaptée")
                        .font(.headline)
                    Text((rule.warnings.first ?? "Certaines commandes doivent être testées à nouveau.")
                         + (rule.disabledActions.isEmpty ? "" : " • \(rule.disabledActions.count) fonction(s) concernée(s)"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
                Spacer()
            }
            .modifier(OnlineServiceBannerStyle(accent: rule.blockLive ? .red : .orange))
        }
    }
}

private struct OnlineServiceBannerStyle: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .padding(14)
            .foregroundStyle(.white)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
    }
}
#endif
