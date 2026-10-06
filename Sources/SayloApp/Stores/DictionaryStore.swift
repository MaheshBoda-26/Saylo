import Foundation
import SwiftUI
import os.log

/// Manages dictionary entries with JSON file persistence.
@MainActor
public final class DictionaryStore: ObservableObject {
    private let jsonStore: JSONStore
    private let logger = Logger(subsystem: "com.saylo", category: "DictionaryStore")

    @Published public private(set) var entries: [DictionaryEntry] = []
    @Published public private(set) var keywordsForBiasing: [String] = []
    @Published public private(set) var correctionPairs: [(pattern: String, replacement: String)] = []

    public init(jsonStore: JSONStore) {
        self.jsonStore = jsonStore
        self.entries = jsonStore.dictionaryEntries
        rebuildIndexes()
    }

    // MARK: - Public API

    @discardableResult
    public func addEntry(phrase: String, replacement: String? = nil, type: DictionaryEntryType) -> DictionaryEntry {
        let trimmedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty else { fatalError("Phrase cannot be empty") }

        if let replacement {
            let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedReplacement.isEmpty else { fatalError("Replacement cannot be empty") }
        }

        let entry = DictionaryEntry(
            phrase: trimmedPhrase,
            replacement: replacement?.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type
        )

        jsonStore.addDictionaryEntry(entry)
        entries = jsonStore.dictionaryEntries
        rebuildIndexes()
        return entry
    }

    public func updateEntry(_ entry: DictionaryEntry, phrase: String? = nil, replacement: String? = nil, isEnabled: Bool? = nil) {
        var updated = entry
        if let phrase {
            let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            updated.phrase = trimmed
        }
        if let replacement {
            let trimmed = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.replacement = trimmed.isEmpty ? nil : trimmed
        }
        if let isEnabled {
            updated.isEnabled = isEnabled
        }
        updated.updatedAt = Date()
        jsonStore.updateDictionaryEntry(updated)
        entries = jsonStore.dictionaryEntries
        rebuildIndexes()
    }

    public func deleteEntry(_ entry: DictionaryEntry) {
        jsonStore.deleteDictionaryEntry(entry)
        entries = jsonStore.dictionaryEntries
        rebuildIndexes()
    }

    public func toggleEnabled(_ entry: DictionaryEntry) {
        jsonStore.toggleDictionaryEntry(entry)
        entries = jsonStore.dictionaryEntries
        rebuildIndexes()
    }

    public func search(_ query: String) -> [DictionaryEntry] {
        let lowerQuery = query.lowercased()
        guard !lowerQuery.isEmpty else { return entries }
        return entries.filter { entry in
            entry.phrase.lowercased().contains(lowerQuery) ||
            (entry.replacement?.lowercased().contains(lowerQuery) ?? false)
        }
    }

    // MARK: - Engine Integration

    /// Returns keywords for Whistle's `keywords` parameter (biasing).
    /// Limited to a reasonable count to avoid model drift.
    public func getKeywordsForBiasing(maxCount: Int = 50) -> [String] {
        return Array(keywordsForBiasing.prefix(maxCount))
    }

    /// Applies post-transcription corrections.
    /// Returns the corrected text and a list of corrections that were applied.
    public func applyCorrections(to text: String) -> (corrected: String, corrections: [CorrectionRecord]) {
        var corrected = text
        var appliedCorrections: [CorrectionRecord] = []

        // Sort by pattern length descending (longest match first)
        let sortedPairs = correctionPairs.sorted { $0.pattern.count > $1.pattern.count }

        for (pattern, replacement) in sortedPairs {
            let result = applyCorrectionPattern(
                pattern: pattern,
                replacement: replacement,
                to: corrected
            )
            if result.didChange {
                appliedCorrections.append(CorrectionRecord(
                    original: result.originalMatch,
                    corrected: replacement,
                    type: .postCorrection
                ))
                corrected = result.correctedText
            }
        }

        return (corrected, appliedCorrections)
    }

    /// Validates a dictionary entry and returns warnings if problematic.
    public func validateEntry(phrase: String, replacement: String?) -> [String] {
        var warnings: [String] = []

        // Check for common words that might be over-matched
        let commonWords = [
            "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with",
            "a", "an", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could",
            "should", "may", "might", "must", "can", "this", "that", "these", "those"
        ]

        let lowerPhrase = phrase.lowercased()
        if commonWords.contains(lowerPhrase) {
            warnings.append("'\(phrase)' is a very common word — corrections may fire unexpectedly")
        }

        // Check for short phrases that might match inside other words
        if phrase.count <= 3 && !phrase.contains(" ") {
            warnings.append("Short phrases (≤3 chars) may match inside other words")
        }

        // Check if replacement would create a word that looks like another common word
        if let replacement = replacement {
            let lowerReplacement = replacement.lowercased()
            for common in commonWords {
                if lowerReplacement.contains(common) && lowerReplacement != common {
                    warnings.append("Replacement '\(replacement)' contains '\(common)' — may cause confusion")
                    break
                }
            }
        }

        // Check for overlapping entries
        for entry in entries where entry.isEnabled {
            if entry.phrase.lowercased() == lowerPhrase {
                warnings.append("An entry for '\(phrase)' already exists")
                break
            }
            // Check for substring relationships
            if entry.phrase.lowercased().contains(lowerPhrase) || lowerPhrase.contains(entry.phrase.lowercased()) {
                warnings.append("Overlaps with existing entry '\(entry.phrase)' — longest match wins")
            }
        }

        return warnings
    }

