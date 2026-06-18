import XCTest
@testable import SpotiStats

final class DurationFormattingTests: XCTestCase {

    // MARK: - asTrackLength

    func testTrackLength_zeroMs() {
        XCTAssertEqual(0.asTrackLength, "0:00")
    }

    func testTrackLength_underOneMinute() {
        // 42 seconds = 42_000 ms
        XCTAssertEqual(42_000.asTrackLength, "0:42")
    }

    func testTrackLength_exactMinute() {
        // 3 minutes = 180_000 ms
        XCTAssertEqual(180_000.asTrackLength, "3:00")
    }

    func testTrackLength_typicalSong() {
        // 3:42 = 222_000 ms
        XCTAssertEqual(222_000.asTrackLength, "3:42")
    }

    func testTrackLength_longSong() {
        // 8:05 = 485_000 ms
        XCTAssertEqual(485_000.asTrackLength, "8:05")
    }

    func testTrackLength_padsSingleDigitSeconds() {
        // 1:03 = 63_000 ms — seconds should be zero-padded
        XCTAssertEqual(63_000.asTrackLength, "1:03")
    }

    // MARK: - asListeningTime

    func testListeningTime_seconds() {
        // 42 seconds
        XCTAssertEqual(42_000.asListeningTime, "42s")
    }

    func testListeningTime_minutes() {
        // 23 minutes = 1_380_000 ms
        XCTAssertEqual(1_380_000.asListeningTime, "23 min")
    }

    func testListeningTime_hoursAndMinutes() {
        // 4h 12m = 15_120_000 ms
        XCTAssertEqual(15_120_000.asListeningTime, "4h 12m")
    }

    func testListeningTime_exactHours() {
        // 2h = 7_200_000 ms
        XCTAssertEqual(7_200_000.asListeningTime, "2h")
    }

    func testListeningTime_daysAndHours() {
        // 2d 5h = 53h = 190_800_000 ms
        XCTAssertEqual(190_800_000.asListeningTime, "2d 5h")
    }

    func testListeningTime_exactDays() {
        // 1d = 24h = 86_400_000 ms
        XCTAssertEqual(86_400_000.asListeningTime, "1d")
    }

    // MARK: - Date extensions

    func testShortDateLabel_format() {
        // Create a known date: June 18, 2026
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 18
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.shortDateLabel, "Jun 18")
    }

    func testIsoDateString_format() {
        // The ISO date string should match YYYY-MM-DD
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 5
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.isoDateString, "2026-01-05")
    }
}
