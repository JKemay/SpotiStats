import Foundation

// The pure geometry of the lo-fi night-city scene: deterministic building silhouettes, lit
// windows, and raindrop parameters. No SwiftUI here — `NightCityBackground` renders these —
// so the generation rules are unit-testable and the scene never "shimmers" between renders
// (same seed, same skyline).

/// A tiny seedable generator (SplitMix64). Foundation's `SystemRandomNumberGenerator` can't be
/// seeded, and the scene must be reproducible for stability and for tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

enum NightScene {

    /// One building silhouette, in unit-ish coordinates: `x`/`width` as fractions of scene width,
    /// `height` as a fraction of scene height (measured up from the bottom edge).
    struct Building: Equatable {
        let x: Double
        let width: Double
        let height: Double
        /// Lit windows as (column, row) grid positions inside the building.
        let litWindows: [GridPosition]
    }

    struct GridPosition: Equatable {
        let column: Int
        let row: Int
    }

    /// One raindrop's animation parameters, in unit coordinates. The renderer derives a y
    /// position from elapsed time, so drops need no mutable state at all.
    struct Raindrop: Equatable {
        let x: Double
        /// 0..<1 phase offset so drops don't fall in lockstep.
        let phase: Double
        /// Full screen-heights per second.
        let speed: Double
        /// Streak length as a fraction of scene height.
        let length: Double
    }

    /// Deterministic skyline: `count` buildings tiled left-to-right with slight overlap, varied
    /// heights, and sparse lit windows. Same seed -> identical skyline.
    static func buildings(count: Int = 9, seed: UInt64 = 0xCAFE) -> [Building] {
        var rng = SeededGenerator(seed: seed)
        var result: [Building] = []
        let slot = 1.0 / Double(count)

        for index in 0..<count {
            let width = slot * Double.random(in: 0.85...1.45, using: &rng)
            let x = slot * Double(index) - width * 0.15
            let height = Double.random(in: 0.12...0.34, using: &rng)

            // Sparse warm windows: a few per building, none on some (asleep).
            let columns = max(2, Int(width * 40))
            let rows = max(2, Int(height * 24))
            var lit: [GridPosition] = []
            let litCount = Int.random(in: 0...max(2, (columns * rows) / 6), using: &rng)
            for _ in 0..<litCount {
                lit.append(GridPosition(
                    column: Int.random(in: 0..<columns, using: &rng),
                    row: Int.random(in: 0..<rows, using: &rng)
                ))
            }
            result.append(Building(x: x, width: width, height: height, litWindows: lit))
        }
        return result
    }

    /// Deterministic rain field. Speeds and lengths are correlated (faster drops streak longer)
    /// to fake depth. Same seed -> identical field.
    static func raindrops(count: Int = 60, seed: UInt64 = 0xBEEF) -> [Raindrop] {
        var rng = SeededGenerator(seed: seed)
        return (0..<count).map { _ in
            let depth = Double.random(in: 0.35...1.0, using: &rng) // 1.0 = nearest
            return Raindrop(
                x: Double.random(in: 0...1, using: &rng),
                phase: Double.random(in: 0..<1, using: &rng),
                speed: 0.55 + 0.75 * depth,
                length: 0.025 + 0.045 * depth
            )
        }
    }
}
