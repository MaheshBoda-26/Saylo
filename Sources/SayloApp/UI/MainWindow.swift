import SwiftUI
import AppKit
import DesignSystem

/// Main application window — matches Paper artboards
/// 03 (Home & Dictation Feed), 04 (Insights), 05 (Dictionary):
/// chrome title bar, 210pt sidebar, content, 230pt widget rail on Home.
public struct MainWindow: View {
    @EnvironmentObject private var dictationController: DictationController
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var dictionaryStore: DictionaryStore
    @EnvironmentObject private var preferencesStore: PreferencesStore

    @State private var tab: SayloTab = .dictation
    @State private var showingSettings = false
    /// Reference behavior: starts expanded, the title-bar toggle
    /// collapses it to an icon-only rail and back.
    @State private var sidebarExpanded = true

    public init() {}

    public var body: some View {
        // Reference layout: warm window, sidebar flush left, content in an
        // inset white card with 20pt rounded corners.
        HStack(spacing: 0) {
            SayloSidebar(
                tab: $tab,
                showingSettings: $showingSettings,
                expanded: sidebarExpanded
            )
            .frame(width: sidebarExpanded ? 224 : 84)

            Group {
                switch tab {
                case .dictation:
                    DictationHomeView(onOpenSettings: { showingSettings = true })
                case .insights:
                    InsightsContentView()
                case .dictionary:
                    DictionaryContentView()
                        .environmentObject(dictionaryStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
            .padding(.top, 12)
            .padding(.bottom, 12)
            .padding(.trailing, 12)
            .padding(.leading, 8)
        }
        .animation(.easeOut(duration: 0.22), value: sidebarExpanded)
        .frame(minWidth: 960, minHeight: 680)
        .background(DesignSystem.Color.ground)
        .tint(DesignSystem.Color.accent)
        // Paper design is light-mode only: pin it so native controls
        // (pickers, menus) draw dark text even in system Dark Mode.
        .preferredColorScheme(.light)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeOut(duration: 0.22)) {
                        sidebarExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignSystem.Color.ink)
                }
                .help(sidebarExpanded ? "Collapse sidebar" : "Expand sidebar")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsWindow()
                .environmentObject(preferencesStore)
                .environmentObject(historyStore)
                .environmentObject(dictionaryStore)
                .environmentObject(dictationController)
        }
    }
}

// MARK: - Tabs

enum SayloTab: String, CaseIterable, Identifiable {
    case dictation, insights, dictionary
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dictation: return "Dictation"
        case .insights: return "Insights"
        case .dictionary: return "Dictionary"
        }
    }

    var systemIcon: String {
        switch self {
        case .dictation: return "mic"
        case .insights: return "chart.bar.xaxis"
        case .dictionary: return "book"
        }
    }

    var chromeTitle: String {
        switch self {
        case .dictation: return "Saylo"
        case .insights: return "Saylo — Insights"
        case .dictionary: return "Saylo — Dictionary"
        }
    }

    var chromeBadge: String? {
        tabBadge
    }

    private var tabBadge: String? {
        switch self {
        case .dictation: return "On-Device STT"
        case .insights, .dictionary: return nil
        }
    }
}

// MARK: - Sidebar (210pt, chrome)

private struct SayloSidebar: View {
    @Binding var tab: SayloTab
    @Binding var showingSettings: Bool
    let expanded: Bool

