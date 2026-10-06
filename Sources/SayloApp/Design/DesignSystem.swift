import SwiftUI

public enum DesignSystem {

    // MARK: - Colors

    public enum Color {
        public static let surface = SwiftUI.Color(hex: "#FFFFFF")
        public static let ground = SwiftUI.Color(hex: "#F5F4F0")
        public static let chrome = SwiftUI.Color(hex: "#FBFBFA")
        public static let line = SwiftUI.Color(hex: "#E5E3DD")
        public static let muted = SwiftUI.Color(hex: "#73776F")
        public static let ink = SwiftUI.Color(hex: "#1B1D1C")
        public static let accent = SwiftUI.Color(hex: "#3E7C6C")
        public static let accentSoft = SwiftUI.Color(hex: "#E6EFEC")
        public static let danger = SwiftUI.Color(hex: "#B5483B")
        public static let heroSub = SwiftUI.Color(hex: "#9CA3AF")
        public static let chipDark = SwiftUI.Color(hex: "#2C302E")
        public static let track = SwiftUI.Color(hex: "#E5E7EB")
        public static let slateBar = SwiftUI.Color(hex: "#64748B")
        public static let paleBar = SwiftUI.Color(hex: "#94A3B8")
        public static let segment = SwiftUI.Color(hex: "#CBD5E1")
    }

    // MARK: - Typography

    public enum Typography {
        public static let sans = "Inter"
        public static let serif = "Instrument Serif"
        public static let mono = "Geist Mono"

        public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(sans, size: size).weight(weight)
        }

        public static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(serif, size: size).weight(weight)
        }

        public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(mono, size: size).weight(weight)
        }

        // Size tokens
        public static let xs: CGFloat = 12
        public static let sm: CGFloat = 13
        public static let base: CGFloat = 15
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 32
        public static let display: CGFloat = 72

        // Weight tokens
        public static let weightRegular: Font.Weight = .regular
        public static let weightMedium: Font.Weight = .medium
        public static let weightSemibold: Font.Weight = .semibold
        public static let weightBold: Font.Weight = .bold

        // Tracking
        public static let trackingTight = -0.03
        public static let trackingWide = 0.08

        // Line height
        public static let leadingBody: CGFloat = 22
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let s1: CGFloat = 4
        public static let s2: CGFloat = 8
        public static let s3: CGFloat = 12
        public static let s4: CGFloat = 16
        public static let s6: CGFloat = 24
        public static let s8: CGFloat = 32
        public static let s12: CGFloat = 48
    }

    // MARK: - Radius

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let full: CGFloat = 999
    }

    // MARK: - Containers

    public enum Container {
        public static let pill: CGFloat = 220
        public static let window: CGFloat = 1080
    }

    // MARK: - Breakpoints

    public enum Breakpoint {
        public static let window: CGFloat = 1080
    }

    // MARK: - Opacity

    public enum Opacity {
        public static let muted: CGFloat = 0.6
    }

    // MARK: - Animations

    public enum Animation {
        public static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
        public static let normal = SwiftUI.Animation.easeOut(duration: 0.25)
        public static let slow = SwiftUI.Animation.easeOut(duration: 0.4)
        public static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
    }
}

// MARK: - Color Extension for Hex

private extension SwiftUI.Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extensions for Design System

public extension View {
    func sayloFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.font(.system(size: size, weight: weight, design: design))
    }

    func sayloBody() -> some View {
        self
            .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.base))
            .lineSpacing(DesignSystem.Typography.leadingBody - DesignSystem.Typography.base)
    }

    func sayloLabel() -> some View {
        self
            .font(.custom(DesignSystem.Typography.mono, size: DesignSystem.Typography.xs))
            .tracking(DesignSystem.Typography.trackingWide)
    }

    func sayloTitle() -> some View {
        self
            .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.lg))
            .fontWeight(DesignSystem.Typography.weightSemibold)
            .tracking(DesignSystem.Typography.trackingTight)
    }

    func sayloHeadline() -> some View {
        self
            .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.xl))
            .fontWeight(DesignSystem.Typography.weightBold)
            .tracking(DesignSystem.Typography.trackingTight)
    }

    func sayloCard() -> some View {
        self
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
    }

    func sayloButtonStyle(_ variant: SayloButtonVariant = .primary) -> some View {
        self.buttonStyle(SayloButtonStyle(variant: variant))
    }
}

// MARK: - Button Variants

public enum SayloButtonVariant {
    case primary
    case secondary
    case ghost
    case danger
    case accent
}

