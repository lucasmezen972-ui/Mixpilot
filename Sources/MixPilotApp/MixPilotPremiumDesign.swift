#if os(macOS)
import SwiftUI

enum MixPilotPalette {
    static let canvasTop = Color(red: 0.018, green: 0.024, blue: 0.040)
    static let canvasMiddle = Color(red: 0.028, green: 0.030, blue: 0.060)
    static let canvasBottom = Color(red: 0.018, green: 0.047, blue: 0.061)
    static let surface = Color.white.opacity(0.060)
    static let surfaceRaised = Color.white.opacity(0.082)
    static let surfacePressed = Color.white.opacity(0.105)
    static let border = Color.white.opacity(0.115)
    static let borderStrong = Color.white.opacity(0.185)
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.42)
    static let shadow = Color.black.opacity(0.34)
}

enum MixPilotCardElevation {
    case flat
    case standard
    case elevated

    var fillOpacity: Double {
        switch self {
        case .flat: 0.046
        case .standard: 0.064
        case .elevated: 0.082
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .flat: 8
        case .standard: 18
        case .elevated: 30
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .flat: 3
        case .standard: 9
        case .elevated: 15
        }
    }
}

struct MixPilotPremiumBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    MixPilotPalette.canvasTop,
                    MixPilotPalette.canvasMiddle,
                    MixPilotPalette.canvasBottom,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [.indigo.opacity(0.17), .clear],
                center: UnitPoint(x: 0.14, y: 0.08),
                startRadius: 20,
                endRadius: 610
            )

            RadialGradient(
                colors: [.cyan.opacity(0.10), .clear],
                center: UnitPoint(x: 0.88, y: 0.86),
                startRadius: 10,
                endRadius: 570
            )

            MixPilotGridTexture()
                .opacity(0.24)

            LinearGradient(
                colors: [.black.opacity(0.08), .clear, .black.opacity(0.20)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct MixPilotGridTexture: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 36
            var path = Path()

            stride(from: CGFloat.zero, through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: CGFloat.zero, through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 0.5)
        }
        .mask(
            LinearGradient(
                colors: [.white.opacity(0.75), .white.opacity(0.22), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .allowsHitTesting(false)
    }
}

struct MixPilotGlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var padding: CGFloat
    var accent: Color?
    var elevation: MixPilotCardElevation
    var interactive: Bool
    @ViewBuilder var content: Content

    @State private var isHovering = false

    init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 18,
        accent: Color? = nil,
        elevation: MixPilotCardElevation = .standard,
        interactive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.accent = accent
        self.elevation = elevation
        self.interactive = interactive
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(elevation.fillOpacity + (isHovering && interactive ? 0.016 : 0)))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(isHovering && interactive ? 0.25 : 0.17),
                                (accent ?? .cyan).opacity(accent == nil ? 0.055 : (isHovering && interactive ? 0.26 : 0.17)),
                                .white.opacity(0.035),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: MixPilotPalette.shadow.opacity(isHovering && interactive ? 1 : 0.78),
                radius: elevation.shadowRadius + (isHovering && interactive ? 5 : 0),
                y: elevation.shadowY + (isHovering && interactive ? 2 : 0)
            )
            .shadow(color: (accent ?? .clear).opacity(isHovering && interactive ? 0.10 : 0.035), radius: 22, y: 8)
            .scaleEffect(isHovering && interactive ? 1.004 : 1)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onHover { hovering in
                guard interactive else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    isHovering = hovering
                }
            }
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.88), .indigo.opacity(0.70)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(.white.opacity(0.20), lineWidth: 1)
                        }
                    Image(systemName: symbol)
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)
                .shadow(color: accent.opacity(0.22), radius: 20, y: 8)

                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.65)
                        .foregroundStyle(accent)
                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .tracking(-0.4)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.system(size: 13.5, weight: .regular, design: .rounded))
                        .foregroundStyle(MixPilotPalette.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(3)
                }

                Spacer(minLength: 18)

                HStack(spacing: 9) {
                    actions
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.40), .white.opacity(0.07), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
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
        MixPilotGlassCard(cornerRadius: 17, padding: 15, accent: accent, interactive: true) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.13))
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 43, height: 43)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.85)
                        .foregroundStyle(MixPilotPalette.textTertiary)
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                    if let detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(MixPilotPalette.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 46)
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
            .tracking(0.72)
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accent.opacity(0.105), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(accent.opacity(0.20), lineWidth: 1)
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
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(0.11))
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(-0.12)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MixPilotPalette.textTertiary)
                        .lineSpacing(1.5)
                }
            }
            Spacer(minLength: 8)
        }
    }
}

