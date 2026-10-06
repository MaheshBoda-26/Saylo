import Foundation

/// Rule-based cleanup applied to raw Whistle output before insertion.
public struct TextPostProcessor: Sendable {
    /// Case-insensitive whole-word replacements, e.g. ["salo": "Saylo"].
    public var replacements: [String: String]
    /// Strip hesitation markers (uh, um, …) when true.
    public var removingFillers: Bool

    /// Hesitation markers stripped as standalone tokens, elongations included
    /// ("uhhh", "ummm"). The (?!-) guard keeps hyphenated affirmations
    /// ("uh-huh", "uh-oh") intact. Word boundaries keep real words
    /// ("drum", "her", "ahem") untouched.
    static let fillerPattern = "\\b(u+h+|u+m+|h+m+|a+h+|e+r+m*)\\b(?!-)[,…]*"

    public init(replacements: [String: String] = [:], removingFillers: Bool = true) {
        self.replacements = replacements
        self.removingFillers = removingFillers
    }

    public func process(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        for (from, to) in replacements {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: from) + "\\b"
            s = s.replacingOccurrences(of: pattern, with: NSRegularExpression.escapedTemplate(for: to),
                                       options: [.regularExpression, .caseInsensitive])
        }
        if removingFillers {
            s = s.replacingOccurrences(of: Self.fillerPattern, with: "",
                                       options: [.regularExpression, .caseInsensitive])
            // Rejoin what the fillers leave behind: double spaces,
            // orphaned space before punctuation, leading punctuation.
            s = s.replacingOccurrences(of: "\\s+([,.!?…])", with: "$1", options: .regularExpression)
            s = s.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
            s = s.replacingOccurrences(of: "^[,;…\\-–—]+\\s*", with: "", options: .regularExpression)
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { return "" }
        }
        s = s.prefix(1).uppercased() + s.dropFirst()
        if let last = s.last, !".!?…".contains(last) { s += "." }
        return s
    }
}
