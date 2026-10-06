import Foundation

/// Rule-based cleanup applied to raw Whistle output before insertion.
public struct TextPostProcessor: Sendable {
    /// Case-insensitive whole-word replacements, e.g. ["salo": "Saylo"].
    public var replacements: [String: String]
    /// Strip hesitation markers (uh, um, …) when true.
    public var removingFillers: Bool
    /// Frontmost app bundle ID for context-aware formatting.
    public var appBundleID: String?

    /// Hesitation markers stripped as standalone tokens, elongations included
    /// ("uhhh", "ummm"). The (?!-) guard keeps hyphenated affirmations
    /// ("uh-huh", "uh-oh") intact. Word boundaries keep real words
    /// ("drum", "her", "ahem") untouched.
    static let fillerPattern = "\\b(u+h+|u+m+|h+m+|a+h+|e+r+m*)\\b(?!-)[,…]*"

    public init(replacements: [String: String] = [:], removingFillers: Bool = true, appBundleID: String? = nil) {
        self.replacements = replacements
        self.removingFillers = removingFillers
        self.appBundleID = appBundleID
    }

    public func process(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }

        // 1. Exact replacements (case-insensitive, whole word)
        for (from, to) in replacements {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: from) + "\\b"
            s = s.replacingOccurrences(of: pattern, with: NSRegularExpression.escapedTemplate(for: to),
                                       options: [.regularExpression, .caseInsensitive])
        }

        // 2. Phonetic fuzzy replacements for dictionary words not caught by exact match
        s = applyPhoneticCorrections(s)

        // 3. Remove filler words
        if removingFillers {
            s = s.replacingOccurrences(of: Self.fillerPattern, with: "",
                                       options: [.regularExpression, .caseInsensitive])
            s = s.replacingOccurrences(of: "\\s+([,.!?…])", with: "$1", options: .regularExpression)
            s = s.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
            s = s.replacingOccurrences(of: "^[,;…\\-–—]+\\s*", with: "", options: .regularExpression)
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { return "" }
        }

        // 4. Capitalize first letter
        s = s.prefix(1).uppercased() + s.dropFirst()

        // 5. Context-aware punctuation
        s = applyContextualPunctuation(s)

        return s
    }

    /// Applies phonetic (Double Metaphone) corrections for words that sound like dictionary entries.
    private func applyPhoneticCorrections(_ text: String) -> String {
        guard !replacements.isEmpty else { return text }

        // Build metaphone index from replacements
        var metaphoneMap: [String: String] = [:]
        for (from, to) in replacements {
            let keys = DoubleMetaphone.encode(from.lowercased())
            for key in keys where !key.isEmpty {
                metaphoneMap[key] = to
            }
        }
        guard !metaphoneMap.isEmpty else { return text }

        // Tokenize preserving punctuation boundaries
        let pattern = "(\\w+|[^\\w\\s]+|\\s+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var result = ""
        var lastEnd = text.startIndex

        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match,
                  let tokenRange = Range(match.range(at: 1), in: text) else { return }
            let token = String(text[tokenRange])

            // Only process word tokens (alphanumeric)
            if token.range(of: "\\w", options: .regularExpression) != nil {
                let lower = token.lowercased()
                let keys = DoubleMetaphone.encode(lower)
                var replacement: String?
                for key in keys {
                    if let found = metaphoneMap[key] {
                        replacement = found
                        break
                    }
                }
                if let repl = replacement {
                    // Preserve original casing
                    let finalRepl = token.first?.isUppercase == true ? repl.capitalized : repl
                    result += String(text[lastEnd..<tokenRange.lowerBound]) + finalRepl
                    lastEnd = tokenRange.upperBound
                }
            }
        }
        result += String(text[lastEnd..<text.endIndex])
        return result
    }

    /// Applies context-aware punctuation and formatting.
    private func applyContextualPunctuation(_ text: String) -> String {
        var s = text

        // Detect code context
        let isCodeContext = isCodeApp(appBundleID)

        if isCodeContext {
            // Code context: prefer camelCase, no trailing period for single statements
            if s.contains(" ") || s.contains(".") || s.contains("(") || s.contains("{") {
                // Multi-word or looks like code — ensure proper casing but no forced period
                return s
            }
            // Single token: could be a symbol, don't add period
            return s
        } else {
            // Prose context: ensure sentence ends with punctuation
            if let last = s.last, !".!?…".contains(last) {
                s += "."
            }
            return s
        }
    }

    private func isCodeApp(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        let codeBundles = [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.vscode",
            "com.sublimetext",
            "com.panic.Nova",
            "com.jetbrains.intellij",
            "com.jetbrains.pycharm",
            "com.jetbrains.webstorm",
            "com.jetbrains.goland",
            "com.jetbrains.rider",
            "com.jetbrains.clion",
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "io.alacritty",
            "co.zeit.hyper",
            "net.kovidgoyal.kitty",
            "org.vim",
            "org.neovim",
            "com.github.wezterm",
            "dev.warp.Warp",
            "com.figma.Desktop",
            "com.postmanlabs.mac",
            "com.insomnia.app"
        ]
        return codeBundles.contains(bundleID) || bundleID.contains("vscode") || bundleID.contains("code")
    }
}

/// Double Metaphone implementation for phonetic matching.
/// Ported from the public domain algorithm by Lawrence Philips.
private enum DoubleMetaphone {
    static func encode(_ word: String) -> [String] {
        let primary = metaphone(word, alternate: false)
        let secondary = metaphone(word, alternate: true)
        var result: [String] = []
        if !primary.isEmpty { result.append(primary) }
        if !secondary.isEmpty && secondary != primary { result.append(secondary) }
        return result
    }

