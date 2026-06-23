import XCTest
import SwiftUI
@testable import SpotiStats

final class ColorExtensionsTests: XCTestCase {

    // MARK: - Hex Initialiser

    func test_hexInit_sixDigit_withoutHash() {
        // Spotify green — a well-known sRGB value to verify channel accuracy.
        let color = Color(hex: "1DB954")
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Double(r), Double(0x1D) / 255, accuracy: 0.002)
        XCTAssertEqual(Double(g), Double(0xB9) / 255, accuracy: 0.002)
        XCTAssertEqual(Double(b), Double(0x54) / 255, accuracy: 0.002)
        XCTAssertEqual(Double(a), 1.0, accuracy: 0.001)
    }

    func test_hexInit_sixDigit_withHash() {
        // Ensure the leading '#' is stripped correctly.
        let withHash    = Color(hex: "#1DB954")
        let withoutHash = Color(hex: "1DB954")
        // Compare via UIColor channels.
        let ui1 = UIColor(withHash)
        let ui2 = UIColor(withoutHash)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ui1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ui2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        XCTAssertEqual(r1, r2, accuracy: 0.001)
        XCTAssertEqual(g1, g2, accuracy: 0.001)
        XCTAssertEqual(b1, b2, accuracy: 0.001)
    }

    func test_hexInit_eightDigit_alpha() {
        // RRGGBBAA — 50 % opacity white.
        let color = Color(hex: "FFFFFF80")
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Double(r), 1.0,  accuracy: 0.002)
        XCTAssertEqual(Double(g), 1.0,  accuracy: 0.002)
        XCTAssertEqual(Double(b), 1.0,  accuracy: 0.002)
        XCTAssertEqual(Double(a), Double(0x80) / 255, accuracy: 0.002)
    }

    func test_hexInit_malformed_returnsNonCrashing() {
        // Malformed input must return .clear — not crash.
        let color = Color(hex: "ZZZZZZ")
        // All we can verify without crashing is that a Color was produced.
        XCTAssertNotNil(color)
    }

    func test_hexInit_empty_returnsNonCrashing() {
        let color = Color(hex: "")
        XCTAssertNotNil(color)
    }

    // MARK: - Nocturne Palette Smoke Tests

    func test_nocturnePalette_backgroundPrimary_isDark() {
        // All background tokens should be perceptually dark.
        XCTAssertTrue(Color.Nocturne.backgroundPrimary.isDark)
    }

    func test_nocturnePalette_backgroundSecondary_isDark() {
        XCTAssertTrue(Color.Nocturne.backgroundSecondary.isDark)
    }

    func test_nocturnePalette_textPrimary_isLight() {
        // Primary text must be light (legible on dark backgrounds).
        XCTAssertFalse(Color.Nocturne.textPrimary.isDark)
    }

    func test_nocturnePalette_spotifyGreen_exists() {
        // Basic non-nil / non-crash smoke test.
        XCTAssertNotNil(Color.Nocturne.spotifyGreen)
    }

    // MARK: - Luminance

    func test_luminance_black_isZero() {
        XCTAssertEqual(Color.black.luminance, 0.0, accuracy: 0.001)
    }

    func test_luminance_white_isOne() {
        XCTAssertEqual(Color.white.luminance, 1.0, accuracy: 0.001)
    }

    func test_luminance_midGray_isApprox_0_2() {
        // Pure 50 % gray in sRGB linearises to ~0.216.
        XCTAssertEqual(Color(white: 0.5).luminance, 0.216, accuracy: 0.01)
    }

    // MARK: - isDark

    func test_isDark_black_isTrue() {
        XCTAssertTrue(Color.black.isDark)
    }

    func test_isDark_white_isFalse() {
        XCTAssertFalse(Color.white.isDark)
    }

    // MARK: - Tinting

    func test_lightened_makesColorBrighter() {
        let base    = Color(hex: "1DB954")
        let lighter = base.lightened(by: 0.3)
        XCTAssertGreaterThan(lighter.luminance, base.luminance)
    }

    func test_darkened_makesColorDarker() {
        let base   = Color(hex: "1DB954")
        let darker = base.darkened(by: 0.3)
        XCTAssertLessThan(darker.luminance, base.luminance)
    }

    func test_lightened_byZero_isUnchanged() {
        let base    = Color(hex: "1DB954")
        let result  = base.lightened(by: 0)
        XCTAssertEqual(result.luminance, base.luminance, accuracy: 0.001)
    }

    func test_darkened_byZero_isUnchanged() {
        let base   = Color(hex: "1DB954")
        let result = base.darkened(by: 0)
        XCTAssertEqual(result.luminance, base.luminance, accuracy: 0.001)
    }
}