    var body: some View {
        Group {
            if expanded {
                expandedBody
            } else {
                railBody
            }
        }
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Color.chrome)
    }

    private var expandedBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                SayloMark()
                Text("Saylo")
                    .font(DesignSystem.Typography.sans(22, weight: .semibold))
                    .tracking(-0.01)
                    .foregroundStyle(DesignSystem.Color.ink)
            }
            .frame(height: 32)
            .padding(.top, 40)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 16)

            VStack(spacing: 2) {
                ForEach(SayloTab.allCases) { t in
                    FlowNavRow(systemIcon: t.systemIcon, title: t.title, isActive: tab == t) {
                        tab = t
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                if tab == .dictation {
                    WhistleEngineCard()
                        .padding(.bottom, 10)
                }
                Divider()
                    .overlay(DesignSystem.Color.line)
                    .padding(.bottom, 6)
                SidebarFooterRow(systemIcon: "gearshape", title: "Settings") { showingSettings = true }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }

    private var railBody: some View {
        VStack(spacing: 0) {
            SayloMark()
                .padding(.top, 40)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                ForEach(SayloTab.allCases) { t in
                    FlowRailIcon(systemIcon: t.systemIcon, isActive: tab == t) {
                        tab = t
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                RailIconButton(systemIcon: "gearshape") { showingSettings = true }
            }
            .padding(.bottom, 18)
        }
    }
}

/// Rail icon: 40×40 rounded-square, 19pt glyph,
/// active = warm taupe fill, ink glyph.
private struct FlowRailIcon: View {
    let systemIcon: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemIcon)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(DesignSystem.Color.ink)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? DesignSystem.Color.sidebarSelected : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private var title: String {
        switch systemIcon {
        case "mic": return "Dictation"
        case "chart.bar.xaxis": return "Insights"
        case "book": return "Dictionary"
        default: return ""
        }
    }
}

private struct RailIconButton: View {
    let systemIcon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemIcon)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(DesignSystem.Color.ink)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Expanded nav row: 38pt, icon 17 + label 15, 10px gap,
/// active = warm taupe fill + semibold ink text.
private struct FlowNavRow: View {
    let systemIcon: String
    let title: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemIcon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(DesignSystem.Color.ink)
                    .frame(width: 22, alignment: .center)
                Text(title)
                    .font(DesignSystem.Typography.sans(
                        15,
                        weight: isActive ? DesignSystem.Typography.weightSemibold : DesignSystem.Typography.weightRegular
                    ))
                    .foregroundStyle(DesignSystem.Color.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(height: 38, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? DesignSystem.Color.sidebarSelected : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarFooterRow: View {
    let systemIcon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemIcon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(DesignSystem.Color.ink)
                    .frame(width: 22, alignment: .center)
                Text(title)
                    .font(DesignSystem.Typography.sans(14))
                    .foregroundStyle(DesignSystem.Color.ink)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct WhistleEngineCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s1 + 2) {
            HStack(spacing: DesignSystem.Spacing.s2) {
                Circle()
                    .fill(DesignSystem.Color.accent)
                    .frame(width: 6, height: 6)
                Text("Whistle Engine 100% Local")
                    .font(DesignSystem.Typography.sans(
                        DesignSystem.Typography.xs,
                        weight: DesignSystem.Typography.weightSemibold
                    ))
                    .foregroundStyle(DesignSystem.Color.ink)
            }
            Text("Zero cloud delay or subscription fees. Runs directly on your M2.")
                .font(DesignSystem.Typography.sans(DesignSystem.Typography.xs))
                .lineSpacing(2)
                .foregroundStyle(DesignSystem.Color.muted)
        }
        .padding(DesignSystem.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sayloCard()
    }
}

// MARK: - Dictation home (artboard 03)

private struct DictationHomeView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var dictationController: DictationController
    @EnvironmentObject private var preferencesStore: PreferencesStore

    let onOpenSettings: () -> Void

    @State private var showSearch = false

    var body: some View {
        HStack(spacing: 0) {
            // Center timeline
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s6) {
                    Text("Welcome back, Mahesh")
                        .font(DesignSystem.Typography.sans(28, weight: .semibold))
                        .tracking(-0.02)
                        .foregroundStyle(DesignSystem.Color.ink)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s3) {
                        HStack {
                            SayloSectionLabel("Today")
                            Spacer(minLength: 0)
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    showSearch.toggle()
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 15))
                                    .foregroundStyle(DesignSystem.Color.muted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Search dictations")
                        }
                        if showSearch {
                            SearchField(text: $historyStore.searchQuery, placeholder: "Search…")
                        }
                        if timelineEntries.isEmpty {
                            EmptyTimelineView(hotkey: preferencesStore.hotkey.displayName)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(timelineEntries.enumerated()), id: \.element.id) { index, entry in
                                    TimelineRow(entry: entry, showDivider: index < timelineEntries.count - 1)
                                }
                            }
                            .background(DesignSystem.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(DesignSystem.Color.line, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.top, 28)
                .padding(.bottom, DesignSystem.Spacing.s6)
                .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity)

            // Right widget rail (230pt)
            WidgetRail(onViewReport: {})
                .frame(width: 230)
        }
    }

    private var timelineEntries: [DictationEntry] {
        let cal = Calendar.current
        return historyStore.filteredEntries
            .filter { cal.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }
}

private struct TimelineRow: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var dictationController: DictationController

    let entry: DictationEntry
    var showDivider = true

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.s4) {
            Text(timeString)
                .font(DesignSystem.Typography.mono(DesignSystem.Typography.xs))
                .foregroundStyle(DesignSystem.Color.muted)
                .frame(width: 64, alignment: .leading)
                .padding(.top, 2)
            Text(entry.text)
                .font(DesignSystem.Typography.sans(DesignSystem.Typography.base))
                .lineSpacing(DesignSystem.Typography.bodyLineSpacing)
                .foregroundStyle(DesignSystem.Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if isHovered {
                HStack(spacing: 14) {
                    Button {
                        Task { await dictationController.reinsert(entry.text) }
                    } label: {
                        Image(systemName: "play")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Color.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Re-insert")
                    Button {
                        historyStore.copyText(entry.text)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Color.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy")
                    Button {
                        historyStore.deleteEntry(entry)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Color.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More actions")
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) {
            if showDivider {
                Divider()
                    .overlay(DesignSystem.Color.line)
                    .padding(.horizontal, 20)
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = inside
            }
        }
        .contextMenu {
            Button("Copy") { historyStore.copyText(entry.text) }
            Button("Copy Raw") { historyStore.copyText(entry.rawText) }
            Button("Re-insert") { Task { await dictationController.reinsert(entry.text) } }
            Divider()
            Button("Delete", role: .destructive) { historyStore.deleteEntry(entry) }
        }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        return f.string(from: entry.date).lowercased()
    }
}

private struct EmptyTimelineView: View {
    let hotkey: String
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s4) {
            Text("No dictations today yet")
                .font(DesignSystem.Typography.serif(DesignSystem.Typography.serifLarge))
                .italic()
                .foregroundStyle(DesignSystem.Color.ink)
            Text("Hold \(hotkey) anywhere, speak, and release. The words land at your cursor.")
                .font(DesignSystem.Typography.sans(DesignSystem.Typography.base))
                .lineSpacing(DesignSystem.Typography.bodyLineSpacing)
                .foregroundStyle(DesignSystem.Color.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .padding(.vertical, DesignSystem.Spacing.s8)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget rail (230pt, chrome)

private struct WidgetRail: View {
    @EnvironmentObject private var historyStore: HistoryStore

    let onViewReport: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.s6) {
                VStack(alignment: .leading, spacing: 18) {
                    WidgetStat(value: totalWordsString, label: "total words")
                    WidgetStat(value: "\(wpmAverage)", label: "wpm")
                    WidgetStat(value: "\(dayStreak)", label: "day streak")
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Color.statCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.vertical, DesignSystem.Spacing.s6)
            .padding(.horizontal, DesignSystem.Spacing.s4)
        }
        .background(DesignSystem.Color.ground)
    }

    private var totalWords: Int {
        historyStore.entries.reduce(0) { $0 + EntryStats.wordCount($1.text) }
    }

    private var totalWordsString: String {
        if totalWords >= 1000 {
            return String(format: "%.1fK", Double(totalWords) / 1000.0)
        }
        return "\(totalWords)"
    }

    private var wpmAverage: Int {
        let totalDurationMin = historyStore.entries.reduce(0.0) { $0 + $1.durationSec } / 60.0
        guard totalDurationMin > 0.05 else { return 0 }
        return Int(Double(totalWords) / totalDurationMin)
    }

    private var dayStreak: Int {
        EntryStats.dayStreak(for: historyStore.entries.map(\.date))
    }
}

private struct WidgetStat: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s2) {
            Text(value)
                .font(DesignSystem.Typography.serif(30))
                .foregroundStyle(DesignSystem.Color.ink)
            Text(label)
                .font(DesignSystem.Typography.sans(14))
                .foregroundStyle(DesignSystem.Color.muted)
        }
    }
}

// MARK: - Insights (artboard 04)

struct InsightsContentView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s6) {
                HStack {
                    Text("Insights")
                        .sayloHeadline()
                    Spacer(minLength: 0)
                    Button {} label: {
                        Image(systemName: "clock")
                            .font(.system(size: DesignSystem.Typography.sm))
                            .foregroundStyle(DesignSystem.Color.ink)
                            .frame(width: 32, height: 32)
                            .background(Circle().stroke(DesignSystem.Color.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                // Your usage tab
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s2 + 2) {
                    Text("Your usage")
                        .font(DesignSystem.Typography.sans(
                            DesignSystem.Typography.sm,
                            weight: DesignSystem.Typography.weightSemibold
                        ))
                        .foregroundStyle(DesignSystem.Color.ink)
                        .padding(.bottom, DesignSystem.Spacing.s2 + 2)
                        .overlay(alignment: .bottomLeading) {
                            Rectangle()
                                .fill(DesignSystem.Color.ink)
                                .frame(height: 2)
                        }
                    Divider().overlay(DesignSystem.Color.line)
                }

                // Three stat cards
                HStack(spacing: DesignSystem.Spacing.s4) {
                    InsightsCard(title: "WORDS PER MINUTE") {
                        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s2) {
                            Text("\(wpm)")
                                .font(DesignSystem.Typography.sans(
                                    DesignSystem.Typography.xl,
                                    weight: DesignSystem.Typography.weightBold
                                ))
                                .tracking(DesignSystem.Typography.trackingTight)
                                .foregroundStyle(DesignSystem.Color.ink)
                            Text("Top 4%")
                                .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                                .foregroundStyle(DesignSystem.Color.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Color.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                        }
                        SayloProgressBar(value: 0.78)
                    }

                    InsightsCard(title: "FIXES MADE BY SAYLO") {
                        Text("\(fixesTotal.formatted(.number.grouping(.automatic)))")
                            .font(DesignSystem.Typography.sans(
                                DesignSystem.Typography.xl,
                                weight: DesignSystem.Typography.weightBold
                            ))
                            .tracking(DesignSystem.Typography.trackingTight)
                            .foregroundStyle(DesignSystem.Color.ink)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s1) {
                            Text("\(wordsCorrected) words corrected")
                            Text("\(dictionaryFixes) dictionary fixes")
                        }
                        .font(DesignSystem.Typography.sans(DesignSystem.Typography.xs))
                        .foregroundStyle(DesignSystem.Color.muted)
                    }

                    InsightsCard(title: "TOTAL WORDS DICTATED", trend: "↗ 1.4K% this month") {
                        Text("\(totalWords.formatted(.number.grouping(.automatic)))")
                            .font(DesignSystem.Typography.sans(
                                DesignSystem.Typography.xl,
                                weight: DesignSystem.Typography.weightBold
                            ))
                            .tracking(DesignSystem.Typography.trackingTight)
                            .foregroundStyle(DesignSystem.Color.ink)
                        Text("You've written \(scriptsEquivalent) short film scripts!")
                            .font(DesignSystem.Typography.serif(DesignSystem.Typography.sm))
                            .italic()
                            .foregroundStyle(DesignSystem.Color.muted)
                        SayloProgressBar(value: 0.82, height: 8)
                    }
                }

                // Bottom row: desktop usage + streak
                HStack(alignment: .top, spacing: DesignSystem.Spacing.s4) {
                    InsightsCard(
                        title: "WHERE YOU DICTATE",
                        trend: appTotals.isEmpty ? nil : "\(appTotals.count) \(appTotals.count == 1 ? "app" : "apps")"
                    ) {
                        if appTotals.isEmpty {
                            Text("Dictate in any app and it will show up here.")
                                .font(DesignSystem.Typography.serif(DesignSystem.Typography.sm))
                                .italic()
                                .foregroundStyle(DesignSystem.Color.muted)
                        } else {
                            VStack(spacing: DesignSystem.Spacing.s3) {
                                ForEach(appTotals.prefix(3)) { row in
                                    VStack(spacing: DesignSystem.Spacing.s2) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(row.label)
                                                .font(DesignSystem.Typography.sans(
                                                    DesignSystem.Typography.sm,
                                                    weight: DesignSystem.Typography.weightMedium
                                                ))
                                                .foregroundStyle(DesignSystem.Color.ink)
                                                .lineLimit(1)
                                            Spacer(minLength: 0)
                                            Text("\(row.words.formatted(.number.grouping(.automatic))) words")
                                                .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                                                .foregroundStyle(DesignSystem.Color.muted)
                                            Text("\(Int((row.share * 100).rounded()))%")
                                                .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                                                .foregroundStyle(DesignSystem.Color.ink)
                                                .frame(width: 34, alignment: .trailing)
                                        }
                                        SayloProgressBar(value: row.share, fill: DesignSystem.Color.accent)
                                    }
                                }
                            }
                        }
                    }

                    InsightsCard(
                        title: "DICTATION RHYTHM",
                        trend: "\(streak) day streak · best \(longestStreak)"
                    ) {
                        UsageHeatmap(dailyWords: dailyWordCounts)
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.s6)
            .padding(.horizontal, DesignSystem.Spacing.s8)
        }
    }

    private var totalWords: Int {
        historyStore.entries.reduce(0) { $0 + EntryStats.wordCount($1.text) }
    }

    private var wpm: Int {
        let mins = historyStore.entries.reduce(0.0) { $0 + $1.durationSec } / 60.0
        guard mins > 0.05, totalWords > 0 else { return 95 }
        return Int(Double(totalWords) / mins)
    }

    private var fixesTotal: Int {
        let corrections = historyStore.entries.reduce(0) { $0 + $1.correctionsApplied.count }
        return max(corrections, 0)
    }

    private var wordsCorrected: Int { fixesTotal }
    private var dictionaryFixes: Int { 0 }

    private var scriptsEquivalent: Int { max(1, totalWords / 4500) }

    private var streak: Int {
        EntryStats.dayStreak(for: historyStore.entries.map(\.date))
    }

    private var dailyWordCounts: [String: Int] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        var totals: [String: Int] = [:]
        for entry in historyStore.entries {
            totals[f.string(from: entry.date), default: 0] += EntryStats.wordCount(entry.text)
        }
        return totals
    }

    private var longestStreak: Int {
        EntryStats.longestStreak(for: historyStore.entries.map(\.date))
    }

    private var appTotals: [AppTotal] {
        var words: [String: Int] = [:]
        for entry in historyStore.entries {
            words[EntryStats.appName(for: entry), default: 0] += EntryStats.wordCount(entry.text)
        }
        let total = max(1, words.values.reduce(0, +))
        return words
            .sorted { $0.value > $1.value }
            .map { AppTotal(label: $0.key, words: $0.value, share: Double($0.value) / Double(total)) }
    }
}

