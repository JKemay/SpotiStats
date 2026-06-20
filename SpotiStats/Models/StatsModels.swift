import Foundation

// Decoded shapes for the `stats_*` Postgres RPCs (Phase 3). Keys are the SQL column names
// (snake_case); explicit `CodingKeys` map them so we don't depend on the Supabase client's
// decoder configuration.

/// The window a stats screen is showing. `days == nil` means all collected history.
enum StatsPeriod: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case all

    var id: String { rawValue }

    /// The `p_days` argument passed to the RPCs (nil = all-time).
    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .all: return nil
        }
    }

    var label: String {
        switch self {
        case .week: return "7 days"
        case .month: return "30 days"
        case .all: return "All time"
        }
    }
}

/// Headline counters from `stats_overview`. `firstPlayedAt`/`lastPlayedAt` arrive as UTC
/// ISO-8601 strings (whole seconds) and are parsed lazily, like `PlayHistoryItem.playedAt`.
struct StatsOverview: Decodable, Equatable, Sendable {
    let totalPlays: Int
    let estListeningMs: Int
    let distinctTracks: Int
    let distinctArtists: Int
    let firstPlayedAt: String?
    let lastPlayedAt: String?

    enum CodingKeys: String, CodingKey {
        case totalPlays = "total_plays"
        case estListeningMs = "est_listening_ms"
        case distinctTracks = "distinct_tracks"
        case distinctArtists = "distinct_artists"
        case firstPlayedAt = "first_played_at"
        case lastPlayedAt = "last_played_at"
    }

    /// The zero state — used when the RPC returns no row (no plays collected yet).
    static let empty = StatsOverview(
        totalPlays: 0,
        estListeningMs: 0,
        distinctTracks: 0,
        distinctArtists: 0,
        firstPlayedAt: nil,
        lastPlayedAt: nil
    )

    var isEmpty: Bool { totalPlays == 0 }

    /// When collection started for this user (the earliest play we have).
    var firstPlayedDate: Date? {
        firstPlayedAt.flatMap(StatsDateParsing.timestamp(from:))
    }
}

/// One row from `stats_top_tracks`.
struct StatTrack: Decodable, Equatable, Sendable, Identifiable {
    let trackKey: String
    let trackName: String
    let artistNames: [String]
    let albumArtURL: String?
    let playCount: Int
    let estMs: Int

    var id: String { trackKey }
    var artistsDisplay: String { artistNames.joined(separator: ", ") }

    enum CodingKeys: String, CodingKey {
        case trackKey = "track_key"
        case trackName = "track_name"
        case artistNames = "artist_names"
        case albumArtURL = "album_art_url"
        case playCount = "play_count"
        case estMs = "est_ms"
    }
}

/// One row from `stats_top_albums`.
struct StatAlbum: Decodable, Equatable, Sendable, Identifiable {
    let albumKey: String
    let albumName: String
    let albumArtURL: String?
    let artistNames: [String]
    let playCount: Int
    let estMs: Int

    var id: String { albumKey }
    var artistsDisplay: String { artistNames.joined(separator: ", ") }

    enum CodingKeys: String, CodingKey {
        case albumKey = "album_key"
        case albumName = "album_name"
        case albumArtURL = "album_art_url"
        case artistNames = "artist_names"
        case playCount = "play_count"
        case estMs = "est_ms"
    }
}

/// One row from `stats_top_artists`.
struct StatArtist: Decodable, Equatable, Sendable, Identifiable {
    let artistName: String
    let playCount: Int

    var id: String { artistName }

    enum CodingKeys: String, CodingKey {
        case artistName = "artist_name"
        case playCount = "play_count"
    }
}

/// One day from `stats_daily`. `day` arrives as a `YYYY-MM-DD` string (UTC bucket).
struct StatDailyPoint: Decodable, Equatable, Sendable, Identifiable {
    let day: String
    let playCount: Int
    let estMs: Int

    var id: String { day }

    /// Parsed calendar date for charting; nil if the string is malformed (then the point is
    /// dropped from the chart rather than guessed).
    var date: Date? { StatsDateParsing.day(from: day) }

    enum CodingKeys: String, CodingKey {
        case day
        case playCount = "play_count"
        case estMs = "est_ms"
    }
}

/// Shared parsers for the string date/timestamp shapes our collected data returns. The `stats_*`
/// RPCs emit whole-second UTC strings; a raw `play_events` select returns full timestamptz with
/// fractional seconds, so we try the fractional formatter first, then whole seconds.
enum StatsDateParsing {
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func timestamp(from string: String) -> Date? {
        fractionalFormatter.date(from: string) ?? timestampFormatter.date(from: string)
    }

    static func day(from string: String) -> Date? {
        dayFormatter.date(from: string)
    }
}

/// One row from `stats_listening_clock`: a (weekday, hour) bucket with its play count.
/// weekday follows the PostgreSQL DOW convention: 0 = Sunday … 6 = Saturday.
/// hour is 0 … 23 (UTC).
struct HeatmapCell: Decodable, Equatable, Sendable {
    let weekday: Int
    let hour: Int
    let playCount: Int

