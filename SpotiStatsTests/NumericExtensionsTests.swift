import XCTest
@testable import SpotiStats

final class NumericExtensionsTests: XCTestCase {

    // MARK: - BinaryInteger compactFormatted

    func testCompactFormatted_belowThreshold() {
        XCTAssertEqual(0.compactFormatted, "0")
        XCTAssertEqual(42.compactFormatted, "42")
        XCTAssertEqual(999.compactFormatted, "999")
    }

    func testCompactFormatted_thousands() {
        XCTAssertEqual(1_000.compactFormatted, "1K")
        XCTAssertEqual(1_200.compactFormatted, "1.2K")
        XCTAssertEqual(15_300.compactFormatted, "15.3K")
        XCTAssertEqual(999_900.compactFormatted, "999.9K")
    }

    func testCompactFormatted_millions() {
        XCTAssertEqual(1_000_000.compactFormatted, "1M")
        XCTAssertEqual(2_500_000.compactFormatted, "2.5M")
        XCTAssertEqual(123_400_000.compactFormatted, "123.4M")
    }

    func testCompactFormatted_billions() {
        XCTAssertEqual(1_000_000_000.compactFormatted, "1B")
        XCTAssertEqual(7_800_000_000.compactFormatted, "7.8B")
    }

    // MARK: - Double compactFormatted

    func testDoubleCompactFormatted() {
        XCTAssertEqual(Double(500).compactFormatted, "500")
        XCTAssertEqual(Double(1_500).compactFormatted, "1.5K")
        XCTAssertEqual(Double(2_000_000).compactFormatted, "2M")
    }

    // MARK: - percentFormatted

    func testPercentFormatted_wholeNumber() {
        XCTAssertEqual(Double(1.0).percentFormatted, "100%")
        XCTAssertEqual(Double(0.5).percentFormatted, "50%")
        XCTAssertEqual(Double(0.0).percentFormatted, "0%")
    }

    func testPercentFormatted_withDecimal() {
        XCTAssertEqual(Double(0.753).percentFormatted, "75.3%")
        XCTAssertEqual(Double(0.126).percentFormatted, "12.6%")
    }

    // MARK: - signedString (BinaryInteger)

    func testIntSignedString_positive() {
        XCTAssertEqual(5.signedString, "+5")
        XCTAssertEqual(100.signedString, "+100")
    }

    func testIntSignedString_negative() {
        XCTAssertEqual((-3).signedString, "-3")
    }

    func testIntSignedString_zero() {
        XCTAssertEqual(0.signedString, "0")
    }

    // MARK: - signedString (Double)

    func testDoubleSignedString() {
        XCTAssertEqual(Double(5.2).signedString, "+5.2")
        XCTAssertEqual(Double(-3.0).signedString, "-3.0")
        XCTAssertEqual(Double(0.0).signedString, "0")
    }

    // MARK: - changePercentFormatted

    func testChangePercentFormatted_positive() {
        XCTAssertEqual(Double(0.15).changePercentFormatted, "+15%")
    }

    func testChangePercentFormatted_negative() {
        XCTAssertEqual(Double(-0.08).changePercentFormatted, "-8%")
    }

    func testChangePercentFormatted_zero() {
        XCTAssertEqual(Double(0.0).changePercentFormatted, "0%")
    }

    // MARK: - ordinal

    func testOrdinal_basics() {
        XCTAssertEqual(1.ordinal, "1st")
        XCTAssertEqual(2.ordinal, "2nd")
        XCTAssertEqual(3.ordinal, "3rd")
        XCTAssertEqual(4.ordinal, "4th")
    }

    func testOrdinal_teens() {
        XCTAssertEqual(11.ordinal, "11th")
        XCTAssertEqual(12.ordinal, "12th")
        XCTAssertEqual(13.ordinal, "13th")
    }

    func testOrdinal_largerNumbers() {
        XCTAssertEqual(21.ordinal, "21st")
        XCTAssertEqual(22.ordinal, "22nd")
        XCTAssertEqual(103.ordinal, "103rd")
        XCTAssertEqual(111.ordinal, "111th")
    }

    // MARK: - clamped

    func testClamped_withinRange() {
        XCTAssertEqual(5.clamped(to: 0...10), 5)
    }

    func testClamped_belowRange() {
        XCTAssertEqual((-5).clamped(to: 0...10), 0)
    }

    func testClamped_aboveRange() {
        XCTAssertEqual(15.clamped(to: 0...10), 10)
    }

    func testClamped_double() {
        XCTAssertEqual(0.5.clamped(to: 0.0...1.0), 0.5)
        XCTAssertEqual((-0.1).clamped(to: 0.0...1.0), 0.0)
        XCTAssertEqual(1.5.clamped(to: 0.0...1.0), 1.0)
    }
}
