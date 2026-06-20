import XCTest
@testable import SpotiStats

/// Unit tests for `WeeklyShareData.from(bundle:period:)`.
/// All cases use value-type construction (no async, no mocks needed).
final class WeeklyShareDataTests: XCTestCase {

    // MARK: - Helpers

    /// A fully-populated `StatsBundle` using `StatsSamples` fixtures.
    private var populatedBundle: StatsBundle {
        StatsBundle(
            overview: StatsSamples.overview,        // 42 plays, 9_000_000 ms
            topTracks: [StatsSamples.track],        // "Nocturne" by "EDEN"
            topAlbums: [StatsSamples.album],
            topArtists: [StatsSamples.artist],      // "EDEN"
            daily: [StatsSamples.day],
            clock: ListeningClock(cells: StatsSamples.heatmapCells),
            streaks: ListeningStreaks(current: 3, longest: 3)
        )
    }

    /// A `StatsBundle` with no top tracks, no top artists, and a zero streak.
    private var emptyBundle: StatsBundle {
        StatsBundle(
            overview: StatsOverview.empty,
            topTracks: [],
            topAlbums: [],
            topArtists: [],
            daily: [],
            clock: ListeningClock(cells: []),
            streaks: .none
        )
    }

    // MARK: - Populated bundle tests

    func testListeningTimeMapsCorrectly() {
        let result = WeeklyShareData.from(bundle: populatedBundle, period: .week)
        // 9_000_000 ms = 2h 30m
        XCTAssertEqual(result.listeningTime, "2h 30m")
    }

    func testPlaysMapsCorrectly() {
        let result = WeeklyShareData.from(bundle: populatedBundle, period: .week)
        XCTAssertEqual(result.plays, 42)
    }

    func testTopTrackNameMapsCorrectly() {
        let result = WeeklyShareData.from(bundle: populatedBundle, period: .week)
        XCTAssertEqual(result.topTrackName, "Nocturne")
    }

    func testTopTrackArtistMapsCorrectly() {
        let result = WeeklyShareData.from(bundle: populatedBundle, period: .week)
        XCTAssertEqual(result.topTrackArtist, "EDEN")
    }

    func testTopArtistNameMapsCorrectly() {
        let result = WeeklyShareData.from(bundle: populatedBundle, period: .week)
        XCTAssertEqual(result.topArtistName, "EDEN")
    }

    func testCurrentStreakMapsCorrectly() {
        let result = WeeklyShareData.from(bundle: populatedBundle, period: .week)
        XCTAssertEqual(result.currentStreak, 3)
    }

    // MARK: - Period label tests

    func testPeriodLabelWeek() {
        let result = WeeklyShareData.from(bundle: populatedBundle, period: .week)
        XCTAssertEqual(result.periodLabel, "Last 7 days")
    }

    func testPeriodLabelMonth() {
        let result = WeeklyShareData.from(bundle: populatedBundle, period: .month)
        XCTAssertEqual(result.periodLabel, "Last 30 days")
    }

    func testPeriodLabelAll() {
        let result = WeeklyShareData.from(bundle: populatedBundle, period: .all)
        XCTAssertEqual(result.periodLabel, "All time")
    }

    // MARK: - Empty bundle tests

    func testEmptyBundleTopTrackIsNil() {
        let result = WeeklyShareData.from(bundle: emptyBundle, period: .week)
        XCTAssertNil(result.topTrackName)
        XCTAssertNil(result.topTrackArtist)
    }

    func testEmptyBundleTopArtistIsNil() {
        let result = WeeklyShareData.from(bundle: emptyBundle, period: .week)
        XCTAssertNil(result.topArtistName)
    }

    func testEmptyBundleStreakIsZero() {
        let result = WeeklyShareData.from(bundle: emptyBundle, period: .week)
        XCTAssertEqual(result.currentStreak, 0)
    }

    func testEmptyBundleListeningTimeIsZeroSeconds() {
        let result = WeeklyShareData.from(bundle: emptyBundle, period: .week)
        XCTAssertEqual(result.listeningTime, "0s")
    }

    func testEmptyBundlePlaysIsZero() {
        let result = WeeklyShareData.from(bundle: emptyBundle, period: .week)
        XCTAssertEqual(result.plays, 0)
    }

    // MARK: - Equatable conformance

    func testEquatableSameData() {
        let lhs = WeeklyShareData.from(bundle: populatedBundle, period: .week)
        let rhs = WeeklyShareData.from(bundle: populatedBundle, period: .week)
        XCTAssertEqual(lhs, rhs)
    }

    func testEquatableDifferentPeriod() {
        let weekData = WeeklyShareData.from(bundle: populatedBundle, period: .week)
        let monthData = WeeklyShareData.from(bundle: populatedBundle, period: .month)
        XCTAssertNotEqual(weekData, monthData)
    }

    // MARK: - Multi-artist track display

    func testTopTrackArtistJoinsMultipleArtists() {
        let multiArtistTrack = StatTrack(
            trackKey: "collab",
            trackName: "Collab Track",
            artistNames: ["Artist A", "Artist B"],
            albumArtURL: nil,
            playCount: 10,
            estMs: 200_000
        )
        let bundle = StatsBundle(
            overview: StatsSamples.overview,
            topTracks: [multiArtistTrack],
            topAlbums: [],
            topArtists: [],
            daily: [],
            clock: ListeningClock(cells: []),
            streaks: .none
        )
        let result = WeeklyShareData.from(bundle: bundle, period: .week)
        XCTAssertEqual(result.topTrackArtist, "Artist A, Artist B")
    }
}
