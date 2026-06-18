import XCTest
@testable import SpotiStats

/// Stats view-model behavior + the model parsing/formatting helpers.
final class StatsTests: XCTestCase {

    // MARK: View model

    @MainActor
    func testLoadSuccessAssemblesBundle() async {
        let provider = MockStatsProvider()
        provider.overviewResult = .success(StatsSamples.overview)
        provider.topTracksResult = .success([StatsSamples.track])
        provider.topArtistsResult = .success([StatsSamples.artist])
        provider.dailyResult = .success([StatsSamples.day])
        let viewModel = StatsViewModel()

        await viewModel.load(using: provider)

        guard case .loaded(let bundle) = viewModel.state else {
            return XCTFail("Expected .loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(bundle.overview.totalPlays, 42)
        XCTAssertEqual(bundle.topTracks, [StatsSamples.track])
        XCTAssertEqual(bundle.topArtists, [StatsSamples.artist])
        XCTAssertEqual(bundle.daily, [StatsSamples.day])
    }

    @MainActor
    func testDefaultPeriodIsMonthAndDrivesWindow() async {
        let provider = MockStatsProvider()
        let viewModel = StatsViewModel()

        XCTAssertEqual(viewModel.selectedPeriod, .month)
        await viewModel.load(using: provider)

        XCTAssertEqual(provider.requestedOverviewDays, [30])
        XCTAssertEqual(provider.requestedDailyDays, [30])
    }

    @MainActor
    func testAllTimePeriodPassesNilDaysButBoundedDailyWindow() async {
        let provider = MockStatsProvider()
        let viewModel = StatsViewModel()
        viewModel.selectedPeriod = .all

        await viewModel.load(using: provider)

        XCTAssertEqual(provider.requestedOverviewDays, [nil]) // all-time overview
        XCTAssertEqual(provider.requestedDailyDays, [30])     // trend stays bounded
    }

    @MainActor
    func testWeekPeriodUsesSevenDays() async {
        let provider = MockStatsProvider()
        let viewModel = StatsViewModel()
        viewModel.selectedPeriod = .week

        await viewModel.load(using: provider)

        XCTAssertEqual(provider.requestedOverviewDays, [7])
        XCTAssertEqual(provider.requestedDailyDays, [7])
    }

    @MainActor
    func testLoadFailureSurfacesFriendlyMessage() async {
        let provider = MockStatsProvider()
        provider.overviewResult = .failure(URLError(.notConnectedToInternet))
        let viewModel = StatsViewModel()

        await viewModel.load(using: provider)

        XCTAssertEqual(viewModel.state, .failed("You're offline. Check your connection and retry."))
    }

    @MainActor
    func testEmptyOverviewStaysLoadedSoTheViewCanShowGatheringState() async {
        let provider = MockStatsProvider()
        provider.overviewResult = .success(.empty)
        let viewModel = StatsViewModel()

        await viewModel.load(using: provider)

        guard case .loaded(let bundle) = viewModel.state else {
            return XCTFail("Expected .loaded, got \(viewModel.state)")
        }
        XCTAssertTrue(bundle.overview.isEmpty)
    }

    // MARK: Models

    func testListeningTimeFormatting() {
        XCTAssertEqual(StatsFormat.listeningTime(milliseconds: 9_000_000), "2h 30m")
        XCTAssertEqual(StatsFormat.listeningTime(milliseconds: 600_000), "10m")
        XCTAssertEqual(StatsFormat.listeningTime(milliseconds: 0), "0m")
        XCTAssertEqual(StatsFormat.listeningTime(milliseconds: -5), "0m") // never negative
        XCTAssertEqual(StatsFormat.listeningTime(milliseconds: 3_600_000), "1h 0m")
    }

    func testPeriodDaysMapping() {
        XCTAssertEqual(StatsPeriod.week.days, 7)
        XCTAssertEqual(StatsPeriod.month.days, 30)
        XCTAssertNil(StatsPeriod.all.days)
        XCTAssertEqual(StatsPeriod.allCases.count, 3)
    }

    func testDailyPointParsesDayString() {
        XCTAssertNotNil(StatsSamples.day.date)
        let malformed = StatDailyPoint(day: "not-a-date", playCount: 1, estMs: 0)
        XCTAssertNil(malformed.date)
    }

    func testOverviewParsesFirstPlayedTimestamp() {
        XCTAssertNotNil(StatsSamples.overview.firstPlayedDate)
        XCTAssertNil(StatsOverview.empty.firstPlayedDate)
    }

    func testOverviewDecodesFromRPCJSON() throws {
        // Mirrors a single-row `stats_overview` response (snake_case, string timestamps).
        let json = """
        {
          "total_plays": 42,
          "est_listening_ms": 9000000,
          "distinct_tracks": 30,
          "distinct_artists": 18,
          "first_played_at": "2026-06-10T12:00:00Z",
          "last_played_at": "2026-06-17T20:00:00Z"
        }
        """
        let overview = try JSONDecoder().decode(StatsOverview.self, from: Data(json.utf8))
        XCTAssertEqual(overview.totalPlays, 42)
        XCTAssertEqual(overview.distinctArtists, 18)
        XCTAssertNotNil(overview.firstPlayedDate)
    }

    func testTopTrackDecodesFromRPCJSON() throws {
        let json = """
        {
          "track_key": "track1",
          "track_name": "Nocturne",
          "artist_names": ["EDEN"],
          "album_art_url": "https://img/nocturne",
          "play_count": 7,
          "est_ms": 1400000
        }
        """
        let track = try JSONDecoder().decode(StatTrack.self, from: Data(json.utf8))
        XCTAssertEqual(track.trackName, "Nocturne")
        XCTAssertEqual(track.artistNames, ["EDEN"])
        XCTAssertEqual(track.playCount, 7)
    }

    func testCollectedPlayDecodesFromPlayEventsRow() throws {
        // Mirrors a raw play_events select (snake_case; timestamptz with fractional seconds).
        let json = """
        {
          "id": 1234,
          "played_at": "2026-06-17T20:00:00.123456+00:00",
          "track_name": "Nocturne",
          "artist_names": ["EDEN"],
          "album_name": "Vertigo",
          "album_art_url": "https://img/nocturne",
          "explicit": false
        }
        """
        let play = try JSONDecoder().decode(CollectedPlay.self, from: Data(json.utf8))
        XCTAssertEqual(play.id, 1234)
        XCTAssertEqual(play.trackName, "Nocturne")
        XCTAssertEqual(play.artistsDisplay, "EDEN")
        XCTAssertNotNil(play.playedAtDate) // fractional-second timestamp parses
    }

    func testCollectedPlayParsesWholeSecondTimestamp() {
        XCTAssertNotNil(StatsSamples.recentPlay.playedAtDate) // "...T20:00:00Z" (no fraction)
    }
}