    private static func metaphone(_ word: String, alternate: Bool) -> String {
        let input = word.uppercased()
        var result = ""
        var index = 0

        // Skip these at start
        while index < input.count && "AEIOUY".contains(input[index]) { index += 1 }

        while index < input.count && result.count < 4 {
            let c = input[index]
            let next = index + 1 < input.count ? input[index + 1] : nil
            let next2 = index + 2 < input.count ? input[index + 2] : nil
            let _ = index + 3 < input.count ? input[index + 3] : nil
            let prev = index > 0 ? input[index - 1] : nil

            switch c {
            case "A", "E", "I", "O", "U", "Y":
                if result.isEmpty { result += "A" }
                index += 1

            case "B":
                if prev != "B" { result += "P" }
                index += (next == "B" ? 2 : 1)

            case "C":
                if index == 0 && next == "A" && next2 == "R" { // "CAR" at start
                    result += "K"
                    index += 2
                } else if next == "H" {
                    if index > 0 && "AEIOU".contains(prev ?? " ") {
                        result += "K"
                    } else if index == 0 && next2 != nil && "AEIOU".contains(next2!) {
                        result += "K"
                    } else {
                        result += "X"
                    }
                    index += 2
                } else if next == "I" && (next2 == "A" || next2 == "O") { // CIA, CIO
                    result += alternate ? "X" : "S"
                    index += 3
                } else if next == "E" || next == "I" || next == "Y" {
                    result += "S"
                    index += 2
                } else {
                    result += "K"
                    index += 1
                }

            case "D":
                if next == "G" && (next2 == "E" || next2 == "I" || next2 == "Y") { // DGE, DGI, DGY
                    result += "J"
                    index += 3
                } else if next == "G" {
                    result += "TK"
                    index += 2
                } else {
                    result += "T"
                    index += (next == "D" ? 2 : 1)
                }

            case "F":
                result += "F"
                index += (next == "F" ? 2 : 1)

            case "G":
                if next == "H" {
                    if index > 0 && "BDH".contains(prev ?? " ") {
                        // GH after B, D, H is silent
                    } else if index > 0 && "AEIOU".contains(prev ?? " ") {
                        result += "K"
                    } else {
                        // Silent at end or before consonant
                    }
                    index += 2
                } else if next == "N" && index + 2 == input.count { // GN at end
                    result += "N"
                    index += 2
                } else if next == "N" && next2 != nil && "AEIOU".contains(next2!) { // GNE, GNI
                    result += alternate ? "KN" : "N"
                    index += 2
                } else if next == "E" || next == "I" || next == "Y" {
                    result += alternate ? "J" : "K"
                    index += 2
                } else {
                    result += "K"
                    index += (next == "G" ? 2 : 1)
                }

            case "H":
                if index == 0 && (next == "E" || next == "I" || next == "O" || next == "U") {
                    // Initial H before vowel
                    result += "H"
                    index += 1
                } else if index > 0 && "AEIOU".contains(prev ?? " ") && (next == nil || !"AEIOU".contains(next!)) {
                    // H between vowel and consonant
                    result += "H"
                    index += 1
                } else {
                    index += 1
                }

            case "J":
                result += "J"
                index += (next == "J" ? 2 : 1)

            case "K":
                result += "K"
                index += (next == "K" ? 2 : 1)

            case "L":
                result += "L"
                index += (next == "L" ? 2 : 1)

            case "M":
                result += "M"
                index += (next == "M" ? 2 : 1)

            case "N":
                result += "N"
                index += (next == "N" ? 2 : 1)

            case "P":
                if next == "H" {
                    result += "F"
                    index += 2
                } else {
                    result += "P"
                    index += (next == "P" ? 2 : 1)
                }

            case "Q":
                result += "K"
                index += 1

            case "R":
                result += "R"
                index += (next == "R" ? 2 : 1)

            case "S":
                if next == "H" {
                    result += "X"
                    index += 2
                } else if next == "I" && (next2 == "O" || next2 == "A") { // SIO, SIA
                    result += "X"
                    index += 3
                } else if next == "C" && next2 != nil && (next2 == "H" || next2 == "E" || next2 == "I" || next2 == "Y") {
                    // SCH, SCE, SCI, SCY
                    index += 2
                } else {
                    result += "S"
                    index += 1
                }

            case "T":
                if next == "I" && (next2 == "O" || next2 == "A") { // TIO, TIA
                    result += "X"
                    index += 3
                } else if next == "C" && next2 == "H" { // TCH
                    result += "X"
                    index += 3
                } else if next == "H" {
                    result += "0"
                    index += 2
                } else {
                    result += "T"
                    index += (next == "T" ? 2 : 1)
                }

            case "V":
                result += "F"
                index += (next == "V" ? 2 : 1)

            case "W":
                if next == "R" { // WR
                    result += "R"
                    index += 2
                } else if index == 0 && (next == "A" || next == "O") { // WA, WO
                    result += alternate ? "A" : "F"
                    index += 1
                } else if index > 0 && "AEIOU".contains(prev ?? " ") {
                    // W after vowel
                    result += "F"
                    index += 1
                } else {
                    index += 1
                }

            case "X":
                result += "KS"
                index += 1

            case "Z":
                result += "S"
                index += (next == "Z" ? 2 : 1)

            default:
                index += 1
            }
        }

        return String(result.prefix(4))
    }
}

// Extension for subscript access on String
private extension String {
    subscript(_ index: Int) -> Character {
        self[self.index(startIndex, offsetBy: index)]
    }
}