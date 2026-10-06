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
                    SidebarFooterRow(emoji: "?", title: "Help") { showingSettings = true }
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

                    SayloSerifHeroCard(
                        headline: "Working around other people?",
                        copy: "With Whistle on-device, whisper or speak softly and Saylo captures every word with zero cloud latency.",
                        ctaTitle: "Show me how"
                    ) {
                        onOpenSettings()
                    }

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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Voice Profile Active!")
                        .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Color.ink)
                    Text("Whistle custom vocabulary tuned to your technical phrasing.")
                        .font(.custom(DesignSystem.Typography.sans, size: 12))
                        .foregroundStyle(DesignSystem.Color.muted)
                    Button(action: onViewReport) {
                        Text("View report")
                            .font(.custom(DesignSystem.Typography.sans, size: 12))
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignSystem.Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
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
                            Text("LONGEST STREAK | \(streak) DAYS")
                                .font(.custom(DesignSystem.Typography.mono, size: 10))
                                .foregroundStyle(DesignSystem.Color.muted)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ForEach(["Jun", "Jul", "Aug", "Sep", "Oct"], id: \.self) { m in
                                    Text(m)
                                        .font(.custom(DesignSystem.Typography.mono, size: 10))
                                        .foregroundStyle(DesignSystem.Color.muted)
                                    if m != "Oct" { Spacer(minLength: 0) }
                                }
                            }
                            HeatmapGrid(activeDays: activeDaySet)
                        }
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

    private var activeDaySet: Set<String> {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return Set(historyStore.entries.map { f.string(from: $0.date) })
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

private struct HeatmapGrid: View {
    let activeDays: Set<String>
    private let cols = 5
    private let rows = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<cols, id: \.self) { c in
                VStack(spacing: 4) {
                    ForEach(0..<rows, id: \.self) { r in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cellColor(col: c, row: r))
                            .frame(width: 14, height: 14)
                    }
                }
            }
        }
    }

    /// Most recent 25 days mapped oldest→newest across columns;
    /// active = accent, otherwise track. Falls back to Paper's
    /// illustrative ramp when there is no history yet.
    private func cellColor(col: Int, row: Int) -> SwiftUI.Color {
        let index = col * rows + row // 0 oldest
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: index - (cols * rows - 1), to: Date()) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        if activeDays.isEmpty {
            // Illustrative ramp matching Paper when empty
            let threshold = [20, 17, 13, 8, 0][col]
            return index >= threshold ? DesignSystem.Color.accent : DesignSystem.Color.track
        }
        if activeDays.contains(f.string(from: day)) {
            return DesignSystem.Color.accent
        }
        return DesignSystem.Color.track
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
}
