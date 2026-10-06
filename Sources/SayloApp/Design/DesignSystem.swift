import SwiftUI
import CoreText

/// Paper V1 — "Mineral (Verdigris)".
///
/// Limestone and slate neutrals, one verdigris accent, Inter for the work,
/// Instrument Serif for the voice, Geist Mono for keys and metrics.
public enum DesignSystem {

    // MARK: - Colors

    public enum Color {
        public static let surface = colorFromHex("#FFFFFF")
        public static let ground = colorFromHex("#F5F4F0")
        public static let chrome = colorFromHex("#FBFBFA")
        public static let line = colorFromHex("#E5E3DD")
        public static let muted = colorFromHex("#73776F")
        public static let ink = colorFromHex("#1B1D1C")
        public static let accent = colorFromHex("#3E7C6C")
        public static let accentSoft = colorFromHex("#E6EFEC")
        public static let danger = colorFromHex("#B5483B")
        /// Secondary copy on an ink surface — surface at muted opacity.
        public static let heroSub = colorFromHex("#A5A39B")
        /// Chip fill inside an ink card.
        public static let chipDark = colorFromHex("#2C302E")
        /// Empty track (progress bar, toggle off, heatmap cell).
        public static let track = colorFromHex("#E5E3DD")
        /// Inert bar/segment sitting next to an accent fill.
        public static let segment = colorFromHex("#DAD8D0")
        /// Destructive tint behind a warning chip.
        public static let dangerSoft = colorFromHex("#F6E9E6")
        /// Selected sidebar row fill (warm taupe, Flow reference).
        public static let sidebarSelected = colorFromHex("#EAE6D9")
        /// Stats rail card fill (warm beige, Flow reference).
        public static let statCard = colorFromHex("#EFE9DC")
        /// "Pro" badge lavender.
        public static let proBadgeBg = colorFromHex("#EBDFFF")
        public static let proBadgeText = colorFromHex("#6D28D9")
    }

    // MARK: - Bundled Fonts

    /// Registers Inter, Instrument Serif and Geist Mono from `Resources/Fonts`
    /// with CoreText. Called once from the app entry point — without it every
    /// `.custom(DesignSystem.Typography.*)` silently falls back to the system font.
    public static func registerBundledFonts() {
        for url in bundledFontURLs() {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

private static func bundledFontURLs() -> [URL] {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Design
            .deletingLastPathComponent()   // SayloApp
            .appendingPathComponent("Resources", isDirectory: true)

        var roots: [URL] = [sourceRoot]
        if let resourceURL = Bundle.main.resourceURL { roots.append(resourceURL) }
        roots.append(Bundle.main.bundleURL)

        // SwiftPM nests the copied `Resources` directory differently between
        // `swift run` and the assembled .app, so look for any `Fonts`
        // directory a few levels below each root.
        var directories: [URL] = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in enumerator {
                if url.lastPathComponent == "Fonts" {
                    directories.append(url)
                    enumerator.skipDescendants()
                } else if enumerator.level > 4 {
                    enumerator.skipDescendants()
                }
            }
        }

        var files: [URL] = []
        for directory in directories {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else { continue }
            files.append(contentsOf: entries.filter {
                ["ttf", "otf"].contains($0.pathExtension.lowercased())
            })
        }
        return files
    }

    // MARK: - Typography

    public enum Typography {
        public static let sans = "Inter"
        public static let serif = "Instrument Serif"
        public static let mono = "Geist Mono"

        /// Inter and Geist Mono ship legacy-style family names for their
        /// non-RIBBI cuts, so weight has to be resolved at the family level.
        private static func family(_ base: String, weight: Font.Weight) -> String {
            guard base == sans || base == mono else { return base }
            switch weight {
            case .medium:
                return base == mono ? "Geist Mono Medium" : "Inter Medium"
            case .semibold:
                return base == mono ? "Geist Mono Medium" : "Inter SemiBold"
            case .bold, .heavy, .black:
                // Inter's bold cut lives inside the base family.
                return base
            default:
                return base
            }
        }

        public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(family(sans, weight: weight), size: size)
        }

        public static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(family(serif, weight: weight), size: size)
        }

