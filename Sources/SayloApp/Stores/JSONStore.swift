import Foundation
import os.log

/// Simple JSON file-based storage for dictation history and dictionary entries.
/// Avoids SwiftData @Model macro which requires Xcode.
public final class JSONStore: ObservableObject {
    private let logger = Logger(subsystem: "com.saylo", category: "JSONStore")
    private let fileURL: URL
    private let saveQueue = DispatchQueue(label: "com.saylo.jsonstore", qos: .utility)

    @Published public private(set) var historyEntries: [DictationEntry] = []
    @Published public private(set) var dictionaryEntries: [DictionaryEntry] = []

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let sayloDir = appSupport.appendingPathComponent("Saylo", isDirectory: true)
        try? FileManager.default.createDirectory(at: sayloDir, withIntermediateDirectories: true)

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
            logger.error("Failed to load store: \(error.localizedDescription)")
        }
    }

    private func save() {
        let store = StoreData(history: historyEntries, dictionary: dictionaryEntries)
        saveQueue.async { [weak self] in
            guard let self else { return }
            do {
                let data = try JSONEncoder().encode(store)
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                self.logger.error("Failed to save store: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - History

    public func addHistoryEntry(_ entry: DictationEntry) {
        historyEntries.insert(entry, at: 0)
        // Limit history size
        if historyEntries.count > 1000 {
            historyEntries = Array(historyEntries.prefix(1000))
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
        if let index = dictionaryEntries.firstIndex(where: { $0.id == entry.id }) {
            dictionaryEntries[index] = entry
            save()
        }
    }

    public func deleteDictionaryEntry(_ entry: DictionaryEntry) {
        dictionaryEntries.removeAll { $0.id == entry.id }
        save()
    }

    public func toggleDictionaryEntry(_ entry: DictionaryEntry) {
        if let index = dictionaryEntries.firstIndex(where: { $0.id == entry.id }) {
            dictionaryEntries[index].isEnabled.toggle()
            dictionaryEntries[index].updatedAt = Date()
            save()
        }
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