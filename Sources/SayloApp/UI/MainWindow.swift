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

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            SayloWindowChrome(title: tab.chromeTitle, badge: tab.chromeBadge)

            HStack(spacing: 0) {
                SayloSidebar(tab: $tab, showingSettings: $showingSettings)
                    .frame(width: 210)

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
            }
        }
        .frame(minWidth: 1080, minHeight: 680)
        .background(DesignSystem.Color.ground)
        // Paper design is light-mode only: pin it so native controls
        // (pickers, menus) draw dark text even in system Dark Mode.
        .preferredColorScheme(.light)
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

    var emoji: String {
        switch self {
        case .dictation: return "🎙"
        case .insights: return "📊"
        case .dictionary: return "📖"
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

    var body: some View {
        VStack {
            VStack(spacing: 4) {
                ForEach(SayloTab.allCases) { t in
                    SayloNavRow(title: t.title, emoji: t.emoji, isActive: tab == t) {
                        tab = t
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                if tab == .dictation {
                    WhistleEngineCard()
                }
                VStack(spacing: 4) {
                    Divider().overlay(DesignSystem.Color.line)
                        .padding(.top, 10)
                    SidebarFooterRow(emoji: "⚙", title: "Settings") { showingSettings = true }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 14)
        .background(DesignSystem.Color.chrome)
        .overlay(alignment: .trailing) {
            Divider().overlay(DesignSystem.Color.line)
        }
    }
}

private struct SidebarFooterRow: View {
    let emoji: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(emoji).font(.system(size: 12)).foregroundStyle(DesignSystem.Color.muted)
                Text(title)
                    .font(.custom(DesignSystem.Typography.sans, size: 12))
                    .foregroundStyle(DesignSystem.Color.ink)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct WhistleEngineCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(DesignSystem.Color.accent).frame(width: 6, height: 6)
                Text("Whistle Engine 100% Local")
                    .font(.custom(DesignSystem.Typography.sans, size: 11))
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Color.ink)
            }
            Text("Zero cloud delay or subscription fees. Runs directly on your M2.")
                .font(.custom(DesignSystem.Typography.sans, size: 10))
                .lineSpacing(4 - 10)
                .foregroundStyle(DesignSystem.Color.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
    }
}

// MARK: - Dictation home (artboard 03)

private struct DictationHomeView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var dictationController: DictationController
    @EnvironmentObject private var preferencesStore: PreferencesStore

    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Center timeline
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Welcome back, Mahesh")
                        .font(.custom(DesignSystem.Typography.sans, size: 26))
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Color.ink)

                                        VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SayloSectionLabel("Today")
                            Spacer(minLength: 0)
                            HStack(spacing: 12) {
                                SearchField(text: $historyStore.searchQuery, placeholder: "Search…")
                                    .frame(width: 180)
                                Text("🔍").font(.system(size: 13)).foregroundStyle(DesignSystem.Color.muted)
                            }
                        }
                        if timelineEntries.isEmpty {
                            EmptyTimelineView(hotkey: preferencesStore.hotkey.displayName)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(timelineEntries) { entry in
                                    TimelineRow(entry: entry)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 36)
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

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Text(timeString)
                .font(.custom(DesignSystem.Typography.mono, size: 12))
                .foregroundStyle(DesignSystem.Color.muted)
                .frame(width: 55, alignment: .leading)
            Text(entry.text)
                .font(.custom(DesignSystem.Typography.sans, size: 14))
                .lineSpacing(22 - 14)
                .foregroundStyle(DesignSystem.Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider().overlay(DesignSystem.Color.line)
        }
        .contentShape(Rectangle())
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
        VStack(spacing: 16) {
            Text("No dictations today yet")
                .font(.custom(DesignSystem.Typography.serif, size: 32))
                .foregroundStyle(DesignSystem.Color.ink)
            Text("Hold \(hotkey) anywhere, speak, and release. The words land at your cursor.")
                .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                .foregroundStyle(DesignSystem.Color.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget rail (230pt, chrome)

private struct WidgetRail: View {
    @EnvironmentObject private var historyStore: HistoryStore

    let onViewReport: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    WidgetStat(value: totalWordsString, label: "total words")
                    WidgetStat(value: "\(wpmAverage)", label: "wpm average")
                    WidgetStat(value: "\(dayStreak)", label: "day streak")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(DesignSystem.Color.line, lineWidth: 1)
                )
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 18)
        }
        .background(DesignSystem.Color.chrome)
        .overlay(alignment: .leading) {
            Divider().overlay(DesignSystem.Color.line)
        }
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
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.custom(DesignSystem.Typography.sans, size: 24))
                .fontWeight(.bold)
                .foregroundStyle(DesignSystem.Color.ink)
            Text(label)
                .font(.custom(DesignSystem.Typography.sans, size: 11))
                .foregroundStyle(DesignSystem.Color.muted)
        }
    }
}

