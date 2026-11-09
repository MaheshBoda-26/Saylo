import Foundation
import CoreGraphics

// MARK: - History Entry

public struct DictationEntry: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let date: Date
    public let text: String
    public let rawText: String
    public let language: String
    public let durationSec: Double
    public let appBundleID: String?
    public let correctionsApplied: [CorrectionRecord]

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        text: String,
        rawText: String,
        language: String,
        durationSec: Double,
        appBundleID: String? = nil,
        correctionsApplied: [CorrectionRecord] = []
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.rawText = rawText
        self.language = language
        self.durationSec = durationSec
        self.appBundleID = appBundleID
        self.correctionsApplied = correctionsApplied
    }

    public static func == (lhs: DictationEntry, rhs: DictationEntry) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct CorrectionRecord: Codable, Sendable, Equatable {
    public let original: String
    public let corrected: String
    public let type: CorrectionType
    public let timestamp: Date

    public init(original: String, corrected: String, type: CorrectionType, timestamp: Date = Date()) {
        self.original = original
        self.corrected = corrected
        self.type = type
        self.timestamp = timestamp
    }
}

public enum CorrectionType: String, Codable, Sendable {
    case keywordBias = "keyword_bias"
    case postCorrection = "post_correction"
}

// MARK: - Dictionary Entry

public struct DictionaryEntry: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public var phrase: String
    public var replacement: String?
    public var type: DictionaryEntryType
    public let createdAt: Date
    public var updatedAt: Date
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        phrase: String,
        replacement: String? = nil,
        type: DictionaryEntryType,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.phrase = phrase
        self.replacement = replacement
        self.type = type
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isEnabled = isEnabled
    }

    public static func == (lhs: DictionaryEntry, rhs: DictionaryEntry) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public enum DictionaryEntryType: String, Codable, Sendable, CaseIterable, Identifiable {
    case word = "word"
    case correction = "correction"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .word: return "Word/Phrase"
        case .correction: return "Correction"
        }
    }
}

// MARK: - Preferences are `@AppStorage`-backed in PreferencesStore

public enum HotkeyConfig: String, Codable, Sendable, CaseIterable, Identifiable {
    case fn = "fn"
    case rightOption = "right_option"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fn: return "Fn (Globe)"
        case .rightOption: return "Right Option (⌥)"
        }
    }

    /// Compact form for the floating pill and menu-bar rows.
    public var shortLabel: String {
        switch self {
        case .fn: return "fn"
        case .rightOption: return "⌥"
        }
    }
}

public enum PillPosition: String, Codable, Sendable, CaseIterable, Identifiable {
    case bottomCenter = "bottom_center"
    case topCenter = "top_center"
    case cursor = "cursor"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bottomCenter: return "Bottom Center"
        case .topCenter: return "Top Center"
        case .cursor: return "Near Cursor"
        }
    }
}

public enum SupportedLanguage: String, Codable, Sendable, CaseIterable, Identifiable {
    case auto = "auto"
    case english = "en"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case dutch = "nl"
    case polish = "pl"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .english: return "English"
        case .german: return "German"
        case .french: return "French"
        case .spanish: return "Spanish"
        case .italian: return "Italian"
        case .dutch: return "Dutch"
        case .polish: return "Polish"
        }
    }
}
