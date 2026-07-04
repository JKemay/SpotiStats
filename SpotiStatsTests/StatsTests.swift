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
        provider.topAlbumsResult = .success([StatsSamples.album])
        provider.topArtistsResult = .success([StatsSamples.artist])
        provider.dailyResult = .success([StatsSamples.day])
        provider.clockResult = .success(StatsSamples.heatmapCells)
        provider.playDaysResult = .success(StatsSamples.playDays)
        let viewModel = StatsViewModel()

        await viewModel.load(using: provider)

        guard case .loaded(let bundle) = viewModel.state else {
            return XCTFail("Expected .loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(bundle.overview.totalPlays, 42)
        XCTAssertEqual(bundle.topTracks, [StatsSamples.track])
        XCTAssertEqual(bundle.topAlbums, [StatsSamples.album])
        XCTAssertEqual(bundle.topArtists, [StatsSamples.artist])
        XCTAssertEqual(bundle.daily, [StatsSamples.day])
        XCTAssertEqual(bundle.clock, ListeningClock(cells: StatsSamples.heatmapCells))
        XCTAssertFalse(bundle.clock.isEmpty)
        // streaks field is present; longest is deterministically 3 from StatsSamples.playDays
        // (2026-06-15/16/17 form a 3-day run). current depends on real Date(), so we check longest.
        XCTAssertEqual(bundle.streaks.longest, 3)
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
        XCTAssertEqual(9_000_000.asListeningTime, "2h 30m")
        XCTAssertEqual(600_000.asListeningTime, "10 min")
        XCTAssertEqual(0.asListeningTime, "0s")
        XCTAssertEqual((-5).asListeningTime, "0s") // negative ms rounds to 0s
        XCTAssertEqual(3_600_000.asListeningTime, "1h")
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

    func testTopAlbumDecodesFromRPCJSON() throws {
        let json = """
        {
          "album_key": "Vertigo",
          "album_name": "Vertigo",
          "album_art_url": "https://img/vertigo",
          "artist_names": ["EDEN"],
          "play_count": 5,
          "est_ms": 1000000
        }
        """
        let album = try JSONDecoder().decode(StatAlbum.self, from: Data(json.utf8))
        XCTAssertEqual(album.albumName, "Vertigo")
        XCTAssertEqual(album.artistNames, ["EDEN"])
        XCTAssertEqual(album.playCount, 5)
        XCTAssertEqual(album.artistsDisplay, "EDEN")
    }

    func testTopArtistDecodesFromRPCJSON() throws {
        let json = """
        {
          "artist_name": "EDEN",
          "play_count": 12
        }
        """
        let artist = try JSONDecoder().decode(StatArtist.self, from: Data(json.utf8))
        XCTAssertEqual(artist.artistName, "EDEN")
        XCTAssertEqual(artist.playCount, 12)
        XCTAssertEqual(artist.id, "EDEN")
    }

    func testDailyPointDecodesFromRPCJSON() throws {
        let json = """
        {
          "day": "2026-06-17",
          "play_count": 9,
          "est_ms": 1800000
        }
        """
        let point = try JSONDecoder().decode(StatDailyPoint.self, from: Data(json.utf8))
        XCTAssertEqual(point.playCount, 9)
        XCTAssertEqual(point.estMs, 1_800_000)
        XCTAssertNotNil(point.date)
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

    // MARK: ListeningClock

    func testListeningClockIntensityNormalization() {
        // heatmapCells: max is weekday 1 / hour 9 with count 10.
        let clock = ListeningClock(cells: StatsSamples.heatmapCells)

        // Max cell is exactly 1.0.
        XCTAssertEqual(clock.intensity(weekday: 1, hour: 9), 1.0, accuracy: 0.001)

        // Smaller cell is a correct fraction: 5 / 10 = 0.5.
        XCTAssertEqual(clock.intensity(weekday: 1, hour: 10), 0.5, accuracy: 0.001)

        // Absent cell is 0.
        XCTAssertEqual(clock.intensity(weekday: 0, hour: 0), 0.0, accuracy: 0.001)

        // Summary counters.
        XCTAssertEqual(clock.maxCount, 10)
        XCTAssertEqual(clock.totalPlays, 18)
        XCTAssertFalse(clock.isEmpty)
    }

    func testListeningClockEmptyStateNeverDividesByZero() {
        let empty = ListeningClock(cells: [])
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.maxCount, 0)
        XCTAssertEqual(empty.totalPlays, 0)
        // Must not crash or return NaN.
        XCTAssertEqual(empty.intensity(weekday: 0, hour: 0), 0.0, accuracy: 0.001)
        XCTAssertEqual(empty.intensity(weekday: 6, hour: 23), 0.0, accuracy: 0.001)
    }

    func testHeatmapCellDecodesFromRPCJSON() throws {
        let json = """
        {
          "weekday": 3,
          "hour": 14,
          "play_count": 7
        }
        """
        let cell = try JSONDecoder().decode(HeatmapCell.self, from: Data(json.utf8))
        XCTAssertEqual(cell.weekday, 3)
        XCTAssertEqual(cell.hour, 14)
        XCTAssertEqual(cell.playCount, 7)
    }
}
