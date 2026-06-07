import Foundation

// MARK: - Time range
//
// Spotify's "top items" endpoints only support three fixed affinity windows. These are NOT
// arbitrary date ranges, and `longTerm` is deliberately NOT "all time" — it's calculated from
// several years of data with recent activity weighted more heavily. We label them honestly in the
// UI (see `honestLabel`) so we never overclaim what the data means.

/// One of Spotify's three top-items affinity windows.
enum SpotifyTimeRange: String, CaseIterable, Sendable {
    case shortTerm = "short_term"
    case mediumTerm = "medium_term"
    case longTerm = "long_term"

    /// The exact value Spotify expects in the `time_range` query parameter.
    var queryValue: String { rawValue }

    /// A short, honest label for the UI. Avoids calling the long window "all time".
    var honestLabel: String {
        switch self {
        case .shortTerm: return "Last 4 weeks"
        case .mediumTerm: return "Last 6 months"
        case .longTerm: return "Several years"
        }
    }
}

// MARK: - Shared value types

/// An image (album art or artist photo). `height`/`width` can be null in Spotify responses.
struct SpotifyImage: Decodable, Equatable, Sendable {
    let url: String
    let height: Int?
    let width: Int?
}

/// A minimal artist reference as embedded inside a track.
struct SpotifyArtistRef: Decodable, Equatable, Sendable {
    let id: String?
    let name: String
}

/// An album reference embedded inside a track (we only need the name and artwork).
struct SpotifyAlbumRef: Decodable, Equatable, Sendable {
    let name: String
    let images: [SpotifyImage]
}

// MARK: - Tracks

/// A track. `id` is optional because user-local tracks have no Spotify catalog id.
///
/// Note: not `Identifiable` on purpose — a nil `id` (local tracks) would collide in a SwiftUI
/// `ForEach`. Views should choose an explicit identity (e.g. enumerated offset) where needed.
struct SpotifyTrack: Decodable, Equatable, Sendable {
    let id: String?
    let name: String
    let artists: [SpotifyArtistRef]
    let album: SpotifyAlbumRef
    let durationMs: Int
    let explicit: Bool

    /// Comma-joined artist names, convenient for display.
    var artistNames: String {
        artists.map(\.name).joined(separator: ", ")
    }
}

// MARK: - Artists

/// A full artist object (from the top-artists endpoint).
struct SpotifyArtist: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let genres: [String]
    let popularity: Int?
    let images: [SpotifyImage]
}

// MARK: - Response envelopes

/// Spotify wraps list endpoints in a paging object; for v1 we only need `items`.
struct SpotifyPage<Item: Decodable>: Decodable {
    let items: [Item]
}

/// One entry from the recently-played endpoint: the track plus when it was played.
///
/// `playedAt` is kept as the raw ISO-8601 string here; it's parsed into a `Date` later, in the
/// Phase 2 collector, where the exact timestamp matters for de-duplication.
struct PlayHistoryItem: Decodable, Equatable, Sendable {
    let track: SpotifyTrack
    let playedAt: String
}

/// The recently-played response envelope.
struct RecentlyPlayedResponse: Decodable {
    let items: [PlayHistoryItem]
}