    enum CodingKeys: String, CodingKey {
        case weekday
        case hour
        case playCount = "play_count"
    }
}

/// A normalised view of the `stats_listening_clock` RPC result, ready for the heatmap renderer.
/// All grid/intensity math lives here so it can be unit-tested independently of the view.
struct ListeningClock: Equatable, Sendable {
    private let cells: [HeatmapCell]

    /// The highest play count among all cells (0 when there are no cells).
    let maxCount: Int

    /// Sum of all play counts across every bucket.
    let totalPlays: Int

    init(cells: [HeatmapCell]) {
        self.cells = cells
        self.maxCount = cells.map(\.playCount).max() ?? 0
        self.totalPlays = cells.reduce(0) { $0 + $1.playCount }
    }

    var isEmpty: Bool { totalPlays == 0 }

    /// Relative intensity for the given cell, in 0 … 1.
    /// Returns 0 when there is no data or when the grid has no plays (avoids division by zero).
    func intensity(weekday: Int, hour: Int) -> Double {
        guard maxCount > 0 else { return 0 }
        let count = cells.first { $0.weekday == weekday && $0.hour == hour }?.playCount ?? 0
        return Double(count) / Double(maxCount)
    }
}

/// Listening-streak counters derived from the `stats_play_days` RPC.
struct ListeningStreaks: Equatable, Sendable {
    /// Number of consecutive calendar days (UTC) ending at today or yesterday.
    let current: Int
    /// Longest run of consecutive calendar days in the collected history.
    let longest: Int

    /// Zero state — returned when there is no play history or the input is empty.
    static let none = ListeningStreaks(current: 0, longest: 0)
}

/// Pure streak calculator. All logic lives here (not in the view) so it can be unit-tested
/// with a deterministic injected `today`.
enum StreakCalculator {
    // MARK: - Public API

    /// Compute `ListeningStreaks` from a list of `"yyyy-MM-dd"` UTC day strings and a reference
    /// date for "today". Unparseable strings and duplicates are silently ignored. Safe on empty
    /// input — returns `.none`.
    ///
    /// - Parameters:
    ///   - playDays: Raw day strings from the `stats_play_days` RPC (any order, may contain dupes).
    ///   - today: The calendar date to treat as "today" (UTC). Pass `Date()` from the call site;
    ///            injected here so tests are deterministic.
    static func streaks(playDays: [String], today: Date) -> ListeningStreaks {
        guard !playDays.isEmpty else { return .none }

        let todayNumber = utcDayNumber(for: today)
        let daySet = buildDaySet(from: playDays)
        guard !daySet.isEmpty else { return .none }

        let longest = longestRun(in: daySet)
        let current = currentStreak(in: daySet, todayNumber: todayNumber)

        return ListeningStreaks(current: current, longest: longest)
    }

    // MARK: - Private helpers

    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        if let utc = TimeZone(identifier: "UTC") {
            cal.timeZone = utc
        }
        return cal
    }()

    /// Reference epoch for day-number arithmetic: 2000-01-01 UTC (arbitrary, consistent).
    private static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        return utcCalendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }()

    /// Convert a `Date` to an integer day-number relative to `referenceDate` (UTC calendar days).
    private static func utcDayNumber(for date: Date) -> Int {
        utcCalendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
    }

    /// Parse day strings into a `Set<Int>` of day-numbers; bad strings are dropped silently.
    private static func buildDaySet(from playDays: [String]) -> Set<Int> {
        var result = Set<Int>()
        for string in playDays {
            if let date = StatsDateParsing.day(from: string) {
                result.insert(utcDayNumber(for: date))
            }
        }
        return result
    }

    /// Longest run of consecutive integers in `set`.
    private static func longestRun(in set: Set<Int>) -> Int {
        guard !set.isEmpty else { return 0 }
        let sorted = set.sorted()
        var best = 1
        var run = 1
        for index in 1..<sorted.count {
            if sorted[index] == sorted[index - 1] + 1 {
                run += 1
                if run > best { best = run }
            } else {
                run = 1
            }
        }
        return best
    }

    /// Current streak ending at today (or yesterday if today has no plays yet).
    private static func currentStreak(in set: Set<Int>, todayNumber: Int) -> Int {
        // Determine starting point: today if played today; yesterday if played yesterday; else 0.
        let startDay: Int
        if set.contains(todayNumber) {
            startDay = todayNumber
        } else if set.contains(todayNumber - 1) {
            startDay = todayNumber - 1
        } else {
            return 0
        }

        // Walk backward counting consecutive days.
        var count = 0
        var day = startDay
        while set.contains(day) {
            count += 1
            day -= 1
        }
        return count
    }
}

/// Everything one Stats screen render needs, loaded together.
struct StatsBundle: Equatable, Sendable {
    let overview: StatsOverview
    let topTracks: [StatTrack]
    let topAlbums: [StatAlbum]
    let topArtists: [StatArtist]
    let daily: [StatDailyPoint]
    let clock: ListeningClock
    let streaks: ListeningStreaks
}
