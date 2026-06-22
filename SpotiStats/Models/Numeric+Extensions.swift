import Foundation

// MARK: - Compact Number Formatting

extension BinaryInteger {
    /// Formats large numbers in compact form: 1200 → "1.2K", 1500000 → "1.5M".
    /// Falls back to the raw number string below 1,000.
    var compactFormatted: String {
        let value = Double(self)
        switch abs(value) {
        case 1_000_000_000...:
            return String(format: "%.1fB", value / 1_000_000_000)
                .replacingOccurrences(of: ".0B", with: "B")
        case 1_000_000...:
            return String(format: "%.1fM", value / 1_000_000)
                .replacingOccurrences(of: ".0M", with: "M")
        case 1_000...:
            return String(format: "%.1fK", value / 1_000)
                .replacingOccurrences(of: ".0K", with: "K")
        default:
            return "\(self)"
        }
    }
}

extension Double {
    /// Formats large numbers in compact form: 1200.0 → "1.2K", 1500000.0 → "1.5M".
    var compactFormatted: String {
        switch abs(self) {
        case 1_000_000_000...:
            return String(format: "%.1fB", self / 1_000_000_000)
                .replacingOccurrences(of: ".0B", with: "B")
        case 1_000_000...:
            return String(format: "%.1fM", self / 1_000_000)
                .replacingOccurrences(of: ".0M", with: "M")
        case 1_000...:
            return String(format: "%.1fK", self / 1_000)
                .replacingOccurrences(of: ".0K", with: "K")
        default:
            return String(format: "%.0f", self)
        }
    }
}

// MARK: - Percentage Formatting

extension Double {
    /// Formats as a percentage string: 0.753 → "75.3%", 1.0 → "100%".
    /// Omits the decimal place when the result is a whole number.
    var percentFormatted: String {
        let pct = self * 100
        if pct.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(pct))%"
        }
        return String(format: "%.1f%%", pct)
    }
}

// MARK: - Change Indicators

extension BinaryInteger {
    /// Returns a signed string with a + or - prefix: 5 → "+5", -3 → "-3", 0 → "0".
    var signedString: String {
        if self > 0 { return "+\(self)" }
        if self < 0 { return "\(self)" }
        return "0"
    }
}

extension Double {
    /// Returns a signed string with one decimal place: 5.2 → "+5.2", -3.0 → "-3.0".
    var signedString: String {
        if self > 0 { return String(format: "+%.1f", self) }
        if self < 0 { return String(format: "%.1f", self) }
        return "0"
    }

    /// Returns a signed percentage change string: 0.15 → "+15%", -0.08 → "-8%".
    var changePercentFormatted: String {
        let pct = self * 100
        let rounded = Int(pct.rounded())
        if rounded > 0 { return "+\(rounded)%" }
        if rounded < 0 { return "\(rounded)%" }
        return "0%"
    }
}

// MARK: - Ordinal Formatting

extension Int {
    /// Returns the number with an English ordinal suffix: 1 → "1st", 2 → "2nd", 13 → "13th".
    var ordinal: String {
        let suffix: String
        let ones = self % 10
        let tens = (self / 10) % 10

        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(self)\(suffix)"
    }
}

// MARK: - Clamping

extension Comparable {
    /// Clamps the value to the given closed range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
