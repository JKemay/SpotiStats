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

extension [SpotifyImage] {
    /// The smallest image, for row-sized thumbnails. Spotify returns images largest-first, but we
    /// sort by area instead of trusting the order (and ignore entries with missing dimensions
    /// unless they're all we have).
    var thumbnailURL: URL? {
        let sized = filter { $0.width != nil && $0.height != nil }
        let smallest = sized.min { lhs, rhs in
            (lhs.width ?? 0) * (lhs.height ?? 0) < (rhs.width ?? 0) * (rhs.height ?? 0)
        }
        guard let candidate = smallest ?? first else { return nil }
        return URL(string: candidate.url)
    }
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
///
/// Spotify's docs say `genres` is always present, but live responses omit it for some artists
/// (verified 2026-06-10 against `/me/top/artists`), so it and `images` decode with empty
/// defaults instead of failing the whole page.
struct SpotifyArtist: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let genres: [String]
    let popularity: Int?
    let images: [SpotifyImage]

    init(id: String, name: String, genres: [String], popularity: Int?, images: [SpotifyImage]) {
        self.id = id
        self.name = name
        self.genres = genres
        self.popularity = popularity
        self.images = images
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        genres = try container.decodeIfPresent([String].self, forKey: .genres) ?? []
        popularity = try container.decodeIfPresent(Int.self, forKey: .popularity)
        images = try container.decodeIfPresent([SpotifyImage].self, forKey: .images) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, genres, popularity, images
    }
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

    /// A best-effort parse of `playedAt` for display ("2 hours ago"). Returns nil rather than
    /// guessing if the format is unexpected — the UI simply omits the timestamp then.
    var playedAtDate: Date? {
        Self.fractionalSecondsFormatter.date(from: playedAt)
            ?? Self.wholeSecondsFormatter.date(from: playedAt)
    }

    // ISO8601DateFormatter is thread-safe and expensive to build, so share static instances.
    // Spotify usually includes fractional seconds, but we accept whole seconds too.
    private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let wholeSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

/// The recently-played response envelope.
struct RecentlyPlayedResponse: Decodable {
    let items: [PlayHistoryItem]
}
