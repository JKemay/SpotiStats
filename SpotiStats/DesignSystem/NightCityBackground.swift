import SwiftUI

/// The app's signature backdrop: the night gradient, a deterministic city skyline, and an
/// animated rain layer. Drop this behind any screen (it ignores safe areas itself).
///
/// Performance notes: the skyline `Canvas` re-renders only on size changes; the rain `Canvas`
/// animates via `TimelineView` but derives every drop position from elapsed time over a fixed,
/// precomputed field — no per-frame state mutation or allocations beyond one stroked path.
/// Rain pauses entirely under Reduce Motion.
struct NightCityBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let buildings = NightScene.buildings()
    private static let raindrops = NightScene.raindrops()

    var body: some View {
        ZStack {
            Theme.Colors.backgroundGradient

            skyline

            // Reduce Motion gets the calm version: skyline only, no falling rain.
            if !reduceMotion {
                rain
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var skyline: some View {
        Canvas { context, size in
            let silhouette = Color(hex: 0x120A26)
            let windowGlow = Theme.Colors.accent.opacity(0.5)

            for building in Self.buildings {
                let rect = CGRect(
                    x: building.x * size.width,
                    y: size.height * (1 - building.height),
                    width: building.width * size.width,
                    height: size.height * building.height
                )
                context.fill(Path(rect), with: .color(silhouette))

                // Windows: a sparse grid of small lit panes inside the building.
                let columns = max(2, Int(building.width * 40))
                let rows = max(2, Int(building.height * 24))
                let cellWidth = rect.width / CGFloat(columns)
                let cellHeight = rect.height / CGFloat(rows)
                for window in building.litWindows {
                    let pane = CGRect(
                        x: rect.minX + CGFloat(window.column) * cellWidth + cellWidth * 0.3,
                        y: rect.minY + CGFloat(window.row) * cellHeight + cellHeight * 0.3,
                        width: max(1.5, cellWidth * 0.4),
                        height: max(1.5, cellHeight * 0.4)
                    )
                    context.fill(Path(pane), with: .color(windowGlow))
                }
            }
        }
        .opacity(0.85)
    }

    private var rain: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                var streaks = Path()

                for drop in Self.raindrops {
                    // Wrap each drop through (height + streak) so it re-enters from the top.
                    let travel = size.height + drop.length * size.height
                    let progress = (time * drop.speed + drop.phase * 4).truncatingRemainder(
                        dividingBy: travel / size.height
                    )
                    let yTop = progress * size.height - drop.length * size.height
                    let x = drop.x * size.width

                    streaks.move(to: CGPoint(x: x, y: yTop))
                    streaks.addLine(to: CGPoint(
                        // A slight slant reads as wind without needing per-drop angles.
                        x: x - 2,
                        y: yTop + drop.length * size.height
                    ))
                }

                context.stroke(
                    streaks,
                    with: .color(Theme.Colors.accent.opacity(0.18)),
                    lineWidth: 1
                )
            }
        }
    }
}

#Preview {
    NightCityBackground()
        .preferredColorScheme(.dark)
}