    // MARK: - Private Implementation

    private func rebuildIndexes() {
        var keywords: [String] = []
        var corrections: [(pattern: String, replacement: String)] = []

        for entry in entries where entry.isEnabled {
            // For keyword biasing: use the phrase as-is
            keywords.append(entry.phrase)

            // For post-correction: build patterns based on entry type
            switch entry.type {
            case .word:
                // Word/phrase to recognize — add as correction to itself (ensures consistent casing)
                let pattern = buildFlexiblePattern(from: entry.phrase)
                corrections.append((pattern: pattern, replacement: entry.phrase))

            case .correction:
                if let replacement = entry.replacement {
                    // "when you hear X, write Y" — match flexible versions of X, replace with Y
                    let pattern = buildFlexiblePattern(from: entry.phrase)
                    corrections.append((pattern: pattern, replacement: replacement))
                }
            }
        }

        self.keywordsForBiasing = keywords
        self.correctionPairs = corrections

        logger.debug("Rebuilt indexes: \(keywords.count) keywords, \(corrections.count) correction patterns")
    }

    /// Builds a regex pattern that matches the phrase with flexible spacing/hyphens between words.
    /// "Claude Code" matches "Claude Code", "Claude-Code", "ClaudeCode", "Cloud Code", etc.
    private func buildFlexiblePattern(from phrase: String) -> String {
        let words = phrase
            .split(separator: " ")
            .map { NSRegularExpression.escapedPattern(for: String($0)) }

        if words.count == 1 {
            // Single word: match whole word only
            return "\\b\(words[0])\\b"
        }

        // Multi-word: allow optional whitespace or hyphen between parts
        let joined = words.joined(separator: "[\\s-]*")
        return "\\b\(joined)\\b"
    }

    /// Applies a single correction pattern to text.
    private func applyCorrectionPattern(pattern: String, replacement: String, to text: String) -> (didChange: Bool, originalMatch: String, correctedText: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return (false, "", text)
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var correctedText = text
        var didChange = false
        var lastMatch = ""

        // Find all matches and replace them (longest match first is handled by sorted pairs)
        while let match = regex.firstMatch(in: correctedText, options: [], range: NSRange(correctedText.startIndex..<correctedText.endIndex, in: correctedText)) {
            if let matchRange = Range(match.range(at: 0), in: correctedText) {
                let matchedText = String(correctedText[matchRange])
                lastMatch = matchedText

                // Preserve case of first character if the match starts with uppercase
                var finalReplacement = replacement
                if matchedText.first?.isUppercase == true, let first = replacement.first {
                    finalReplacement = String(first).uppercased() + replacement.dropFirst()
                }

                correctedText.replaceSubrange(matchRange, with: finalReplacement)
                didChange = true
            } else {
                break
            }
        }

        return (didChange, lastMatch, correctedText)
    }
}

// MARK: - Export/Import for plain file editing

public extension DictionaryStore {
    struct ExportFormat: Codable {
        public var entries: [ExportEntry]
        public var exportedAt: Date

        public init(entries: [DictionaryEntry]) {
            self.entries = entries.map { ExportEntry(from: $0) }
            self.exportedAt = Date()
        }
    }

    struct ExportEntry: Codable {
        public let phrase: String
        public let replacement: String?
        public let type: DictionaryEntryType
        public let isEnabled: Bool

        public init(from entry: DictionaryEntry) {
            self.phrase = entry.phrase
            self.replacement = entry.replacement
            self.type = entry.type
            self.isEnabled = entry.isEnabled
        }
    }

    func export() throws -> Data {
        let format = ExportFormat(entries: entries.filter { $0.isEnabled })
        return try JSONEncoder().encode(format)
    }

    func importFrom(data: Data) throws -> (added: Int, updated: Int, errors: [String]) {
        let format = try JSONDecoder().decode(ExportFormat.self, from: data)
        var added = 0
        var updated = 0
        var errors: [String] = []

        for exportEntry in format.entries {
            // Check if entry exists
            if let existing = entries.first(where: { $0.phrase.lowercased() == exportEntry.phrase.lowercased() }) {
                // Update existing
                var updatedEntry = existing
                updatedEntry.replacement = exportEntry.replacement
                updatedEntry.type = exportEntry.type
                updatedEntry.isEnabled = exportEntry.isEnabled
                updatedEntry.updatedAt = Date()
                jsonStore.updateDictionaryEntry(updatedEntry)
                updated += 1
            } else {
                // Add new
                let entry = DictionaryEntry(
                    phrase: exportEntry.phrase,
                    replacement: exportEntry.replacement,
                    type: exportEntry.type,
                    isEnabled: exportEntry.isEnabled
                )
                jsonStore.addDictionaryEntry(entry)
                added += 1
            }
        }

        entries = jsonStore.dictionaryEntries
        rebuildIndexes()
        return (added, updated, errors)
    }
}