private struct AppTotal: Identifiable {
    let label: String
    let words: Int
    let share: Double
    var id: String { label }
}

private struct InsightsCard<Content: View>: View {
    let title: String?
    let trend: String?
    @ViewBuilder let content: Content

    init(title: String?, trend: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trend = trend
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s3) {
            if let title {
                HStack {
                    SayloSectionLabel(title)
                    Spacer(minLength: 0)
                    if let trend {
                        Text(trend)
                            .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                            .foregroundStyle(DesignSystem.Color.accent)
                    }
                }
            }
            content
        }
        .padding(DesignSystem.Spacing.s6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sayloCard()
    }
}

/// Real calendar heatmap: one column per week, one row per weekday,
/// ending with the current week. Colour intensity is derived from the
/// number of words dictated that day.
private struct UsageHeatmap: View {
    let dailyWords: [String: Int]

    @State private var hovered: DayCell?

    private let weeks = 26
    private let cell: CGFloat = 12
    private let cellRadius: CGFloat = 2
    private let gap: CGFloat = DesignSystem.Spacing.s1 - 1
    private let cal = Calendar.current

    private struct DayCell: Identifiable {
        let date: Date
        let words: Int
        var id: Date { Calendar.current.startOfDay(for: date) }
    }

    /// Weeks oldest→newest; each is 7 dates, `nil` before the window starts.
    private var grid: [[DayCell?]] {
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1 = Sunday
        let currentWeekStart = cal.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        let firstWeekStart = cal.date(byAdding: .day, value: -7 * (weeks - 1), to: currentWeekStart) ?? currentWeekStart

        return (0..<weeks).map { w in
            let weekStart = cal.date(byAdding: .day, value: 7 * w, to: firstWeekStart) ?? firstWeekStart
            return (0..<7).map { d in
                guard let date = cal.date(byAdding: .day, value: d, to: weekStart) else { return nil }
                return DayCell(date: date, words: words(on: date))
            }
        }
    }

