import SwiftUI
import DesignSystem

/// Settings dialog — matches Paper artboard 06:
/// 840×580 modal, 230pt sidebar, serif content title,
/// grouped cards with hairline dividers and Paper toggles.
public struct SettingsWindow: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferencesStore: PreferencesStore
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var dictionaryStore: DictionaryStore
    @EnvironmentObject private var permissionsManager: PermissionsManager

    @State private var selectedTab: PaperSettingsTab = .system

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SETTINGS")
                        .font(.custom(DesignSystem.Typography.mono, size: 10))
                        .tracking(DesignSystem.Typography.trackingWide)
                        .foregroundStyle(DesignSystem.Color.muted)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                    ForEach(PaperSettingsTab.allCases) { tab in
                        SayloNavRow(title: tab.title, emoji: tab.emoji, isActive: selectedTab == tab) {
                            selectedTab = tab
                        }
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saylo v1.0.0 (Apple M2)")
                        .font(.custom(DesignSystem.Typography.mono, size: 10))
                        .foregroundStyle(DesignSystem.Color.muted)
                    Text("Cactus Whistle 16.9 MB")
                        .font(.custom(DesignSystem.Typography.mono, size: 10))
                        .foregroundStyle(DesignSystem.Color.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .frame(width: 230)
            .background(DesignSystem.Color.chrome)
            .overlay(alignment: .trailing) {
                Divider().overlay(DesignSystem.Color.line)
            }

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(selectedTab.title)
                        .font(.custom(DesignSystem.Typography.serif, size: 28))
                        .foregroundStyle(DesignSystem.Color.ink)
                    switch selectedTab {
                    case .general:
                        GeneralPane()
                    case .system:
                        SystemPane()
                    case .microphone:
                        MicrophonePane()
                    case .whistle:
                        WhistlePane()
                    case .permissions:
                        PermissionsPane()
                    }
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DesignSystem.Color.surface)
        }
        .frame(width: 840, height: 580)
        // Paper design is light-mode only: pin it so native controls
        // (segmented + popup pickers) draw dark text in Dark Mode.
        .preferredColorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 80, x: 0, y: 32)
    }
}

private enum PaperSettingsTab: String, CaseIterable, Identifiable {
    case general, system, microphone, whistle, permissions
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .system: return "System"
        case .microphone: return "Microphone"
        case .whistle: return "Whistle Engine"
        case .permissions: return "Permissions"
        }
    }

    var emoji: String {
        switch self {
        case .general: return "⚙"
        case .system: return "💻"
        case .microphone: return "🎙"
        case .whistle: return "⚡"
        case .permissions: return "🔒"
        }
    }
}

// MARK: - Panes

private struct PaneTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
            .fontWeight(.semibold)
            .foregroundStyle(DesignSystem.Color.ink)
    }
}

private struct PaperRow<Content: View>: View {
    let label: String
    var showDivider = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                    .foregroundStyle(DesignSystem.Color.ink)
                Spacer(minLength: 0)
                content
            }
            .padding(.vertical, 12)
            if showDivider {
                Divider().overlay(DesignSystem.Color.line)
            }
        }
    }
}

