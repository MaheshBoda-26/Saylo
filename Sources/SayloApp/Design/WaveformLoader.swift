import SwiftUI

/// Native SwiftUI port of `waveform-loader.tsx`.
///
/// React original:
/// - 8 bars, `w-1` (4pt) `rounded-full`, `flex space-x-0.5 h-8`
/// - `animate={{ height: [4, 24, 4] }}`, `duration: 1`,
///   `repeat: Infinity`, `delay: sin(i) * 0.5`, `ease: easeInOut`
///
/// This port uses `TimelineView(.animation)` + cosine easing to reproduce
/// the same easeInOut [4 → 24 → 4] loop without framer-motion.
public struct WaveformLoader: View {
    public var barCount: Int = 8
    public var minHeight: CGFloat = 4
    public var maxHeight: CGFloat = 24
    public var duration: Double = 1.0
    public var barWidth: CGFloat = 4
    public var spacing: CGFloat = 2
    public var color: Color?

    @Environment(\.colorScheme) private var colorScheme

    public init(
        barCount: Int = 8,
        minHeight: CGFloat = 4,
        maxHeight: CGFloat = 24,
        duration: Double = 1.0,
        barWidth: CGFloat = 4,
        spacing: CGFloat = 2,
        color: Color? = nil
    ) {
        self.barCount = barCount
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.duration = duration
        self.barWidth = barWidth
        self.spacing = spacing
        self.color = color
    }

    private var resolvedColor: Color {
        if let color { return color }
        return colorScheme == .dark ? DesignSystem.Color.surface : DesignSystem.Color.ink
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(resolvedColor)
                        .frame(width: barWidth, height: height(at: now, index: i))
                }
            }
            .frame(height: 32)
        }
    }

    private func height(at now: Double, index i: Int) -> CGFloat {
        // Faithful to React: delay = sin(i) * 0.5 (can be negative = start mid-cycle)
        let delay = sin(Double(i)) * 0.5
        var progress = ((now + delay) / duration).truncatingRemainder(dividingBy: 1.0)
        if progress < 0 { progress += 1.0 }
        // Cosine easeInOut matching framer-motion `easeInOut` for [4, 24, 4]
        let eased = 0.5 - 0.5 * cos(progress * 2 * .pi)
        return minHeight + (maxHeight - minHeight) * CGFloat(eased)
    }
}

/// Swift parity for `demo.tsx` — centers the loader full-screen.
public struct WaveformLoaderDemo: View {
    public init() {}
    public var body: some View {
        VStack {
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                WaveformLoader()
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.ground)
    }
}

#Preview {
    WaveformLoaderDemo()
        .frame(width: 400, height: 300)
}
