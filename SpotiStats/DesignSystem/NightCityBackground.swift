import SwiftUI

/// The app's signature backdrop: the night gradient, drifting smoke, a deterministic city
/// skyline, and an animated rain layer. Drop this behind any screen (it ignores safe areas).
///
/// Performance notes: the skyline `Canvas` re-renders only on size changes; the smoke and rain
/// `Canvas` layers animate via `TimelineView` but derive every position from elapsed time over
/// fixed, precomputed fields — no per-frame state mutation. Under Reduce Motion the smoke is
/// drawn once (static) and the rain is omitted entirely.
struct NightCityBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let buildings = NightScene.buildings()
    private static let raindrops = NightScene.raindrops()
    private static let smokePuffs = NightScene.smoke()

    var body: some View {
        ZStack {
            Theme.Colors.backgroundGradient

            // Smoke sits behind the skyline so buildings cut crisp silhouettes through the haze.
            smoke

            skyline

            // Reduce Motion gets the calm version: static smoke + skyline, no falling rain.
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

    private var smoke: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let tint = Theme.Colors.accentBlue

                for puff in Self.smokePuffs {
                    // Drift horizontally and wrap; drawing one wrap-around copy keeps the loop
                    // seamless as a puff exits one edge and re-enters the other.
                    let centerY = puff.y * size.height
                    let radius = puff.radius * size.width
                    let base = (puff.phase + time * puff.speed).truncatingRemainder(dividingBy: 1)
                    let wrapped = base < 0 ? base + 1 : base

                    for offset in [-1.0, 0.0] {
                        let centerX = (wrapped + offset) * size.width
                        let rect = CGRect(
                            x: centerX - radius,
                            y: centerY - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [tint.opacity(puff.opacity), .clear]),
                                center: CGPoint(x: centerX, y: centerY),
                                startRadius: 0,
                                endRadius: radius
                            )
                        )
                    }
                }
            }
        }
        .blendMode(.plusLighter)
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
