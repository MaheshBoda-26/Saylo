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
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignSystem.Color.ink)
                        .frame(width: 28, height: 28)
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 1).fill(.white).frame(width: 2, height: 5)
                        RoundedRectangle(cornerRadius: 1).fill(DesignSystem.Color.accent).frame(width: 2, height: 10)
                        RoundedRectangle(cornerRadius: 1).fill(.white).frame(width: 2, height: 7)
                        RoundedRectangle(cornerRadius: 1).fill(.white).frame(width: 2, height: 4)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Saylo")
                        .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Color.ink)
                    Text("Whistle STT · \(statusText)")
                        .font(.custom(DesignSystem.Typography.mono, size: 11))
                        .foregroundStyle(DesignSystem.Color.muted)
                }
                Spacer(minLength: 0)
                Circle()
                    .fill(statusDot)
                    .frame(width: 8, height: 8)
                    .symbolEffect(.pulse, options: .repeating, value: dictationController.state == .recording)
            }
            .padding(14)

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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider().overlay(DesignSystem.Color.line)

            // Quick actions
            VStack(spacing: 2) {
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
                            .font(.custom(DesignSystem.Typography.mono, size: 11))
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
            .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
            .foregroundStyle(DesignSystem.Color.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 300)
        .background(DesignSystem.Color.surface)
        // Paper design is light-mode only.
        .preferredColorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
                    .font(.custom(DesignSystem.Typography.sans, size: 12))
                    .foregroundStyle(isHighlighted ? DesignSystem.Color.accent : DesignSystem.Color.muted)
                    .fontWeight(isHighlighted ? .medium : .regular)
                Spacer(minLength: 0)
                Text(value)
                    .font(.custom(DesignSystem.Typography.mono, size: 11))
                    .foregroundStyle(DesignSystem.Color.ink)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? DesignSystem.Color.accentSoft : .clear)
            )
            if showDivider {
                Divider().overlay(DesignSystem.Color.line.opacity(0.5))
                    .padding(.horizontal, 10)
            }
        }
    }
}
