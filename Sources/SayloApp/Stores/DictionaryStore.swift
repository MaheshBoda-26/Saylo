import Foundation
import SayloCore
import os.log

/// How an edit treats an entry's replacement text.
public enum ReplacementUpdate: Sendable {
    /// Leave whatever is stored in place.
    case unchanged
    /// Remove the replacement (a "word" entry has none).
    case clear
    /// Replace it with this value.
    case set(String)
}

/// Manages dictionary entries with JSON file persistence.
@MainActor
public final class DictionaryStore: ObservableObject {
    public enum StoreError: LocalizedError {
        case emptyPhrase
        case emptyReplacement

        public var errorDescription: String? {
            switch self {
            case .emptyPhrase: return "Enter a word or phrase."
            case .emptyReplacement: return "Enter the replacement text."
            }
        }
    }

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
    public func addEntry(phrase: String, replacement: String? = nil,
                         type: DictionaryEntryType) throws -> DictionaryEntry {
        let trimmedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty else { throw StoreError.emptyPhrase }

        let trimmedReplacement = replacement?.trimmingCharacters(in: .whitespacesAndNewlines)
        if type == .correction, (trimmedReplacement?.isEmpty ?? true) {
            throw StoreError.emptyReplacement
        }

        let entry = DictionaryEntry(
            phrase: trimmedPhrase,
            replacement: trimmedReplacement?.isEmpty == true ? nil : trimmedReplacement,
            type: type
        )

        jsonStore.addDictionaryEntry(entry)
        entries = jsonStore.dictionaryEntries
        rebuildIndexes()
        return entry
    }

    /// Applies every field change in a single write, preserving the entry's
    /// identity and creation date.
    public func updateEntry(_ entry: DictionaryEntry,
                            phrase: String? = nil,
                            replacement: ReplacementUpdate = .unchanged,
                            type: DictionaryEntryType? = nil,
                            isEnabled: Bool? = nil) {
        var updated = entry

        if let phrase {
            let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            updated.phrase = trimmed
        }

        if let type {
            updated.type = type
            // A word entry never carries a replacement.
            if type == .word { updated.replacement = nil }
        }

        switch replacement {
        case .unchanged:
            break
        case .clear:
            updated.replacement = nil
        case .set(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.replacement = trimmed.isEmpty ? nil : trimmed
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

    /// Plain phrase → replacement pairs for `TextPostProcessor`.
    ///
    /// `correctionPairs` holds regular expressions and must not be handed to the
    /// post-processor: it would escape them a second time (so they never match)
    /// and build a nonsense Double Metaphone index from the backslashes.
    public var phraseReplacements: [String: String] {
        var result: [String: String] = [:]
        for entry in entries where entry.isEnabled {
            if let replacement = entry.replacement {
                result[entry.phrase] = replacement
            } else if entry.type == .word {
                // Normalise casing without changing the word.
                result[entry.phrase] = entry.phrase
            }
        }
        return result
    }

    /// Applies post-transcription corrections.
    /// Returns the corrected text and a list of corrections that were applied.
    public func applyCorrections(to text: String) -> (corrected: String, corrections: [CorrectionRecord]) {
        let pairs = correctionPairs.map { CorrectionPair(pattern: $0.pattern, replacement: $0.replacement) }
        let result = CorrectionEngine.apply(pairs, to: text)
        let records = result.applied.map {
            CorrectionRecord(original: $0.original, corrected: $0.replacement, type: .postCorrection)
        }
        return (result.text, records)
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
            let phrase = entry.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty else { continue }

            // For keyword biasing: use the phrase as-is
            keywords.append(phrase)

            // For post-correction: build patterns based on entry type
            switch entry.type {
            case .word:
                // Word/phrase to recognize — add as correction to itself (ensures consistent casing)
                corrections.append((pattern: buildFlexiblePattern(from: phrase), replacement: phrase))

            case .correction:
                if let replacement = entry.replacement?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !replacement.isEmpty {
                    // "when you hear X, write Y" — match flexible versions of X, replace with Y
                    corrections.append((pattern: buildFlexiblePattern(from: phrase), replacement: replacement))
                }
            }
        }

        self.keywordsForBiasing = keywords
        self.correctionPairs = corrections

        logger.debug("Rebuilt indexes: \(keywords.count) keywords, \(corrections.count) correction patterns")
    }

    /// Builds a regex pattern that matches the phrase with flexible spacing/hyphens between words.
    /// "Claude Code" matches "Claude Code", "Claude-Code", "ClaudeCode", etc.
    private func buildFlexiblePattern(from phrase: String) -> String {
        let words = phrase
            .split(whereSeparator: { $0.isWhitespace })
            .map { NSRegularExpression.escapedPattern(for: String($0)) }

        guard let first = words.first else { return "" }
        if words.count == 1 {
            // Single word: match whole word only
            return "\\b\(first)\\b"
        }

        // Multi-word: allow optional whitespace or hyphen between parts
        let joined = words.joined(separator: "[\\s-]*")
        return "\\b\(joined)\\b"
    }
}
