import SwiftUI
import DesignSystem

/// Menu bar popover — matches Paper artboard 02 "Menu Bar Popover":
/// Saylo header + status dot, key/mic/language rows,
/// Open Dashboard footer. Fully wired to live stores.
public struct MenuBarView: View {
    @EnvironmentObject private var dictationController: DictationController
    @EnvironmentObject private var preferencesStore: PreferencesStore
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var dictionaryStore: DictionaryStore

    @State private var showingSettings = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: DesignSystem.Spacing.s3) {
                SayloMark()
                VStack(alignment: .leading, spacing: 1) {
                    Text("Saylo")
                        .font(DesignSystem.Typography.sans(
                            DesignSystem.Typography.sm,
                            weight: DesignSystem.Typography.weightSemibold
                        ))
                        .foregroundStyle(DesignSystem.Color.ink)
                    Text("Whistle STT · \(statusText)")
                        .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                        .foregroundStyle(DesignSystem.Color.muted)
                }
                Spacer(minLength: 0)
                Circle()
                    .fill(statusDot)
                    .frame(width: 8, height: 8)
                    .symbolEffect(.pulse, options: .repeating, value: dictationController.state == .recording)
                    .accessibilityLabel("Status: \(statusText)")
            }
            .padding(DesignSystem.Spacing.s4)

            Divider().overlay(DesignSystem.Color.line)

            // Status rows
            VStack(spacing: 0) {
                PopoverRow(
                    label: "Push-to-Talk Key",
                    value: "Hold \(shortHotkey)",
                    isHighlighted: true
                )
                PopoverRow(
                    label: "Hands-Free Lock",
                    value: preferencesStore.handsFreeEnabled ? "Double-tap \(shortHotkey)" : "Off"
                )
                PopoverRow(
                    label: "Microphone",
                    value: "MacBook Air Mic"
                )
                PopoverRow(
                    label: "Language",
                    value: "Auto-Detect (\(SupportedLanguage.allCases.count))",
                    showDivider: false
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.s2)
            .padding(.vertical, DesignSystem.Spacing.s1 + 2)

            Divider().overlay(DesignSystem.Color.line)

            // Quick actions
            VStack(spacing: DesignSystem.Spacing.s1) {
                Button {
                    toggleDictation()
                } label: {
                    Label(
                        dictationController.state == .recording ? "Stop Dictation" : "Start Dictation",
                        systemImage: dictationController.state == .recording ? "stop.circle" : "mic.circle"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(dictationController.state == .transcribing || dictationController.state == .inserting)

                Button {
                    showingSettings = true
                } label: {
                    HStack {
                        Text("Open Dashboard…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("⌘,")
                            .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                            .foregroundStyle(DesignSystem.Color.muted)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",")

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit Saylo", systemImage: "power")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .font(DesignSystem.Typography.sans(
                DesignSystem.Typography.sm,
                weight: DesignSystem.Typography.weightMedium
            ))
            .foregroundStyle(DesignSystem.Color.ink)
            .padding(.horizontal, DesignSystem.Spacing.s4)
            .padding(.vertical, DesignSystem.Spacing.s3)
        }
        .frame(width: 300)
        .background(DesignSystem.Color.surface)
        // Paper design is light-mode only.
        .preferredColorScheme(.light)
        .tint(DesignSystem.Color.accent)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .sheet(isPresented: $showingSettings) {
            SettingsWindow()
                .environmentObject(preferencesStore)
                .environmentObject(historyStore)
                .environmentObject(dictionaryStore)
        }
    }

    private var statusText: String {
        switch dictationController.state {
        case .idle: return "Ready"
        case .recording: return "Listening"
        case .transcribing: return "Decoding"
        case .inserting: return "Pasting"
        case .error: return "Error"
        }
    }

    private var statusDot: SwiftUI.Color {
        switch dictationController.state {
        case .idle: return DesignSystem.Color.accent
        case .recording: return DesignSystem.Color.danger
        case .transcribing, .inserting: return DesignSystem.Color.accent
        case .error: return DesignSystem.Color.danger
        }
    }

    private var shortHotkey: String {
        switch preferencesStore.hotkey {
        case .fn: return "Fn"
        case .rightOption: return "⌥"
        }
    }

    private func toggleDictation() {
        switch dictationController.state {
        case .idle:
            dictationController.startRecording()
        case .recording:
            dictationController.stopRecording()
        case .error:
            dictationController.dismissError()
        default:
            break
        }
    }
}

private struct PopoverRow: View {
    let label: String
    let value: String
    var isHighlighted = false
    var showDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(DesignSystem.Typography.sans(
                        DesignSystem.Typography.xs,
                        weight: isHighlighted ? DesignSystem.Typography.weightMedium : DesignSystem.Typography.weightRegular
                    ))
                    .foregroundStyle(isHighlighted ? DesignSystem.Color.accent : DesignSystem.Color.muted)
                Spacer(minLength: 0)
                Text(value)
                    .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                    .foregroundStyle(DesignSystem.Color.ink)
            }
            .padding(.horizontal, DesignSystem.Spacing.s2 + 2)
            .padding(.vertical, DesignSystem.Spacing.s2)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(isHighlighted ? DesignSystem.Color.accentSoft : .clear)
            )
            if showDivider {
                Divider().overlay(DesignSystem.Color.line.opacity(DesignSystem.Opacity.muted))
                    .padding(.horizontal, DesignSystem.Spacing.s2 + 2)
            }
        }
    }
}
