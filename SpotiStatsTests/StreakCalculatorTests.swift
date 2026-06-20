import XCTest
@testable import SpotiStats

/// Deterministic unit tests for `StreakCalculator`. All tests inject a fixed `today` date built
/// from calendar components (no force-unwrap; uses `XCTUnwrap`).
final class StreakCalculatorTests: XCTestCase {

    // MARK: - Helpers

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        if let utc = TimeZone(identifier: "UTC") {
            cal.timeZone = utc
        }
        return cal
    }

    /// Build a `Date` from year/month/day components in UTC. Fails the test if components are invalid.
    private func utcDate(year: Int, month: Int, day: Int) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return try XCTUnwrap(
            utcCalendar.date(from: components),
            "Could not build date \(year)-\(month)-\(day)"
        )
    }

    // MARK: - Empty / degenerate input

    func testEmptyInputReturnsNone() throws {
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(playDays: [], today: today)
        XCTAssertEqual(result, .none)
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.longest, 0)
    }

    func testAllUnparseableStringsReturnNone() throws {
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(playDays: ["not-a-date", "20260620", "hello"], today: today)
        XCTAssertEqual(result, .none)
    }

    func testDuplicateDaysDeduped() throws {
        // Three copies of the same day; longest should be 1, not 3.
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(
            playDays: ["2026-06-18", "2026-06-18", "2026-06-18"],
            today: today
        )
        XCTAssertEqual(result.longest, 1)
    }

    // MARK: - Current streak: ending today

    func testThreeDayRunEndingTodayCurrentIsThree() throws {
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(
            playDays: ["2026-06-20", "2026-06-19", "2026-06-18"],
            today: today
        )
        XCTAssertEqual(result.current, 3)
        XCTAssertEqual(result.longest, 3)
    }

    func testSingleDayTodayCurrentIsOne() throws {
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(playDays: ["2026-06-20"], today: today)
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.longest, 1)
    }

    // MARK: - Current streak: ending yesterday (streak stays "current")

    func testThreeDayRunEndingYesterdayCurrentIsThree() throws {
        // today = 2026-06-20; latest play = 2026-06-19 (yesterday) — streak is still current.
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(
            playDays: ["2026-06-19", "2026-06-18", "2026-06-17"],
            today: today
        )
        XCTAssertEqual(result.current, 3)
        XCTAssertEqual(result.longest, 3)
    }

    func testSingleDayYesterdayCurrentIsOne() throws {
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(playDays: ["2026-06-19"], today: today)
        XCTAssertEqual(result.current, 1)
    }

    // MARK: - Gap breaks current streak

    func testGapBeforeTodayBreaksCurrentToZero() throws {
        // today = 2026-06-20; last play was 2026-06-18 (2 days ago) — gap breaks current.
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(
            playDays: ["2026-06-18", "2026-06-17", "2026-06-16"],
            today: today
        )
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.longest, 3)
    }

    func testGapInsideRunCurrentPicksShortestTail() throws {
        // 2026-06-20 (today), 2026-06-19 present, gap, then 2026-06-15/14/13.
        // current = 2 (20, 19); longest = 3 (15, 14, 13).
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(
            playDays: ["2026-06-20", "2026-06-19", "2026-06-15", "2026-06-14", "2026-06-13"],
            today: today
        )
        XCTAssertEqual(result.current, 2)
        XCTAssertEqual(result.longest, 3)
    }

    // MARK: - Longest picks the winner when it's NOT the current run

    func testLongestPicksNonCurrentRun() throws {
        // today = 2026-06-20; current streak: just today (1 day).
        // Longest historical run: 2026-06-10, 2026-06-09, 2026-06-08, 2026-06-07 (4 days).
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(
            playDays: ["2026-06-20", "2026-06-10", "2026-06-09", "2026-06-08", "2026-06-07"],
            today: today
        )
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.longest, 4)
    }

    // MARK: - StatsSamples deterministic case

    func testStatsSamplePlayDaysLongestIsThree() throws {
        // StatsSamples.playDays = 2026-06-17, 2026-06-16, 2026-06-15, 2026-06-10.
        // Longest run: 15, 16, 17 = 3. Current depends on today; use a day where it's 0.
        let today = try utcDate(year: 2026, month: 6, day: 20) // 2026-06-18 is missing → gap → current 0
        let result = StreakCalculator.streaks(playDays: StatsSamples.playDays, today: today)
        XCTAssertEqual(result.longest, 3)
        XCTAssertEqual(result.current, 0)
    }

    func testStatsSamplePlayDaysCurrentWhenTodayIsWithinRun() throws {
        // If "today" is 2026-06-17, the run 15/16/17 ends today → current = 3.
        let today = try utcDate(year: 2026, month: 6, day: 17)
        let result = StreakCalculator.streaks(playDays: StatsSamples.playDays, today: today)
        XCTAssertEqual(result.current, 3)
        XCTAssertEqual(result.longest, 3)
    }

    func testStatsSamplePlayDaysCurrentWhenYesterdayIsEndOfRun() throws {
        // If "today" is 2026-06-18, yesterday = 2026-06-17 is the tip of the run → current = 3.
        let today = try utcDate(year: 2026, month: 6, day: 18)
        let result = StreakCalculator.streaks(playDays: StatsSamples.playDays, today: today)
        XCTAssertEqual(result.current, 3)
        XCTAssertEqual(result.longest, 3)
    }

    // MARK: - Mixed parseable + unparseable

    func testMixedParseableAndUnparseableDropsBadEntries() throws {
        let today = try utcDate(year: 2026, month: 6, day: 20)
        let result = StreakCalculator.streaks(
            playDays: ["2026-06-20", "GARBAGE", "2026-06-19", "", "2026-06-18"],
            today: today
        )
        XCTAssertEqual(result.current, 3)
        XCTAssertEqual(result.longest, 3)
    }
}
