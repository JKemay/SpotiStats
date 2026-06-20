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

/// Everything one Stats screen render needs, loaded together.
struct StatsBundle: Equatable, Sendable {
    let overview: StatsOverview
    let topTracks: [StatTrack]
    let topArtists: [StatArtist]
    let daily: [StatDailyPoint]
}