    private var maxWords: Int {
        max(dailyWords.values.max() ?? 0, 1)
    }

    private func words(on date: Date) -> Int {
        dailyWords[key(for: date)] ?? 0
    }

    private func key(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Month label sits above the first week column of each month, skipped
    /// when it would collide with the previous label.
    private var monthLabels: [String?] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        let minimumColumnGap = 3
        var lastLabelledColumn = -minimumColumnGap

        return grid.enumerated().map { index, column in
            defer { lastLabelledColumn = index }
            guard index - lastLabelledColumn >= minimumColumnGap else { return nil }
            guard let first = column.compactMap({ $0 }).first?.date else { return nil }
            let previous = cal.date(byAdding: .day, value: -7, to: first)
            guard let previous,
                  cal.component(.month, from: previous) != cal.component(.month, from: first) else { return nil }
            return f.string(from: first)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s2) {
            HStack(spacing: gap) {
                ForEach(Array(monthLabels.enumerated()), id: \.offset) { _, label in
                    Text(label ?? "")
                        .font(DesignSystem.Typography.mono(DesignSystem.Typography.nano))
                        .foregroundStyle(DesignSystem.Color.muted)
                        .fixedSize()
                        .frame(width: cell, alignment: .leading)
                }
            }

            HStack(alignment: .top, spacing: gap) {
                VStack(spacing: gap) {
                    ForEach(Array(weekdayInitials.enumerated()), id: \.offset) { index, initial in
                        Text(index % 2 == 1 ? initial : "")
                            .font(DesignSystem.Typography.mono(DesignSystem.Typography.nano))
                            .foregroundStyle(DesignSystem.Color.muted)
                            .frame(width: 14, height: cell, alignment: .trailing)
                    }
                }

                HStack(spacing: gap) {
                    ForEach(Array(grid.enumerated()), id: \.offset) { _, column in
                        VStack(spacing: gap) {
                            ForEach(Array(column.enumerated()), id: \.offset) { _, day in
                                if let day {
                                    cellView(day)
                                } else {
                                    Color.clear.frame(width: cell, height: cell)
                                }
                            }
                        }
                    }
                }
            }

            readout
        }
    }

