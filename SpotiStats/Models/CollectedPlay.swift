import Foundation

/// One play from our own `play_events` history (the collector's record), as read directly via
/// PostgREST. Unlike Spotify's recently-played (its ephemeral last 50), this is unbounded and
/// grows forever — it's what powers the Home dashboard's recent feed.
///
/// `playedAt` arrives as an ISO-8601 timestamp string and is parsed lazily (the row's `id` gives
/// a stable identity for SwiftUI lists).
struct CollectedPlay: Decodable, Equatable, Sendable, Identifiable {
    let id: Int
    let playedAt: String
    let trackName: String
    let artistNames: [String]
    let albumName: String?
    let albumArtURL: String?
    let explicit: Bool

    var artistsDisplay: String { artistNames.joined(separator: ", ") }
    var playedAtDate: Date? { StatsDateParsing.timestamp(from: playedAt) }

    enum CodingKeys: String, CodingKey {
        case id
        case playedAt = "played_at"
        case trackName = "track_name"
        case artistNames = "artist_names"
        case albumName = "album_name"
        case albumArtURL = "album_art_url"
        case explicit
    }
}
