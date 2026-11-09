import Foundation
import SwiftUI
import AppKit
import DesignSystem
import SayloCore

/// A floating NSPanel that shows the dictation state with live waveform.
public final class FloatingPillPanel: NSPanel {
    private var hostingView: NSHostingView<PillContent>?
    private var pendingHide: DispatchWorkItem?

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
        self.alphaValue = 0

        setupContent()
    }

    private func setupContent() {
        let content = PillContent(state: .idle, level: 0, duration: 0, hotkey: "fn")
        let hosting = NSHostingView(rootView: content)
        hosting.frame = self.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting
        self.hostingView = hosting
    }

    /// Replaces the hosted root view. SwiftUI diffs the new value, so no
    /// out-of-band state mutation is needed.
    public func updateState(_ state: DictationController.DictationState,
                            level: Float,
                            duration: TimeInterval,
                            hotkey: String) {
        DispatchQueue.main.async { [weak self] in
            self?.hostingView?.rootView = PillContent(
                state: state,
                level: level,
                duration: duration,
                hotkey: hotkey
            )
        }
    }

    public func show(at position: PillPosition) {
        pendingHide?.cancel()
        pendingHide = nil

        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let frame = self.frame
        let newOrigin: CGPoint

        switch position {
        case .bottomCenter:
            newOrigin = CGPoint(
                x: visible.minX + (visible.width - frame.width) / 2,
                y: visible.minY + 60
            )
        case .topCenter:
            newOrigin = CGPoint(
                x: visible.minX + (visible.width - frame.width) / 2,
                y: visible.maxY - frame.height - 60
            )
        case .cursor:
            let mouse = NSEvent.mouseLocation
            let x = min(max(mouse.x - frame.width / 2, visible.minX + 8),
                        visible.maxX - frame.width - 8)
            let y = min(max(mouse.y - frame.height - 20, visible.minY + 8),
                        visible.maxY - frame.height - 8)
            newOrigin = CGPoint(x: x, y: y)
        }

        self.setFrameOrigin(newOrigin)
        self.alphaValue = 1
        self.orderFrontRegardless()
    }

    public func hide() {
        pendingHide?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.orderOut(nil)
            self.pendingHide = nil
        }
        pendingHide = work

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}

// MARK: - Pill Content View

private struct PillContent: View {
    let state: DictationController.DictationState
    let level: Float
    let duration: TimeInterval
    let hotkey: String

    var body: some View {
        ZStack {
            // Background
            Capsule(style: .continuous)
                .fill(DesignSystem.Color.ink)
                .shadow(
                    color: DesignSystem.Shadow.cardColor,
                    radius: DesignSystem.Shadow.cardRadius,
                    x: 0,
                    y: DesignSystem.Shadow.cardY
                )

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle: return "Saylo ready"
        case .recording: return "Listening"
        case .transcribing: return "Processing"
        case .inserting: return "Pasted"
        case .error: return "Error"
        }
    }

    /// State glyphs mirror Paper's pill states; per-state content views
    /// carry their own icons, so only the error state needs one here.
    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DesignSystem.Typography.xs, weight: .medium))
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
                .fill(DesignSystem.Color.surface.opacity(DesignSystem.Opacity.subtle))
                .frame(width: 6, height: 6)
            Text("Saylo Ready")
                .font(DesignSystem.Typography.sans(
                    DesignSystem.Typography.sm,
                    weight: DesignSystem.Typography.weightMedium
                ))
                .foregroundStyle(DesignSystem.Color.surface)
            Text(hotkey)
                .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                .foregroundStyle(DesignSystem.Color.surface.opacity(DesignSystem.Opacity.strong))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DesignSystem.Color.surface.opacity(DesignSystem.Opacity.faint))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
        }
    }

    /// Listening — Paper State 02: waveform + "Listening…" + mono duration
    @ViewBuilder
    private var recordingView: some View {
        HStack(spacing: DesignSystem.Spacing.s2) {
            WaveformView(level: level)
                .frame(width: 44, height: 24)

            Text("Listening…")
                .font(DesignSystem.Typography.sans(
                    DesignSystem.Typography.sm,
                    weight: DesignSystem.Typography.weightMedium
                ))
                .foregroundStyle(DesignSystem.Color.surface)

            Text(Self.formatDuration(duration))
                .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Color.accent)
        }
    }

    /// Inference — Paper State 03: waveform-loader + "Processing…"
    @ViewBuilder
    private var transcribingView: some View {
        HStack(spacing: DesignSystem.Spacing.s2) {
            WaveformLoader(color: DesignSystem.Color.surface)
            Text("Processing…")
                .font(DesignSystem.Typography.sans(
                    DesignSystem.Typography.sm,
                    weight: DesignSystem.Typography.weightMedium
                ))
                .foregroundStyle(DesignSystem.Color.surface)
        }
    }

    /// Complete — Paper State 04: check + "Pasted" + "⌘V"
    @ViewBuilder
    private var insertingView: some View {
        HStack(spacing: DesignSystem.Spacing.s2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DesignSystem.Typography.xs, weight: .medium))
                .foregroundStyle(DesignSystem.Color.accent)
            Text("Pasted")
                .font(DesignSystem.Typography.sans(
                    DesignSystem.Typography.sm,
                    weight: DesignSystem.Typography.weightMedium
                ))
                .foregroundStyle(DesignSystem.Color.surface)
            Text("⌘V")
                .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                .foregroundStyle(DesignSystem.Color.surface.opacity(DesignSystem.Opacity.muted))
        }
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Waveform View

/// Live input meter. The animation phase comes from `TimelineView`, so no timer
/// has to be created — or remembered to be invalidated — per appearance.
private struct WaveformView: View {
    let level: Float
    private let barCount = 20

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1)

            GeometryReader { geometry in
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(DesignSystem.Color.accent)
                            .frame(width: 3, height: barHeight(for: index,
                                                               maxHeight: geometry.size.height,
                                                               phase: phase))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func barHeight(for index: Int, maxHeight: CGFloat, phase: Double) -> CGFloat {
        let normalizedIndex = CGFloat(index) / CGFloat(barCount - 1)
        let wave = sin(normalizedIndex * .pi * 2 + CGFloat(phase) * .pi * 2)
        let baseHeight: CGFloat = maxHeight * 0.3
        let variableHeight = maxHeight * 0.7 * CGFloat(level) * abs(wave) * 0.5 + 0.5
        return max(2, baseHeight + variableHeight)
    }
}