        public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(family(mono, weight: weight), size: size)
        }

        // Size tokens
        public static let micro: CGFloat = 10
        public static let nano: CGFloat = 9
        public static let xs: CGFloat = 12
        public static let sm: CGFloat = 13
        public static let base: CGFloat = 15
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 32
        public static let display: CGFloat = 72

        /// Serif-italic voice size ("You spoke 4,812 words this week.").
        public static let serifLarge: CGFloat = 40
        /// Serif-italic accent word inside an ink card.
        public static let serifAccent: CGFloat = 28
        /// Ink-card headline, sits between Title and Headline.
        public static let hero: CGFloat = 24

        // Weight tokens
        public static let weightRegular: Font.Weight = .regular
        public static let weightMedium: Font.Weight = .medium
        public static let weightSemibold: Font.Weight = .semibold
        public static let weightBold: Font.Weight = .bold

        // Tracking
        public static let trackingTight = -0.03
        public static let trackingDisplay = -0.04
        public static let trackingTitle = -0.01
        public static let trackingWide = 0.08

        // Line height
        public static let leadingBody: CGFloat = 22
        /// Extra leading added to 15pt body copy to reach `leadingBody`.
        public static let bodyLineSpacing: CGFloat = 4
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
        public static let faint: CGFloat = 0.12
        public static let subtle: CGFloat = 0.35
        public static let muted: CGFloat = 0.6
        public static let strong: CGFloat = 0.7
    }

    // MARK: - Elevation

    /// Paper window shadow: `#00000014` at `0 24 64`.
    public enum Shadow {
        public static let windowColor = SwiftUI.Color.black.opacity(0.08)
        public static let windowRadius: CGFloat = 32
        public static let windowY: CGFloat = 24

        public static let cardColor = SwiftUI.Color.black.opacity(0.12)
        public static let cardRadius: CGFloat = 8
        public static let cardY: CGFloat = 4
    }

    // MARK: - Animations

    public enum Animation {
        public static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
        public static let normal = SwiftUI.Animation.easeOut(duration: 0.25)
        public static let slow = SwiftUI.Animation.easeOut(duration: 0.4)
        public static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
    }
}

// MARK: - Color Hex Helper

private func colorFromHex(_ hex: String) -> SwiftUI.Color {
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
    return SwiftUI.Color(
        .sRGB,
        red: Double(r) / 255,
        green: Double(g) / 255,
        blue: Double(b) / 255,
        opacity: Double(a) / 255
    )
}

// MARK: - View Extensions for Design System

