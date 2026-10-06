import Foundation
import SwiftUI
import AppKit
import DesignSystem
import SayloCore

/// A floating NSPanel that shows the dictation state with live waveform.
public final class FloatingPillPanel: NSPanel {
    private var hostingView: NSHostingView<PillContent>?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: DesignSystem.Container.pill, height: 56),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.animationBehavior = .utilityWindow

        setupContent()
    }

    private func setupContent() {
        let content = PillContent()
        let hosting = NSHostingView(rootView: content)
        hosting.frame = self.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting
        self.hostingView = hosting
    }

    public func updateState(_ state: DictationController.DictationState, level: Float, duration: TimeInterval) {
        DispatchQueue.main.async {
            self.hostingView?.rootView.update(state: state, level: level, duration: duration)
        }
    }

    public func show(at position: PillPosition) {
        guard let screen = NSScreen.main else { return }

        let frame = self.frame
        let newOrigin: CGPoint

        switch position {
        case .bottomCenter:
            newOrigin = CGPoint(
                x: (screen.visibleFrame.width - frame.width) / 2,
                y: screen.visibleFrame.minY + 60
            )
        case .topCenter:
            newOrigin = CGPoint(
                x: (screen.visibleFrame.width - frame.width) / 2,
                y: screen.visibleFrame.maxY - frame.height - 60
            )
        case .cursor:
            let mouseLocation = NSEvent.mouseLocation
            newOrigin = CGPoint(
                x: mouseLocation.x - frame.width / 2,
                y: mouseLocation.y - frame.height - 20
            )
        }

        self.setFrameOrigin(newOrigin)
        self.orderFrontRegardless()
        self.animator().alphaValue = 1.0
    }

    public func hide() {
        self.animator().alphaValue = 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.orderOut(nil)
        }
    }
}

// MARK: - Pill Content View

private struct PillContent: View {
    @State private var state: DictationController.DictationState = .idle
    @State private var level: Float = 0
    @State private var duration: TimeInterval = 0
    @State private var waveformPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: DesignSystem.Radius.full)
                .fill(DesignSystem.Color.ink)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            // Content based on state
            HStack(spacing: DesignSystem.Spacing.s3) {
                stateIcon

                switch state {
                case .recording:
                    recordingView
                case .transcribing:
                    transcribingView
                case .inserting:
                    insertingView
                default:
                    idleView
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.s4)
            .foregroundStyle(DesignSystem.Color.surface)
        }
        .frame(width: DesignSystem.Container.pill, height: 56)
        .animation(DesignSystem.Animation.normal, value: state)
    }

    /// State glyphs mirror Paper's pill states; per-state content views
    /// carry their own icons, so only the error state needs one here.
    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignSystem.Color.danger)
        default:
            EmptyView()
        }
    }

    /// Standby — Paper State 01: "Saylo Ready · fn"
    @ViewBuilder
    private var idleView: some View {
        HStack(spacing: DesignSystem.Spacing.s2) {
            Circle()
                .fill(DesignSystem.Color.surface.opacity(0.35))
                .frame(width: 6, height: 6)
            Text("Saylo Ready")
                .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Color.surface)
            Text(hotkeyDisplay)
                .font(.custom(DesignSystem.Typography.mono, size: 10))
                .foregroundStyle(DesignSystem.Color.surface.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DesignSystem.Color.surface.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    /// Listening — Paper State 02: waveform + "Listening…" + "16kHz"
    @ViewBuilder
    private var recordingView: some View {
        HStack(spacing: DesignSystem.Spacing.s2) {
            WaveformView(level: level, phase: waveformPhase)
                .frame(width: 44, height: 24)

            Text("Listening…")
                .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Color.surface)

            Text(formatDuration(duration))
                .font(.custom(DesignSystem.Typography.mono, size: 10))
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Color.accent)
        }
        .onAppear {
            startWaveformAnimation()
        }
    }

    private func startWaveformAnimation() {
        // Use a repeating timer to drive the waveform animation
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            withAnimation(.linear(duration: 1.0)) {
                waveformPhase = waveformPhase >= 1.0 ? 0.0 : 1.0
            }
        }
    }

    /// Inference — Paper State 03: "Processing… · ~11ms TTFT"
    @ViewBuilder
    private var transcribingView: some View {
        HStack(spacing: DesignSystem.Spacing.s2) {
            Text("Processing…")
                .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Color.surface)
            Text("~11ms TTFT")
                .font(.custom(DesignSystem.Typography.mono, size: 10))
                .foregroundStyle(DesignSystem.Color.surface.opacity(0.6))
        }
    }

    /// Complete — Paper State 04: green check + "Pasted" + "⌘V"
    @ViewBuilder
    private var insertingView: some View {
        HStack(spacing: DesignSystem.Spacing.s2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignSystem.Color.accent)
            Text("Pasted")
                .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Color.surface)
            Text("⌘V")
                .font(.custom(DesignSystem.Typography.mono, size: 10))
                .foregroundStyle(DesignSystem.Color.surface.opacity(0.6))
        }
    }

    private var hotkeyDisplay: String {
        "fn"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    mutating func update(state: DictationController.DictationState, level: Float, duration: TimeInterval) {
        self.state = state
        self.level = level
        self.duration = duration
    }
}

// MARK: - Waveform View

private struct WaveformView: View {
    let level: Float
    let phase: CGFloat
    let barCount = 20

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let height = barHeight(for: i, maxHeight: geometry.size.height)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(DesignSystem.Color.accent)
                        .frame(width: 3, height: height)
                        .animation(.linear(duration: 0.05), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        // Create a wave pattern based on phase and level
        let normalizedIndex = CGFloat(index) / CGFloat(barCount - 1)
        let wave = sin(normalizedIndex * .pi * 2 + phase * .pi * 2)
        let baseHeight: CGFloat = maxHeight * 0.3
        let variableHeight = maxHeight * 0.7 * CGFloat(level) * abs(wave) * 0.5 + 0.5
        return max(2, baseHeight + variableHeight)
    }
}