import Foundation
@testable import SpotiStats

/// A scriptable `StatsProviding` for view-model tests: set a `Result` per RPC, and it records
/// the `days` window each call requested.
final class MockStatsProvider: StatsProviding {
    var overviewResult: Result<StatsOverview, Error> = .success(.empty)
    var topTracksResult: Result<[StatTrack], Error> = .success([])
    var topArtistsResult: Result<[StatArtist], Error> = .success([])
    var dailyResult: Result<[StatDailyPoint], Error> = .success([])
    var recentPlaysResult: Result<[CollectedPlay], Error> = .success([])

    private(set) var requestedOverviewDays: [Int?] = []
    private(set) var requestedDailyDays: [Int] = []
    private(set) var requestedTopTrackDays: [Int?] = []
    private(set) var requestedRecentLimits: [Int] = []

    func overview(days: Int?) async throws -> StatsOverview {
        requestedOverviewDays.append(days)
        return try overviewResult.get()
    }

    func topTracks(days: Int?, limit: Int) async throws -> [StatTrack] {
        requestedTopTrackDays.append(days)
        return try topTracksResult.get()
    }

    func topArtists(days: Int?, limit: Int) async throws -> [StatArtist] {
        try topArtistsResult.get()
    }

    func daily(days: Int) async throws -> [StatDailyPoint] {
        requestedDailyDays.append(days)
        return try dailyResult.get()
    }

    func recentPlays(limit: Int) async throws -> [CollectedPlay] {
        requestedRecentLimits.append(limit)
        return try recentPlaysResult.get()
    }
}

enum StatsSamples {
    static let overview = StatsOverview(
        totalPlays: 42,
        estListeningMs: 9_000_000, // 2h 30m
        distinctTracks: 30,
        distinctArtists: 18,
        firstPlayedAt: "2026-06-10T12:00:00Z",
        lastPlayedAt: "2026-06-17T20:00:00Z"
    )

    static let track = StatTrack(
        trackKey: "track1",
        trackName: "Nocturne",
        artistNames: ["EDEN"],
        albumArtURL: "https://img/nocturne",
        playCount: 7,
        estMs: 1_400_000
    )

    static let artist = StatArtist(artistName: "EDEN", playCount: 12)

    static let day = StatDailyPoint(day: "2026-06-17", playCount: 9, estMs: 1_800_000)

    static let recentPlay = CollectedPlay(
        id: 1,
        playedAt: "2026-06-17T20:00:00Z",
        trackName: "Nocturne",
        artistNames: ["EDEN"],
        albumName: "Vertigo",
        albumArtURL: "https://img/nocturne",
        explicit: false
    )
}