// MARK: - Insights (artboard 04)

struct InsightsContentView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Insights")
                        .font(.custom(DesignSystem.Typography.sans, size: 26))
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Color.ink)
                    Spacer(minLength: 0)
                    Button {} label: {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Color.ink)
                            .frame(width: 32, height: 32)
                            .background(Circle().stroke(DesignSystem.Color.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                // Your usage tab
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your usage")
                        .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Color.ink)
                        .padding(.bottom, 10)
                        .overlay(alignment: .bottomLeading) {
                            Rectangle().fill(DesignSystem.Color.ink).frame(height: 2)
                        }
                    Divider().overlay(DesignSystem.Color.line)
                }

                // Three stat cards
                HStack(spacing: 16) {
                    InsightsCard(title: "WORDS PER MINUTE") {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(wpm)")
                                .font(.custom(DesignSystem.Typography.sans, size: 32))
                                .fontWeight(.bold)
                                .foregroundStyle(DesignSystem.Color.ink)
                            Text("Top 4%")
                                .font(.custom(DesignSystem.Typography.mono, size: 11))
                                .foregroundStyle(DesignSystem.Color.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Color.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        SayloProgressBar(value: 0.78)
                    }

                    InsightsCard(title: "FIXES MADE BY SAYLO") {
                        Text("\(fixesTotal.formatted(.number.grouping(.automatic)))")
                            .font(.custom(DesignSystem.Typography.sans, size: 32))
                            .fontWeight(.bold)
                            .foregroundStyle(DesignSystem.Color.ink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(wordsCorrected) words corrected")
                            Text("\(dictionaryFixes) dictionary fixes")
                        }
                        .font(.custom(DesignSystem.Typography.sans, size: 12))
                        .foregroundStyle(DesignSystem.Color.muted)
                    }

                    InsightsCard(title: "TOTAL WORDS DICTATED", trend: "↗ 1.4K% this month") {
                        Text("\(totalWords.formatted(.number.grouping(.automatic)))")
                            .font(.custom(DesignSystem.Typography.sans, size: 32))
                            .fontWeight(.bold)
                            .foregroundStyle(DesignSystem.Color.ink)
                        Text("You've written \(scriptsEquivalent) short film scripts!")
                            .font(.custom(DesignSystem.Typography.serif, size: 13))
                            .italic()
                            .foregroundStyle(DesignSystem.Color.muted)
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4).fill(DesignSystem.Color.accent)
                                .frame(maxWidth: .infinity).frame(height: 8)
                            RoundedRectangle(cornerRadius: 4).fill(DesignSystem.Color.segment)
                                .frame(width: 40, height: 8)
                        }
                    }
                }

                // Bottom row: desktop usage + streak
                HStack(alignment: .top, spacing: 16) {
                    InsightsCard(title: nil) {
                        HStack {
                            Text("Desktop usage")
                                .font(.custom(DesignSystem.Typography.sans, size: 16))
                                .fontWeight(.bold)
                                .foregroundStyle(DesignSystem.Color.ink)
                            Spacer(minLength: 0)
                            Text("TOTAL APPS USED | \(appTotals.count)")
                                .font(.custom(DesignSystem.Typography.mono, size: 10))
                                .foregroundStyle(DesignSystem.Color.muted)
                        }
                        VStack(spacing: 10) {
                            ForEach(Array(appTotals.prefix(3).enumerated()), id: \.element.app) { index, row in
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("\(row.emoji) \(row.label)")
                                            .font(.custom(DesignSystem.Typography.sans, size: 12))
                                            .foregroundStyle(DesignSystem.Color.ink)
                                        Spacer(minLength: 0)
                                        Text("\(Int(row.share * 100))% (\(row.words))")
                                            .font(.custom(DesignSystem.Typography.sans, size: 12))
                                            .foregroundStyle(DesignSystem.Color.muted)
                                    }
                                    SayloProgressBar(value: row.share, fill: row.color)
                                }
                            }
                        }
                    }

                    InsightsCard(title: nil) {
                        HStack {
                            Text("\(streak) day streak")
                                .font(.custom(DesignSystem.Typography.sans, size: 16))
                                .fontWeight(.bold)
                                .foregroundStyle(DesignSystem.Color.ink)
                            Spacer(minLength: 0)
                            Text("LONGEST STREAK | \(longestStreak) DAYS")
                                .font(.custom(DesignSystem.Typography.mono, size: 10))
                                .foregroundStyle(DesignSystem.Color.muted)
                        }
                        UsageHeatmap(dailyWords: dailyWordCounts)
                    }
                }
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 36)
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

    private var appTotals: [(app: String, label: String, emoji: String, words: Int, share: Double, color: SwiftUI.Color)] {
        var words: [String: Int] = [:]
        for entry in historyStore.entries {
            words[EntryStats.appName(for: entry), default: 0] += EntryStats.wordCount(entry.text)
        }
        let total = max(1, words.values.reduce(0, +))
        let sorted = words.sorted { $0.value > $1.value }
        let palette: [SwiftUI.Color] = [DesignSystem.Color.accent, DesignSystem.Color.slateBar, DesignSystem.Color.paleBar]
        let emojiFor = ["🤖", "⚙", "💬"]
        let labelFor = ["AI PROMPTS", "OTHER TASKS", "PERSONAL MESSAGES"]
        return sorted.enumerated().map { i, kv in
            (app: kv.key,
             label: i < 3 ? labelFor[i] : kv.key.uppercased(),
             emoji: i < 3 ? emojiFor[i] : "•",
             words: kv.value,
             share: Double(kv.value) / Double(total),
             color: palette[i % palette.count])
        }
    }
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
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack {
                    SayloSectionLabel(title)
                    Spacer(minLength: 0)
                    if let trend {
                        Text(trend)
                            .font(.custom(DesignSystem.Typography.mono, size: 10))
                            .foregroundStyle(DesignSystem.Color.accent)
                    }
                }
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.chrome)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
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
    private let gap: CGFloat = 3
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

    /// Month label sits above the first week column of each month.
    private var monthLabels: [String?] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return grid.map { column in
            guard let first = column.compactMap({ $0 }).first?.date else { return nil }
            let previous = cal.date(byAdding: .day, value: -7, to: first)
            guard let previous,
                  cal.component(.month, from: previous) != cal.component(.month, from: first) else { return nil }
            return f.string(from: first)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: gap) {
                ForEach(Array(monthLabels.enumerated()), id: \.offset) { _, label in
                    Text(label ?? "")
                        .font(.custom(DesignSystem.Typography.mono, size: 9))
                        .foregroundStyle(DesignSystem.Color.muted)
                        .frame(width: cell, alignment: .leading)
                }
            }

            HStack(alignment: .top, spacing: gap) {
                VStack(spacing: gap) {
                    ForEach(Array(weekdayInitials.enumerated()), id: \.offset) { index, initial in
                        Text(index % 2 == 1 ? initial : "")
                            .font(.custom(DesignSystem.Typography.mono, size: 8))
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
        return RoundedRectangle(cornerRadius: 2)
            .fill(color(for: day))
            .frame(width: cell, height: cell)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
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
            HStack(spacing: 6) {
                Text(Self.displayDate(day.date))
                    .font(.custom(DesignSystem.Typography.mono, size: 10))
                    .foregroundStyle(DesignSystem.Color.ink)
                Text(day.words == 0 ? "no words dictated" : "\(day.words) \(day.words == 1 ? "word" : "words")")
                    .font(.custom(DesignSystem.Typography.mono, size: 10))
                    .foregroundStyle(DesignSystem.Color.muted)
            }
            .frame(height: 14)
        } else {
            HStack(spacing: 6) {
                Text("Fewer")
                    .font(.custom(DesignSystem.Typography.mono, size: 9))
                    .foregroundStyle(DesignSystem.Color.muted)
                ForEach(0..<4, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(legendColor(step))
                        .frame(width: 10, height: 10)
                }
                Text("More")
                    .font(.custom(DesignSystem.Typography.mono, size: 9))
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