public extension View {
    /// Inter at a token size, with the weight resolved to a real family.
    func sayloFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(DesignSystem.Typography.sans(size, weight: weight))
    }

    /// Mono micro-label: `Label / Mono`, 12/500, +0.08em, muted.
    func sayloLabel() -> some View {
        self
            .font(DesignSystem.Typography.mono(
                DesignSystem.Typography.xs,
                weight: DesignSystem.Typography.weightMedium
            ))
            .tracking(DesignSystem.Typography.trackingWide)
            .foregroundStyle(DesignSystem.Color.muted)
    }

    /// Body 15/400 on a 22pt leading.
    func sayloBody() -> some View {
        self
            .font(DesignSystem.Typography.sans(DesignSystem.Typography.base))
            .lineSpacing(DesignSystem.Typography.bodyLineSpacing)
            .foregroundStyle(DesignSystem.Color.ink)
    }

    /// Title 20/600 on -0.01em.
    func sayloTitle() -> some View {
        self
            .font(DesignSystem.Typography.sans(
                DesignSystem.Typography.lg,
                weight: DesignSystem.Typography.weightSemibold
            ))
            .tracking(DesignSystem.Typography.trackingTitle)
            .foregroundStyle(DesignSystem.Color.ink)
    }

    /// Screen headline 32/700 on -0.03em.
    func sayloHeadline() -> some View {
        self
            .font(DesignSystem.Typography.sans(
                DesignSystem.Typography.xl,
                weight: DesignSystem.Typography.weightBold
            ))
            .tracking(DesignSystem.Typography.trackingTight)
            .foregroundStyle(DesignSystem.Color.ink)
    }

    /// Serif italic voice line, 40pt.
    func sayloSerifVoice() -> some View {
        self
            .font(DesignSystem.Typography.serif(DesignSystem.Typography.serifLarge))
            .italic()
            .foregroundStyle(DesignSystem.Color.ink)
    }

    /// Flat card: surface fill, 14pt radius, hairline border, no shadow.
    func sayloCard() -> some View {
        self
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
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
            bgColor = DesignSystem.Color.surface
            fgColor = DesignSystem.Color.ink
            borderColor = DesignSystem.Color.line
        case .ghost:
            bgColor = .clear
            fgColor = DesignSystem.Color.accent
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
            .font(DesignSystem.Typography.sans(
                DesignSystem.Typography.sm,
                weight: DesignSystem.Typography.weightMedium
            ))
            .foregroundStyle(fgColor)
            .padding(.horizontal, DesignSystem.Spacing.s4 + 2)
            .padding(.vertical, DesignSystem.Spacing.s3 - 2)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isPressed ? bgColor.opacity(0.85) : bgColor)
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
            .font(DesignSystem.Typography.sans(DesignSystem.Typography.base))
            .foregroundStyle(DesignSystem.Color.ink)
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
            Spacer().frame(width: 50)
            Spacer(minLength: 0)
            HStack(spacing: DesignSystem.Spacing.s2) {
                if title == "Saylo" {
                    SayloMark()
                }
                Text(title)
                    .font(DesignSystem.Typography.sans(
                        DesignSystem.Typography.sm,
                        weight: DesignSystem.Typography.weightSemibold
                    ))
                    .foregroundStyle(DesignSystem.Color.ink)
                if let badge {
                    Text(badge)
                        .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                        .foregroundStyle(DesignSystem.Color.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Color.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
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

/// Mini waveform logomark: four bars, one verdigris — the Saylo mark.
public struct SayloMark: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1.5).fill(DesignSystem.Color.surface).frame(width: 3, height: 6)
            RoundedRectangle(cornerRadius: 1.5).fill(DesignSystem.Color.accent).frame(width: 3, height: 14)
            RoundedRectangle(cornerRadius: 1.5).fill(DesignSystem.Color.surface).frame(width: 3, height: 10)
            RoundedRectangle(cornerRadius: 1.5).fill(DesignSystem.Color.surface).frame(width: 3, height: 4)
        }
        .padding(.horizontal, 5)
        .frame(width: 28, height: 28)
        .background(DesignSystem.Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
    }
}

/// Sidebar navigation row: 13pt Inter, radius 8, padding 8/12,
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
            HStack(spacing: DesignSystem.Spacing.s2 + 2) {
                Text(emoji)
                    .font(.system(size: DesignSystem.Typography.sm))
                    .foregroundStyle(isActive ? DesignSystem.Color.accent : DesignSystem.Color.muted)
                Text(title)
                    .font(DesignSystem.Typography.sans(
                        DesignSystem.Typography.sm,
                        weight: isActive ? DesignSystem.Typography.weightSemibold : DesignSystem.Typography.weightRegular
                    ))
                    .foregroundStyle(isActive ? DesignSystem.Color.accent : DesignSystem.Color.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, DesignSystem.Spacing.s2)
            .padding(.horizontal, DesignSystem.Spacing.s3)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isActive ? DesignSystem.Color.accentSoft : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Ink hero card (Paper artboard 05): 24/28 padding, radius 14, serif-italic
/// accent word, muted subcopy, accent CTA followed by dark quick chips.
public struct SayloHeroCard: View {
    let headline: String
    let accentWord: String
    let headlineSuffix: String
    let copy: String
    let ctaTitle: String
    var chips: [String] = []
    let action: () -> Void

    public init(
        headline: String,
        accentWord: String,
        headlineSuffix: String,
        copy: String,
        ctaTitle: String,
        chips: [String] = [],
        action: @escaping () -> Void
    ) {
        self.headline = headline
        self.accentWord = accentWord
        self.headlineSuffix = headlineSuffix
        self.copy = copy
        self.ctaTitle = ctaTitle
        self.chips = chips
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s3) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(headline)
                        .font(DesignSystem.Typography.sans(
                            DesignSystem.Typography.hero,
                            weight: DesignSystem.Typography.weightSemibold
                        ))
                        .foregroundStyle(DesignSystem.Color.surface)
                    Text(accentWord)
                        .font(DesignSystem.Typography.serif(DesignSystem.Typography.serifAccent))
                        .italic()
                        .foregroundStyle(DesignSystem.Color.accent)
                    Text(headlineSuffix)
                        .font(DesignSystem.Typography.sans(
                            DesignSystem.Typography.hero,
                            weight: DesignSystem.Typography.weightSemibold
                        ))
                        .foregroundStyle(DesignSystem.Color.surface)
                }
                Text(copy)
                    .font(DesignSystem.Typography.sans(DesignSystem.Typography.sm))
                    .foregroundStyle(DesignSystem.Color.heroSub)
                    .lineLimit(3)
            }
            HStack(spacing: DesignSystem.Spacing.s2) {
                Button(action: action) {
                    Text(ctaTitle)
                        .font(DesignSystem.Typography.sans(
                            DesignSystem.Typography.xs,
                            weight: DesignSystem.Typography.weightMedium
                        ))
                        .foregroundStyle(DesignSystem.Color.surface)
                        .padding(.horizontal, DesignSystem.Spacing.s3)
                        .padding(.vertical, DesignSystem.Spacing.s2 - 2)
                        .background(DesignSystem.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                }
                .buttonStyle(.plain)
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(DesignSystem.Typography.sans(DesignSystem.Typography.xs))
                        .foregroundStyle(DesignSystem.Color.surface)
                        .padding(.horizontal, DesignSystem.Spacing.s3)
                        .padding(.vertical, DesignSystem.Spacing.s2 - 2)
                        .background(DesignSystem.Color.chipDark)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.s6)
        .padding(.horizontal, DesignSystem.Spacing.s6 + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }
}