// MARK: - Button Style

private struct SayloButtonStyle: ButtonStyle {
    let variant: SayloButtonVariant

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let bgColor: SwiftUI.Color
        let fgColor: SwiftUI.Color
        let borderColor: SwiftUI.Color

        switch variant {
        case .primary:
            bgColor = DesignSystem.Color.ink
            fgColor = DesignSystem.Color.surface
            borderColor = .clear
        case .secondary:
            bgColor = DesignSystem.Color.ground
            fgColor = DesignSystem.Color.ink
            borderColor = DesignSystem.Color.line
        case .ghost:
            bgColor = .clear
            fgColor = DesignSystem.Color.ink
            borderColor = .clear
        case .danger:
            bgColor = DesignSystem.Color.danger
            fgColor = DesignSystem.Color.surface
            borderColor = .clear
        case .accent:
            bgColor = DesignSystem.Color.accent
            fgColor = DesignSystem.Color.surface
            borderColor = .clear
        }

        return configuration.label
            .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
            .fontWeight(DesignSystem.Typography.weightMedium)
            .foregroundStyle(fgColor)
            .padding(.horizontal, DesignSystem.Spacing.s4)
            .padding(.vertical, DesignSystem.Spacing.s2)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isPressed ? bgColor.opacity(0.8) : bgColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.fast, value: isPressed)
    }
}

// MARK: - TextField Style

public struct SayloTextFieldStyle: TextFieldStyle {
    public init() {}

    public func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.base))
            .padding(.horizontal, DesignSystem.Spacing.s3)
            .padding(.vertical, DesignSystem.Spacing.s2)
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
    }
}

// MARK: - Search Field Style

public struct SayloSearchFieldStyle: TextFieldStyle {
    public init() {}

    public func _body(configuration: TextField<_Label>) -> some View {
        HStack(spacing: DesignSystem.Spacing.s2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DesignSystem.Typography.sm))
                .foregroundStyle(DesignSystem.Color.muted)
            configuration
                .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.base))
        }
        .padding(.horizontal, DesignSystem.Spacing.s3)
        .padding(.vertical, DesignSystem.Spacing.s2)
        .background(DesignSystem.Color.ground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.full))
    }
}

// MARK: - Paper Shared Components (V1 Mineral / Verdigris)

/// Window title bar matching Paper artboards 03–05:
/// traffic lights left, centered title (+ optional mono badge), 44pt, chrome bg.
public struct SayloWindowChrome: View {
    let title: String
    var badge: String? = nil

    public init(title: String, badge: String? = nil) {
        self.title = title
        self.badge = badge
    }

    public var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(SwiftUI.Color(hex: "#FF5F56")).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.black.opacity(0.1), lineWidth: 0.5))
                Circle().fill(SwiftUI.Color(hex: "#FFBD2E")).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.black.opacity(0.1), lineWidth: 0.5))
                Circle().fill(SwiftUI.Color(hex: "#27C93F")).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.black.opacity(0.1), lineWidth: 0.5))
            }
            Spacer(minLength: 0)
            HStack(spacing: DesignSystem.Spacing.s2) {
                if title == "Saylo" {
                    SayloMark()
                }
                Text(title)
                    .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                    .fontWeight(DesignSystem.Typography.weightSemibold)
                    .foregroundStyle(DesignSystem.Color.ink)
                if let badge {
                    Text(badge)
                        .font(.custom(DesignSystem.Typography.mono, size: 10))
                        .foregroundStyle(DesignSystem.Color.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Color.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            Spacer(minLength: 0)
            Spacer().frame(width: 50)
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(DesignSystem.Color.chrome)
        .overlay(alignment: .bottom) {
            Divider().overlay(DesignSystem.Color.line)
        }
    }
}

/// Mini waveform logomark used in the title bar.
public struct SayloMark: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1).fill(DesignSystem.Color.ink).frame(width: 2.5, height: 6)
            RoundedRectangle(cornerRadius: 1).fill(DesignSystem.Color.accent).frame(width: 2.5, height: 12)
            RoundedRectangle(cornerRadius: 1).fill(DesignSystem.Color.ink).frame(width: 2.5, height: 8)
            RoundedRectangle(cornerRadius: 1).fill(DesignSystem.Color.ink).frame(width: 2.5, height: 4)
        }
        .frame(height: 14)
    }
}

/// Sidebar navigation row matching Paper: 13px, radius 8, padding 8/12,
/// active = accentSoft fill + accent semibold text.
public struct SayloNavRow: View {
    let title: String
    let emoji: String
    var isActive: Bool = false
    let action: () -> Void

