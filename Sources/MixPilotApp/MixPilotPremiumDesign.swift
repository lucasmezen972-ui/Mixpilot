#if os(macOS)
import SwiftUI

struct MixPilotPremiumBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.032, blue: 0.058),
                    Color(red: 0.055, green: 0.035, blue: 0.105),
                    Color(red: 0.025, green: 0.070, blue: 0.095),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.purple.opacity(0.12))
                .frame(width: 620, height: 620)
                .blur(radius: 110)
                .offset(x: -420, y: -300)

            Circle()
                .fill(.cyan.opacity(0.09))
                .frame(width: 560, height: 560)
                .blur(radius: 120)
                .offset(x: 470, y: 340)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.018), .clear, .white.opacity(0.012)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }
}

struct MixPilotGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 18
    var accent: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.065))
                    .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.18),
                                (accent ?? .cyan).opacity(accent == nil ? 0.06 : 0.22),
                                .white.opacity(0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }
}

struct MixPilotSectionHero<Actions: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
    @ViewBuilder let actions: Actions

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        symbol: String,
        accent: Color = .cyan,
        @ViewBuilder actions: () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.accent = accent
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.95), .blue.opacity(0.75), .purple.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: symbol)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)
            .shadow(color: accent.opacity(0.28), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }

            Spacer(minLength: 18)
            HStack(spacing: 10) { actions }
        }
    }
}

struct MixPilotMetricTile: View {
    let title: String
    let value: String
    let symbol: String
    var accent: Color = .cyan
    var detail: String? = nil

    var body: some View {
        MixPilotGlassCard(cornerRadius: 17, padding: 15, accent: accent) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.14))
                    Image(systemName: symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 43, height: 43)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.42))
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                    if let detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.44))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct MixPilotStatusBadge: View {
    let title: String
    let symbol: String
    var accent: Color = .cyan

    var body: some View {
        Label(title.uppercased(), systemImage: symbol)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.7)
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accent.opacity(0.12), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            }
    }
}

struct MixPilotPanelTitle: View {
    let title: String
    let symbol: String
    var subtitle: String? = nil
    var accent: Color = .cyan

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                }
            }
            Spacer()
        }
    }
}

struct MixPilotPrimaryButtonStyle: ButtonStyle {
    var accent: Color = .cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [accent.opacity(configuration.isPressed ? 0.62 : 0.92), .blue.opacity(0.82), .purple.opacity(0.74)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: accent.opacity(configuration.isPressed ? 0.08 : 0.19), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct MixPilotSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.62 : 0.84))
            .background(.white.opacity(configuration.isPressed ? 0.05 : 0.085), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

struct MixPilotDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(.red.opacity(configuration.isPressed ? 0.55 : 0.78), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(.red.opacity(0.75), lineWidth: 1)
            }
            .shadow(color: .red.opacity(0.18), radius: 12, y: 6)
    }
}

extension View {
    func mixPilotInputStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            }
    }
}
#endif
