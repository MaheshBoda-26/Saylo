import AppKit
import Foundation
import os.log

/// Manages dictation history with JSON file persistence.
@MainActor
public final class HistoryStore: ObservableObject {
    private let jsonStore: JSONStore
    private let logger = Logger(subsystem: "com.saylo", category: "HistoryStore")

    @Published public private(set) var entries: [DictationEntry] = []
    @Published public var searchQuery: String = ""

    public init(jsonStore: JSONStore) {
        self.jsonStore = jsonStore
        self.entries = jsonStore.historyEntries
    }

    /// - Parameter limit: the user's `maxHistoryItems` preference.
    public func addEntry(_ entry: DictationEntry, limit: Int = 1000) {
        jsonStore.addHistoryEntry(entry, limit: limit)
        entries = jsonStore.historyEntries
    }

    public func deleteEntry(_ entry: DictationEntry) {
        jsonStore.deleteHistoryEntry(entry)
        entries = jsonStore.historyEntries
    }

    public func clearHistory() {
        jsonStore.clearHistory()
        entries = jsonStore.historyEntries
    }

    public var filteredEntries: [DictationEntry] {
        guard !searchQuery.isEmpty else { return entries }
        let query = searchQuery.lowercased()
        return entries.filter { entry in
            entry.text.lowercased().contains(query) ||
            entry.rawText.lowercased().contains(query) ||
            entry.appBundleID?.lowercased().contains(query) ?? false
        }
    }

    public func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
