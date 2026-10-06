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

public extension DictionaryEntry {
    var displayText: String {
        if let replacement = replacement {
            return "\(phrase) → \(replacement)"
        }
        return phrase
    }

    var keywordForBiasing: String {
        return phrase
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

// MARK: - Preferences (AppStorage backed, not JSONStore)

public struct Preferences: Codable, Sendable, Equatable {
    public var hotkey: HotkeyConfig
    public var language: String
    public var playSounds: Bool
    public var handsFreeEnabled: Bool
    public var launchAtLogin: Bool
    public var pillPosition: PillPosition
    public var showMenuBarIcon: Bool
    public var maxHistoryItems: Int
    public var showFloatingPillAlways: Bool
    public var showInDock: Bool
    public var muteAudioWhileDictating: Bool

    public init(
        hotkey: HotkeyConfig = .fn,
        language: String = "auto",
        playSounds: Bool = true,
        handsFreeEnabled: Bool = true,
        launchAtLogin: Bool = false,
        pillPosition: PillPosition = .bottomCenter,
        showMenuBarIcon: Bool = true,
        maxHistoryItems: Int = 1000,
        showFloatingPillAlways: Bool = false,
        showInDock: Bool = true,
        muteAudioWhileDictating: Bool = false
    ) {
        self.hotkey = hotkey
        self.language = language
        self.playSounds = playSounds
        self.handsFreeEnabled = handsFreeEnabled
        self.launchAtLogin = launchAtLogin
        self.pillPosition = pillPosition
        self.showMenuBarIcon = showMenuBarIcon
        self.maxHistoryItems = maxHistoryItems
        self.showFloatingPillAlways = showFloatingPillAlways
        self.showInDock = showInDock
        self.muteAudioWhileDictating = muteAudioWhileDictating
    }
}

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

    public var keyCode: UInt16 {
        switch self {
        case .fn: return 0x3F // Fn key
        case .rightOption: return 0x3D // Right Option
        }
    }

    public var modifierFlags: CGEventFlags {
        switch self {
        case .fn: return []
        case .rightOption: return .maskAlternate
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
