import Foundation

// MARK: - Millisecond duration formatting
//
// Spotify reports track durations in milliseconds. These helpers turn raw `Int`
// values into human-readable strings for the UI.

extension Int {
    // MARK: Track length (mm:ss)

    /// Format a millisecond duration as `m:ss` (e.g. `"3:42"`).
    ///
    /// Suitable for individual track rows where brevity matters.
    ///
    ///     let label = track.durationMs.asTrackLength   // "3:42"
    var asTrackLength: String {
        let totalSeconds = self / 1_000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    // MARK: Listening time (adaptive)

    /// Format a millisecond duration as a concise listening-time string.
    ///
    /// Picks the best unit automatically:
    /// - Under 1 minute  → `"42s"`
    /// - Under 1 hour    → `"23 min"`
    /// - Under 24 hours  → `"4h 12m"`
    /// - 24 hours+       → `"2d 5h"`
    ///
    ///     let label = totalMs.asListeningTime   // "4h 12m"
    var asListeningTime: String {
        let totalSeconds = self / 1_000

        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        }

        let minutes = totalSeconds / 60
        if minutes < 60 {
            return "\(minutes) min"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours < 24 {
            return remainingMinutes > 0
                ? "\(hours)h \(remainingMinutes)m"
                : "\(hours)h"
        }

        let days = hours / 24
        let remainingHours = hours % 24
        return remainingHours > 0
            ? "\(days)d \(remainingHours)h"
            : "\(days)d"
    }
}

// MARK: - Date helpers

// Cached formatters — created once and reused across all calls.
private enum DateFormatters {
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let isoDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}

extension Date {
    /// A relative description like "Today", "Yesterday", or "3 days ago".
    ///
    /// Uses `RelativeDateTimeFormatter` with `.named` style so recent dates
    /// read naturally in the recent-plays list.
    var relativeDisplay: String {
        DateFormatters.relative.localizedString(for: self, relativeTo: .now)
    }

    /// Short date string (e.g. "Jun 18") for chart axis labels.
    var shortDateLabel: String {
        DateFormatters.shortDate.string(from: self)
    }

    /// ISO-8601 date-only string (e.g. "2026-06-18") for grouping plays by day.
    var isoDateString: String {
        DateFormatters.isoDate.string(from: self)
    }
}
