import Foundation
import AppKit
import os.log

/// Manages dictation history with JSON file persistence.
@MainActor
public final class HistoryStore: ObservableObject {
    private let jsonStore: JSONStore
    private let logger = Logger(subsystem: "com.saylo", category: "HistoryStore")

    @Published public private(set) var entries: [DictationEntry] = []
    @Published public var searchQuery: String = ""
    @Published public var selectedEntry: DictationEntry?

    public init(jsonStore: JSONStore) {
        self.jsonStore = jsonStore
        self.entries = jsonStore.historyEntries
    }

    public func addEntry(_ entry: DictationEntry) {
        jsonStore.addHistoryEntry(entry)
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

    public func getEntryCount() -> Int {
        return entries.count
    }
}