/// Serif-italic hero variant (Home headline treatment).
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s3) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s1) {
                Text(headline)
                    .font(DesignSystem.Typography.serif(DesignSystem.Typography.serifAccent))
                    .italic()
                    .foregroundStyle(DesignSystem.Color.surface)
                Text(copy)
                    .font(DesignSystem.Typography.sans(DesignSystem.Typography.sm))
                    .foregroundStyle(DesignSystem.Color.heroSub)
            }
            Button(action: action) {
                Text(ctaTitle)
                    .font(DesignSystem.Typography.sans(
                        DesignSystem.Typography.xs,
                        weight: DesignSystem.Typography.weightSemibold
                    ))
                    .foregroundStyle(DesignSystem.Color.ink)
                    .padding(.horizontal, DesignSystem.Spacing.s4)
                    .padding(.vertical, DesignSystem.Spacing.s2)
                    .background(DesignSystem.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DesignSystem.Spacing.s6)
        .padding(.horizontal, DesignSystem.Spacing.s6 + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }
}

/// Mono section label: 12/500, +0.08em, muted (TODAY, WORDS PER MINUTE).
public struct SayloSectionLabel: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text.uppercased())
            .sayloLabel()
    }
}

/// Rounded progress bar: 6pt track, accent fill.
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
            Capsule(style: .continuous)
                .fill(DesignSystem.Color.track)
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(fill)
                        .frame(width: max(height, geo.size.width * min(1, max(0, value))))
                }
        }
        .frame(height: height)
    }
}

/// Toggle matching Paper settings/dialog: 38×22 pill, accent on / track off,
/// 18pt surface knob.
public struct SayloToggleStyle: ToggleStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(DesignSystem.Animation.fast) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(configuration.isOn ? DesignSystem.Color.accent : DesignSystem.Color.track)
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(DesignSystem.Color.surface)
                    .frame(width: 18, height: 18)
                    .padding(2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

/// Grouped settings card: surface fill, radius 10, hairline border.
public struct SayloGroupCard<Content: View>: View {
    @ViewBuilder let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, DesignSystem.Spacing.s4)
            .padding(.vertical, DesignSystem.Spacing.s2)
            .sayloCard()
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
                .font(DesignSystem.Typography.sans(DesignSystem.Typography.base))
                .foregroundStyle(DesignSystem.Color.ink)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DesignSystem.Typography.sm))
                        .foregroundStyle(DesignSystem.Color.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s3)
        .padding(.vertical, DesignSystem.Spacing.s2)
        .frame(height: 38)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
    }
}