private struct GeneralPane: View {
    @EnvironmentObject private var preferencesStore: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaneTitle("Dictation")
            SayloGroupCard {
                PaperRow(label: "Push-to-Talk Key") {
                    Picker("", selection: $preferencesStore.hotkey) {
                        ForEach(HotkeyConfig.allCases) { config in
                            Text(config.displayName).tag(config)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
                PaperRow(label: "Hands-Free Mode") {
                    Toggle("", isOn: $preferencesStore.handsFreeEnabled)
                        .toggleStyle(SayloToggleStyle())
                        .labelsHidden()
                }
                PaperRow(label: "Floating Pill Position", showDivider: false) {
                    Picker("", selection: $preferencesStore.pillPosition) {
                        ForEach(PillPosition.allCases) { pos in
                            Text(pos.displayName).tag(pos)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundStyle(DesignSystem.Color.ink)
                    .frame(width: 180)
                }
            }
        }
        VStack(alignment: .leading, spacing: 10) {
            PaneTitle("Language")
            SayloGroupCard {
                PaperRow(label: "Dictation Language", showDivider: false) {
                    Picker("", selection: $preferencesStore.selectedLanguage) {
                        ForEach(SupportedLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundStyle(DesignSystem.Color.ink)
                    .frame(width: 180)
                }
            }
        }
    }
}

private struct SystemPane: View {
    @EnvironmentObject private var preferencesStore: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaneTitle("App settings")
            SayloGroupCard {
                PaperRow(label: "Launch app at login") {
                    Toggle("", isOn: $preferencesStore.launchAtLogin)
                        .toggleStyle(SayloToggleStyle())
                        .labelsHidden()
                }
                PaperRow(label: "Show Saylo Floating Pill at all times") {
                    Toggle("", isOn: $preferencesStore.showFloatingPillAlways)
                        .toggleStyle(SayloToggleStyle())
                        .labelsHidden()
                }
                PaperRow(label: "Show app in dock", showDivider: false) {
                    Toggle("", isOn: $preferencesStore.showInDock)
                        .toggleStyle(SayloToggleStyle())
                        .labelsHidden()
                }
            }
        }
        VStack(alignment: .leading, spacing: 10) {
            PaneTitle("Sound & Feedback")
            SayloGroupCard {
                PaperRow(label: "Dictation and notification sounds") {
                    Toggle("", isOn: $preferencesStore.playSounds)
                        .toggleStyle(SayloToggleStyle())
                        .labelsHidden()
                }
                PaperRow(label: "Mute all audio while dictating", showDivider: false) {
                    Toggle("", isOn: $preferencesStore.muteAudioWhileDictating)
                        .toggleStyle(SayloToggleStyle())
                        .labelsHidden()
                }
            }
        }
    }
}

private struct MicrophonePane: View {
    @EnvironmentObject private var permissionsManager: PermissionsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaneTitle("Input")
            SayloGroupCard {
                PaperRow(label: "Microphone", showDivider: false) {
                    Text("MacBook Air Mic")
                        .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                        .foregroundStyle(DesignSystem.Color.ink)
                }
            }
        }
        VStack(alignment: .leading, spacing: 10) {
            PaneTitle("Access")
            PermissionCard(
                title: "Microphone",
                subtitle: "Required for audio capture",
                isGranted: permissionsManager.hasMicrophonePermission,
                grant: { await permissionsManager.requestMicrophonePermission() },
                openSettings: { permissionsManager.openMicrophoneSettings() }
            )
        }
    }
}

private struct WhistlePane: View {
    @EnvironmentObject private var dictionaryStore: DictionaryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaneTitle("On-Device Engine")
            SayloGroupCard {
                PaperRow(label: "Model") {
                    Text("whistle.cact · 16.9 MB")
                        .font(.custom(DesignSystem.Typography.mono, size: DesignSystem.Typography.sm))
                        .foregroundStyle(DesignSystem.Color.ink)
                }
                PaperRow(label: "Languages", showDivider: false) {
                    Text("en, de, fr, es, it, nl, pl")
                        .font(.custom(DesignSystem.Typography.mono, size: DesignSystem.Typography.sm))
                        .foregroundStyle(DesignSystem.Color.muted)
                }
            }
        }
        VStack(alignment: .leading, spacing: 10) {
            PaneTitle("Vocabulary Biasing")
            SayloGroupCard {
                PaperRow(label: "Dictionary Entries", showDivider: false) {
                    Text("\(dictionaryStore.entries.filter(\.isEnabled).count) active")
                        .font(.custom(DesignSystem.Typography.mono, size: DesignSystem.Typography.sm))
                        .foregroundStyle(DesignSystem.Color.muted)
                }
            }
        }
    }
}

private struct PermissionsPane: View {
    @EnvironmentObject private var permissionsManager: PermissionsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaneTitle("System Access")
            PermissionCard(
                title: "Microphone",
                subtitle: "Required for audio capture",
                isGranted: permissionsManager.hasMicrophonePermission,
                grant: { await permissionsManager.requestMicrophonePermission() },
                openSettings: { permissionsManager.openMicrophoneSettings() }
            )
            PermissionCard(
                title: "Accessibility",
                subtitle: "Required for global hotkey and text insertion",
                isGranted: permissionsManager.hasAccessibilityPermission,
                grant: { permissionsManager.requestAccessibilityPermission() },
                openSettings: { permissionsManager.openAccessibilitySettings() }
            )
        }
    }
}

// MARK: - Notification Names (posted by settings/vocabulary panes)

extension Notification.Name {
    static let openDictionary = Notification.Name("com.saylo.openDictionary")
    static let exportDictionary = Notification.Name("com.saylo.exportDictionary")
    static let importDictionary = Notification.Name("com.saylo.importDictionary")
    static let clearHistory = Notification.Name("com.saylo.clearHistory")
}

private struct PermissionCard: View {
    let title: String
    let subtitle: String
    let isGranted: Bool
    let grant: () async -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(isGranted ? DesignSystem.Color.accent : DesignSystem.Color.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.base))
                    .foregroundStyle(DesignSystem.Color.ink)
                Text(subtitle)
                    .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                    .foregroundStyle(DesignSystem.Color.muted)
            }
            Spacer(minLength: 0)
            if !isGranted {
                Button("Grant access") {
                    Task { await grant() }
                }
                .sayloButtonStyle(.accent)
            }
            Button("Open System Settings →") {
                openSettings()
            }
            .font(.custom(DesignSystem.Typography.sans, size: 12))
            .foregroundStyle(DesignSystem.Color.accent)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(DesignSystem.Color.chrome)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
    }
}
