import Foundation
@testable import SpotiStats

/// A scriptable `SpotifyAPI` for view-model tests: set a `Result` per endpoint, and it records
/// which affinity windows were requested.
final class MockSpotifyAPI: SpotifyAPI {
    var topTracksResult: Result<[SpotifyTrack], Error> = .success([])
    var topArtistsResult: Result<[SpotifyArtist], Error> = .success([])
    var recentlyPlayedResult: Result<[PlayHistoryItem], Error> = .success([])

    private(set) var requestedTrackRanges: [SpotifyTimeRange] = []
    private(set) var requestedArtistRanges: [SpotifyTimeRange] = []
    private(set) var recentlyPlayedCallCount = 0

    func topTracks(range: SpotifyTimeRange, limit: Int) async throws -> [SpotifyTrack] {
        requestedTrackRanges.append(range)
        return try topTracksResult.get()
    }

    func topArtists(range: SpotifyTimeRange, limit: Int) async throws -> [SpotifyArtist] {
        requestedArtistRanges.append(range)
        return try topArtistsResult.get()
    }

    func recentlyPlayed(limit: Int) async throws -> [PlayHistoryItem] {
        recentlyPlayedCallCount += 1
        return try recentlyPlayedResult.get()
    }
}

/// Hand-built sample models for asserting against (decoding from JSON is covered elsewhere).
enum SampleModels {
    static let track = SpotifyTrack(
        id: "track1",
        name: "Sicko Mode",
        artists: [SpotifyArtistRef(id: "art1", name: "Travis Scott")],
        album: SpotifyAlbumRef(name: "ASTROWORLD", images: []),
        durationMs: 312_820,
        explicit: true
    )

    static let artist = SpotifyArtist(
        id: "art1",
        name: "Travis Scott",
        genres: ["rap", "hip hop"],
        popularity: 95,
        images: []
    )

    static let playHistoryItem = PlayHistoryItem(
        track: track,
        playedAt: "2026-06-06T10:00:00.000Z"
    )
}