    public init(title: String, emoji: String, isActive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.emoji = emoji
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 13))
                    .foregroundStyle(isActive ? DesignSystem.Color.accent : DesignSystem.Color.muted)
                Text(title)
                    .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                    .fontWeight(isActive ? DesignSystem.Typography.weightSemibold : DesignSystem.Typography.weightRegular)
                    .foregroundStyle(isActive ? DesignSystem.Color.accent : DesignSystem.Color.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? DesignSystem.Color.accentSoft : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Black hero card: ink bg, radius 14, serif-italic headline accent word,
/// gray subcopy, white CTA button.
public struct SayloHeroCard: View {
    let headline: String
    let accentWord: String
    let headlineSuffix: String
    let copy: String
    let ctaTitle: String
    let action: () -> Void

    public init(headline: String, accentWord: String, headlineSuffix: String, copy: String, ctaTitle: String, action: @escaping () -> Void) {
        self.headline = headline
        self.accentWord = accentWord
        self.headlineSuffix = headlineSuffix
        self.copy = copy
        self.ctaTitle = ctaTitle
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(headline)
                        .font(.custom(DesignSystem.Typography.sans, size: 24))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(accentWord)
                        .font(.custom(DesignSystem.Typography.serif, size: 26))
                        .italic()
                        .foregroundStyle(DesignSystem.Color.accent)
                    Text(headlineSuffix)
                        .font(.custom(DesignSystem.Typography.sans, size: 24))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                Text(copy)
                    .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                    .foregroundStyle(DesignSystem.Color.heroSub)
                    .lineLimit(3)
            }
            Button(action: action) {
                Text(ctaTitle)
                    .font(.custom(DesignSystem.Typography.sans, size: 12))
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Color.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
    }
}

/// Simple serif-italic hero (Home artboard headline variant).
public struct SayloSerifHeroCard: View {
    let headline: String
    let copy: String
    let ctaTitle: String
    let action: () -> Void

    public init(headline: String, copy: String, ctaTitle: String, action: @escaping () -> Void) {
        self.headline = headline
        self.copy = copy
        self.ctaTitle = ctaTitle
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(.custom(DesignSystem.Typography.serif, size: 24))
                    .italic()
                    .foregroundStyle(.white)
                Text(copy)
                    .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                    .foregroundStyle(DesignSystem.Color.heroSub)
            }
            Button(action: action) {
                Text(ctaTitle)
                    .font(.custom(DesignSystem.Typography.sans, size: 12))
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Color.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
    }
}

/// Mono section label: 11px, wide tracking, muted (e.g. TODAY, WORDS PER MINUTE).
public struct SayloSectionLabel: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text.uppercased())
            .font(.custom(DesignSystem.Typography.mono, size: 11))
            .tracking(DesignSystem.Typography.trackingWide)
            .foregroundStyle(DesignSystem.Color.muted)
    }
}

/// Rounded progress bar: 6–8pt, track fill, accent/slate fill.
public struct SayloProgressBar: View {
    var value: Double // 0...1
    var fill: SwiftUI.Color = DesignSystem.Color.accent
    var height: CGFloat = 6

    public init(value: Double, fill: SwiftUI.Color = DesignSystem.Color.accent, height: CGFloat = 6) {
        self.value = value
        self.fill = fill
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: height / 2)
                .fill(DesignSystem.Color.track)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(fill)
                        .frame(width: max(2, geo.size.width * min(1, max(0, value))))
                }
        }
        .frame(height: height)
    }
}

/// Toggle matching Paper settings/dialog: 38×22 pill, accent on / track off.
public struct SayloToggleStyle: ToggleStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(DesignSystem.Animation.fast) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(configuration.isOn ? DesignSystem.Color.accent : DesignSystem.Color.track)
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .padding(2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Grouped settings card: chrome-tinted surface, radius 12, hairline border.
public struct SayloGroupCard<Content: View>: View {
    @ViewBuilder let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(DesignSystem.Color.chrome)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
    }
}

// MARK: - Reusable Search Field Component

public struct SearchField: View {
    @Binding private var text: String
    private let placeholder: String

    public init(text: Binding<String>, placeholder: String) {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spacing.s2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DesignSystem.Typography.sm))
                .foregroundStyle(DesignSystem.Color.muted)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.base))
                .foregroundStyle(DesignSystem.Color.ink)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignSystem.Color.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s3)
        .padding(.vertical, DesignSystem.Spacing.s2)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
    }
}
