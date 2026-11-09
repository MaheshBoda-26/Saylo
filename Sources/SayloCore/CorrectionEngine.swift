import Foundation

/// One "when you hear this, write that" rule.
///
/// `pattern` is a full regular expression (the dictionary builds these), so a
/// single-word rule should include its own boundaries.
public struct CorrectionPair: Sendable, Equatable {
    public let pattern: String
    public let replacement: String

    public init(pattern: String, replacement: String) {
        self.pattern = pattern
        self.replacement = replacement
    }
}

/// Applies dictionary corrections to a transcript.
///
/// The previous implementation looped on `firstMatch` and re-replaced until no
/// match remained. That never terminates when the replacement already satisfies
/// the pattern — which is exactly what a "recognise this word" entry produces,
/// because it maps a phrase onto itself.
///
/// This implementation collects every match against the *original* text, then
/// makes a single greedy left-to-right pass that prefers the longest match at
/// each position. Consequences:
///
/// - every span is rewritten at most once, so a replacement can never feed its
///   own rule (no loops, no cascades)
/// - a more specific rule wins over a shorter one that starts at the same offset
///   ("Claude Code" beats "Claude")
public enum CorrectionEngine {
    public struct Applied: Sendable, Equatable {
        public let original: String
        public let replacement: String

        public init(original: String, replacement: String) {
            self.original = original
            self.replacement = replacement
        }
    }

    public struct Result: Sendable, Equatable {
        public let text: String
        public let applied: [Applied]

        public init(text: String, applied: [Applied]) {
            self.text = text
            self.applied = applied
        }
    }

    private struct Candidate {
        let range: NSRange
        let pair: CorrectionPair
        let original: String
    }

    public static func apply(_ pairs: [CorrectionPair], to text: String) -> Result {
        guard !pairs.isEmpty, !text.isEmpty else {
            return Result(text: text, applied: [])
        }

        let source = text as NSString
        let full = NSRange(location: 0, length: source.length)
        var candidates: [Candidate] = []

        for pair in pairs {
            guard !pair.pattern.isEmpty,
                  let regex = try? NSRegularExpression(pattern: pair.pattern, options: [.caseInsensitive]) else {
                continue
            }
            for match in regex.matches(in: text, options: [], range: full) where match.range.length > 0 {
                candidates.append(Candidate(
                    range: match.range,
                    pair: pair,
                    original: source.substring(with: match.range)
                ))
            }
        }

        guard !candidates.isEmpty else { return Result(text: text, applied: []) }

        // Leftmost first; at the same offset the longest match wins.
        candidates.sort {
            $0.range.location == $1.range.location
                ? $0.range.length > $1.range.length
                : $0.range.location < $1.range.location
        }

        var output = ""
        var cursor = 0
        var applied: [Applied] = []

        for candidate in candidates {
            // Overlaps a span that was already rewritten.
            guard candidate.range.location >= cursor else { continue }

            let gap = NSRange(location: cursor, length: candidate.range.location - cursor)
            output += source.substring(with: gap)

            if candidate.original == candidate.pair.replacement {
                // Already exactly right — keep the original bytes.
                output += candidate.original
            } else {
                output += preserveCase(of: candidate.pair.replacement, matching: candidate.original)
                applied.append(Applied(original: candidate.original,
                                       replacement: candidate.pair.replacement))
            }
            cursor = candidate.range.location + candidate.range.length
        }
        output += source.substring(from: cursor)

        return Result(text: output, applied: applied)
    }

    /// Carries the capitalisation of the matched text onto the replacement, so
    /// "kubernetes" becomes "Kubernetes" but a sentence-initial match stays
    /// sentence-initial.
    private static func preserveCase(of replacement: String, matching original: String) -> String {
        guard original.first?.isUppercase == true, let first = replacement.first else {
            return replacement
        }
        return String(first).uppercased() + replacement.dropFirst()
    }
}