    private var weekdayInitials: [String] {
        let symbols = cal.shortWeekdaySymbols // index 0 = Sunday
        return (0..<7).map { String(symbols[$0].prefix(1)) }
    }

    private func cellView(_ day: DayCell) -> some View {
        let isHovered = hovered?.id == day.id
        let isFuture = day.date > cal.startOfDay(for: Date())
        return RoundedRectangle(cornerRadius: cellRadius)
            .fill(color(for: day))
            .frame(width: cell, height: cell)
            .overlay(
                RoundedRectangle(cornerRadius: cellRadius)
                    .stroke(isHovered ? DesignSystem.Color.ink : .clear, lineWidth: 1)
            )
            .opacity(isFuture ? 0.35 : 1)
            .contentShape(Rectangle())
            .onHover { inside in
                hovered = inside ? day : (hovered?.id == day.id ? nil : hovered)
            }
            .help("\(Self.displayDate(day.date)): \(day.words) \(day.words == 1 ? "word" : "words")")
    }

    private func color(for day: DayCell) -> SwiftUI.Color {
        guard day.words > 0 else { return DesignSystem.Color.track }
        let ratio = Double(day.words) / Double(maxWords)
        let steps: [Double] = [0.25, 0.5, 0.75]
        let level = steps.firstIndex(where: { ratio <= $0 }) ?? 3
        switch level {
        case 0: return DesignSystem.Color.accent.opacity(0.28)
        case 1: return DesignSystem.Color.accent.opacity(0.5)
        case 2: return DesignSystem.Color.accent.opacity(0.74)
        default: return DesignSystem.Color.accent
        }
    }

