import Foundation

// MARK: - Date Formatting Extensions

extension Date {
      // MARK: Relative Display

      /// Returns a human-readable relative time string for analytics displays.
      /// Examples: "Just now", "3 min ago", "2 hours ago", "Yesterday", "3 days ago", "Jun 15".
      func relativeDisplay(relativeTo now: Date = .now) -> String {
                let interval = now.timeIntervalSince(self)

                guard interval >= 0 else { return "Just now" }

                let seconds = Int(interval)
                let minutes = seconds / 60
                let hours = minutes / 60
                let days = hours / 24

                switch seconds {
                          case 0..<60:
                              return "Just now"
                          case 60..<3_600:
                              return minutes == 1 ? "1 min ago" : "\(minutes) min ago"
                          case 3_600..<86_400:
                              return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
                          default:
                              break
                }

                if days == 1 { return "Yesterday" }
                if days < 7 { return "\(days) days ago" }

                let formatter = DateFormatter()
                formatter.dateFormat = Calendar.current.isDate(self, equalTo: now, toGranularity: .year)
                    ? "MMM d"
                    : "MMM d, yyyy"
                return formatter.string(from: self)
      }

      // MARK: Time-Range Helpers

      /// Start of the current calendar day (midnight).
      var startOfDay: Date {
                Calendar.current.startOfDay(for: self)
      }

      /// Start of the calendar week (Sunday or locale-dependent).
      var startOfWeek: Date {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
                return calendar.date(from: components) ?? self
      }

      /// Start of the calendar month.
      var startOfMonth: Date {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month], from: self)
                return calendar.date(from: components) ?? self
      }

      /// Returns true if this date falls within the same calendar week as `other`.
      func isSameWeek(as other: Date) -> Bool {
                Calendar.current.isDate(self, equalTo: other, toGranularity: .weekOfYear)
      }

      /// Returns true if this date falls within the same calendar day as `other`.
      func isSameDay(as other: Date) -> Bool {
                Calendar.current.isDate(self, equalTo: other, toGranularity: .day)
      }

      // MARK: Analytics Period Labels

      /// Short period label for section headers in analytics views.
      /// Examples: "Today", "This Week", "June 2026".
      func periodLabel(relativeTo now: Date = .now) -> String {
                let calendar = Calendar.current

                if calendar.isDateInToday(self) {
                              return "Today"
                }
                if calendar.isDateInYesterday(self) {
                              return "Yesterday"
                }
                if isSameWeek(as: now) {
                              return "This Week"
                }

                let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: now.startOfWeek)
                if let lastWeekStart, self >= lastWeekStart, self < now.startOfWeek {
                              return "Last Week"
                }

                let formatter = DateFormatter()
                formatter.dateFormat = calendar.isDate(self, equalTo: now, toGranularity: .year)
                    ? "MMMM"
                    : "MMMM yyyy"
                return formatter.string(from: self)
      }

      // MARK: ISO Formatting

      /// ISO 8601 string with fractional seconds, suitable for Supabase queries.
      var iso8601String: String {
                ISO8601DateFormatter.shared.string(from: self)
      }
}

// MARK: - Shared ISO Formatter

extension ISO8601DateFormatter {
      fileprivate static let shared: ISO8601DateFormatter = {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
      }()
}
