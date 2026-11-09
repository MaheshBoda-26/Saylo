import Foundation
import os.log

/// Simple JSON file-based storage for dictation history and dictionary entries.
/// Avoids SwiftData @Model macro which requires Xcode.
///
/// The store is deliberately small: one snapshot file, written atomically on a
/// serial background queue. Mutations must happen on the main thread; the
/// snapshot is captured before the write is handed off.
public final class JSONStore: ObservableObject {
    private let logger = Logger(subsystem: "com.saylo", category: "JSONStore")
    private let fileURL: URL
    private let saveQueue = DispatchQueue(label: "com.saylo.jsonstore", qos: .utility)

    @Published public private(set) var historyEntries: [DictationEntry] = []
    @Published public private(set) var dictionaryEntries: [DictionaryEntry] = []

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        let sayloDir = appSupport.appendingPathComponent("Saylo", isDirectory: true)
        try? FileManager.default.createDirectory(at: sayloDir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])

        self.fileURL = sayloDir.appendingPathComponent("store.json")
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let store = try JSONDecoder().decode(StoreData.self, from: data)
            historyEntries = store.history
            dictionaryEntries = store.dictionary
            logger.info("Loaded \(self.historyEntries.count) history entries, \(self.dictionaryEntries.count) dictionary entries")
        } catch {
            // Keep the unreadable file instead of letting the next save
            // overwrite it with an empty store — a decode failure is
            // recoverable, silent data loss is not.
            logger.error("Failed to load store: \(error.localizedDescription)")
            quarantineUnreadableStore()
        }
    }

    private func quarantineUnreadableStore() {
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = fileURL
            .deletingPathExtension()
            .appendingPathExtension("corrupt-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: backup)
            logger.info("Moved unreadable store to \(backup.lastPathComponent)")
        } catch {
            logger.error("Could not quarantine unreadable store: \(error.localizedDescription)")
        }
    }

    private func save() {
        let store = StoreData(history: historyEntries, dictionary: dictionaryEntries)
        let url = fileURL
        let logger = logger
        saveQueue.async {
            do {
                let data = try JSONEncoder().encode(store)
                try data.write(to: url, options: .atomic)
                // Transcripts are personal: keep the file readable only by the user.
                try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                                      ofItemAtPath: url.path)
            } catch {
                logger.error("Failed to save store: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - History

    public func addHistoryEntry(_ entry: DictationEntry, limit: Int = 1000) {
        historyEntries.insert(entry, at: 0)
        let maxEntries = max(1, limit)
        if historyEntries.count > maxEntries {
            historyEntries = Array(historyEntries.prefix(maxEntries))
        }
        save()
    }

    public func deleteHistoryEntry(_ entry: DictationEntry) {
        historyEntries.removeAll { $0.id == entry.id }
        save()
    }

    public func clearHistory() {
        historyEntries.removeAll()
        save()
    }

    // MARK: - Dictionary

    public func addDictionaryEntry(_ entry: DictionaryEntry) {
        dictionaryEntries.append(entry)
        save()
    }

    public func updateDictionaryEntry(_ entry: DictionaryEntry) {
        guard let index = dictionaryEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        dictionaryEntries[index] = entry
        save()
    }

    public func deleteDictionaryEntry(_ entry: DictionaryEntry) {
        dictionaryEntries.removeAll { $0.id == entry.id }
        save()
    }

    public func toggleDictionaryEntry(_ entry: DictionaryEntry) {
        guard let index = dictionaryEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        dictionaryEntries[index].isEnabled.toggle()
        dictionaryEntries[index].updatedAt = Date()
        save()
    }

    // MARK: - Internal

    private struct StoreData: Codable {
        let history: [DictationEntry]
        let dictionary: [DictionaryEntry]

        init(history: [DictationEntry], dictionary: [DictionaryEntry]) {
            self.history = history
            self.dictionary = dictionary
        }
    }
}