    @ViewBuilder
    private var readout: some View {
        if let day = hovered {
            HStack(spacing: DesignSystem.Spacing.s2) {
                Text(Self.displayDate(day.date))
                    .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                    .foregroundStyle(DesignSystem.Color.ink)
                Text(day.words == 0 ? "no words dictated" : "\(day.words) \(day.words == 1 ? "word" : "words")")
                    .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                    .foregroundStyle(DesignSystem.Color.muted)
            }
            .frame(height: 14)
        } else {
            HStack(spacing: DesignSystem.Spacing.s2) {
                Text("Fewer")
                    .font(DesignSystem.Typography.mono(DesignSystem.Typography.nano))
                    .foregroundStyle(DesignSystem.Color.muted)
                ForEach(0..<4, id: \.self) { step in
                    RoundedRectangle(cornerRadius: cellRadius)
                        .fill(legendColor(step))
                        .frame(width: 10, height: 10)
                }
                Text("More")
                    .font(DesignSystem.Typography.mono(DesignSystem.Typography.nano))
                    .foregroundStyle(DesignSystem.Color.muted)
            }
            .frame(height: 14)
        }
    }

    private func legendColor(_ level: Int) -> SwiftUI.Color {
        switch level {
        case 0: return DesignSystem.Color.accent.opacity(0.28)
        case 1: return DesignSystem.Color.accent.opacity(0.5)
        case 2: return DesignSystem.Color.accent.opacity(0.74)
        default: return DesignSystem.Color.accent
        }
    }

    private static func displayDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, d MMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Stats helpers

enum EntryStats {
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func appName(for entry: DictationEntry) -> String {
        if let bundleID = entry.appBundleID,
           let name = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.localizedName {
            return name
        }
        return entry.appBundleID.map { ($0 as NSString).lastPathComponent } ?? "Unknown"
    }

    /// Consecutive days with at least one entry, ending today/yesterday.
    static func dayStreak(for dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }
        let cal = Calendar.current
        let days = Set(dates.map { cal.startOfDay(for: $0) })
        var cursor = cal.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Longest run of consecutive days with at least one entry.
    static func longestStreak(for dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }
        let cal = Calendar.current
        let days = Set(dates.map { cal.startOfDay(for: $0) }).sorted()
        var longest = 1
        var run = 1
        for i in 1..<days.count {
            let isConsecutive = cal.dateComponents([.day], from: days[i - 1], to: days[i]).day == 1
            run = isConsecutive ? run + 1 : 1
            longest = max(longest, run)
        }
        return longest
    }
}
