import Foundation

// MARK: - String Utility Extensions

/// Convenience extensions for display formatting, truncation, and text processing.
extension String {

    // MARK: - Truncation

    /// Returns the string truncated to `maxLength` characters with a trailing ellipsis if it
    /// exceeds the limit. Returns the original string if it fits.
    func truncated(to maxLength: Int) -> String {
        guard count > maxLength, maxLength > 0 else { return self }
        let endIndex = index(startIndex, offsetBy: maxLength)
        return String(self[..<endIndex]) + "\u{2026}"
    }

    // MARK: - Whitespace Helpers

    /// A trimmed copy with leading and trailing whitespace and newlines removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `true` when the string is empty or contains only whitespace.
    var isBlank: Bool {
        trimmed.isEmpty
    }

    // MARK: - Display Formatting

    /// Formats a numeric string into a compact, human-readable form ("1234" -> "1.2K").
    /// Returns the original string if it cannot be parsed as an integer.
    var compactNumber: String {
        guard let value = Int(self) else { return self }
        return value.compactFormatted
    }

    /// Capitalizes only the first character, leaving the rest unchanged.
    var sentenceCased: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }

    // MARK: - Artist / Track Name Helpers

    /// Patterns matching common parenthetical track-name suffixes ("(feat. ...)",
    /// "(Remastered)", "[Bonus Track]", etc.). Pre-compiled once; invalid patterns are dropped.
    private static let trackNoiseRegexes: [NSRegularExpression] = {
        let patterns = [
            #"\s*[\(\[](?:feat\.|ft\.|featuring)\s+[^\)\]]+[\)\]]"#,
            #"\s*[\(\[](?:Remaster(?:ed)?|Deluxe|Bonus Track|Live|Acoustic|Radio Edit|"#
                + #"Single Version)[^\)\]]*[\)\]]"#
        ]
        return patterns.compactMap {
            try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
        }
    }()

    /// Strips common parenthetical suffixes from track names for cleaner display.
    var cleanedTrackName: String {
        var result = self
        for regex in Self.trackNoiseRegexes {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        return result.trimmed
    }

    /// Joins multiple artist names with commas and "&" before the last one.
    static func formattedArtistList(_ artists: [String]) -> String {
        switch artists.count {
        case 0:
            return ""
        case 1:
            return artists[0]
        case 2:
            return "\(artists[0]) & \(artists[1])"
        default:
            let allButLast = artists.dropLast().joined(separator: ", ")
            let last = artists.last ?? ""
            return "\(allButLast) & \(last)"
        }
    }
}

// MARK: - Int Compact Formatting

extension Int {

    /// Formats the integer into a compact human-readable string (1_200 -> "1.2K", 1_500_000 -> "1.5M").
    var compactFormatted: String {
        let absValue = abs(self)
        let sign = self < 0 ? "-" : ""

        switch absValue {
        case 0..<1_000:
            return "\(sign)\(absValue)"
        case 1_000..<1_000_000:
            return "\(sign)\(Self.formatDecimal(Double(absValue) / 1_000))K"
        case 1_000_000..<1_000_000_000:
            return "\(sign)\(Self.formatDecimal(Double(absValue) / 1_000_000))M"
        default:
            return "\(sign)\(Self.formatDecimal(Double(absValue) / 1_000_000_000))B"
        }
    }

    /// One-decimal string with a trailing ".0" dropped for cleaner display.
    private static func formatDecimal(_ value: Double) -> String {
        let formatted = String(format: "%.1f", value)
        return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
    }
}