struct MixPilotSidebarHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var accent: Color = .cyan
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(eyebrow.uppercased())
                    .tracking(1.45)
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(accent)

            Text(title)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .tracking(-0.25)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(MixPilotPalette.textTertiary)
                .lineLimit(2)
        }
    }
}

struct MixPilotEmptyState<Actions: View>: View {
    let title: String
    let message: String
    let symbol: String
    var accent: Color
    @ViewBuilder let actions: Actions

    init(
        title: String,
        message: String,
        symbol: String,
        accent: Color = .cyan,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.symbol = symbol
        self.accent = accent
        self.actions = actions()
    }

    var body: some View {
        MixPilotGlassCard(cornerRadius: 24, padding: 28, accent: accent, elevation: .elevated) {
            VStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                    Circle()
                        .strokeBorder(accent.opacity(0.20), lineWidth: 1)
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 72, height: 72)

                Text(title)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(MixPilotPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 520)
                HStack(spacing: 10) {
                    actions
                }
            }
            .frame(maxWidth: .infinity, minHeight: 245)
        }
    }
}

extension MixPilotEmptyState where Actions == EmptyView {
    init(title: String, message: String, symbol: String, accent: Color = .cyan) {
        self.init(title: title, message: message, symbol: symbol, accent: accent) {
            EmptyView()
        }
    }
}

struct MixPilotNotice: View {
    enum Kind {
        case info
        case success
        case warning
        case danger

        var color: Color {
            switch self {
            case .info: .cyan
            case .success: .green
            case .warning: .orange
            case .danger: .red
            }
        }

        var symbol: String {
            switch self {
            case .info: "info.circle.fill"
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .danger: "xmark.octagon.fill"
            }
        }
    }

    let title: String
    let message: String
    var kind: Kind = .info

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(kind.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(MixPilotPalette.textSecondary)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(kind.color.opacity(0.075), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(kind.color.opacity(0.17), lineWidth: 1)
        }
    }
}

struct MixPilotKeyValueRow: View {
    let label: String
    let value: String
    var accent: Color = .cyan
    var symbol: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(accent)
                    .frame(width: 18)
            }
            Text(label)
                .font(.callout)
                .foregroundStyle(MixPilotPalette.textTertiary)
            Spacer(minLength: 12)
            Text(value)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 5)
    }
}

struct MixPilotSectionDivider: View {
    var accent: Color = .cyan

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, accent.opacity(0.20), .white.opacity(0.07), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

struct MixPilotPrimaryButtonStyle: ButtonStyle {
    var accent: Color = .cyan
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.52))
            .background(
                LinearGradient(
                    colors: [
                        accent.opacity(configuration.isPressed ? 0.66 : 0.88),
                        .indigo.opacity(configuration.isPressed ? 0.65 : 0.78),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.white.opacity(isEnabled ? 0.20 : 0.08), lineWidth: 1)
            }
            .shadow(color: isEnabled ? accent.opacity(configuration.isPressed ? 0.06 : 0.16) : .clear, radius: 12, y: 5)
            .scaleEffect(configuration.isPressed ? 0.982 : 1)
            .opacity(isEnabled ? 1 : 0.64)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct MixPilotSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(.white.opacity(isEnabled ? (configuration.isPressed ? 0.65 : 0.87) : 0.38))
            .background(
                Color.white.opacity(configuration.isPressed ? 0.055 : 0.078),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.white.opacity(configuration.isPressed ? 0.18 : 0.105), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.984 : 1)
            .opacity(isEnabled ? 1 : 0.62)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct MixPilotDangerButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.48))
            .background(
                LinearGradient(
                    colors: [.red.opacity(configuration.isPressed ? 0.56 : 0.76), .pink.opacity(0.50)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.red.opacity(isEnabled ? 0.62 : 0.20), lineWidth: 1)
            }
            .shadow(color: isEnabled ? .red.opacity(0.15) : .clear, radius: 12, y: 5)
            .scaleEffect(configuration.isPressed ? 0.982 : 1)
            .opacity(isEnabled ? 1 : 0.60)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func mixPilotInputStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(MixPilotPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(MixPilotPalette.border, lineWidth: 1)
            }
    }

    func mixPilotWindowSurface(minWidth: CGFloat? = nil, minHeight: CGFloat? = nil) -> some View {
        self
            .frame(minWidth: minWidth, minHeight: minHeight)
            .preferredColorScheme(.dark)
            .tint(.cyan)
    }

    func mixPilotSidebarSurface() -> some View {
        self
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.23), .black.opacity(0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(.white.opacity(0.075))
                    .frame(width: 1)
            }
    }
}
#endif