import XCTest
@testable import SpotiStats

/// The night scene must be deterministic (no shimmer between renders) and stay inside its
/// documented unit bounds (so the renderer never draws off-scene).
final class NightSceneTests: XCTestCase {

    func testSeededGeneratorIsDeterministic() {
        var first = SeededGenerator(seed: 42)
        var second = SeededGenerator(seed: 42)
        let firstRun = (0..<10).map { _ in first.next() }
        let secondRun = (0..<10).map { _ in second.next() }
        XCTAssertEqual(firstRun, secondRun)
    }

    func testDifferentSeedsDiverge() {
        var first = SeededGenerator(seed: 1)
        var second = SeededGenerator(seed: 2)
        XCTAssertNotEqual(
            (0..<4).map { _ in first.next() },
            (0..<4).map { _ in second.next() }
        )
    }

    func testBuildingsAreDeterministicAndInBounds() {
        let first = NightScene.buildings()
        let second = NightScene.buildings()
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 9)

        for building in first {
            XCTAssertGreaterThan(building.width, 0)
            XCTAssertTrue((0.12...0.34).contains(building.height))

            // Every lit window must sit inside the building's own window grid — the renderer
            // recomputes the same grid from width/height.
            let columns = max(2, Int(building.width * 40))
            let rows = max(2, Int(building.height * 24))
            for window in building.litWindows {
                XCTAssertTrue((0..<columns).contains(window.column))
                XCTAssertTrue((0..<rows).contains(window.row))
            }
        }
    }

    func testRaindropsAreDeterministicAndInBounds() {
        let first = NightScene.raindrops()
        let second = NightScene.raindrops()
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 60)

        for drop in first {
            XCTAssertTrue((0.0...1.0).contains(drop.x))
            XCTAssertTrue((0.0..<1.0).contains(drop.phase))
            XCTAssertTrue((0.55...1.3).contains(drop.speed))
            XCTAssertTrue((0.025...0.07).contains(drop.length))
        }
    }

    func testSmokeIsDeterministicAndInBounds() {
        let first = NightScene.smoke()
        let second = NightScene.smoke()
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 5)

        for puff in first {
            XCTAssertTrue((0.58...0.92).contains(puff.y))
            XCTAssertTrue((0.20...0.40).contains(puff.radius))
            XCTAssertTrue((0.010...0.035).contains(abs(puff.speed))) // magnitude; sign alternates
            XCTAssertTrue((0.0..<1.0).contains(puff.phase))
            XCTAssertTrue((0.05...0.11).contains(puff.opacity))
        }
    }

    func testSmokeDriftsInBothDirections() {
        // Alternating-by-index signs mean the field never all slides one way.
        let puffs = NightScene.smoke()
        XCTAssertTrue(puffs.contains { $0.speed > 0 })
        XCTAssertTrue(puffs.contains { $0.speed < 0 })
    }
}
