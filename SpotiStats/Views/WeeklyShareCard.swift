import SwiftUI

/// A fixed-size shareable stat card rendered synchronously by `ImageRenderer`.
///
/// IMPORTANT: `ImageRenderer` is synchronous — do NOT use `AsyncImage` or any remote
/// image loading here. Only text, shapes, and Canvas drawing are safe.
struct WeeklyShareCard: View {
    let data: WeeklyShareData

    // Fixed canvas size for the exported image. 340 × 480 pt @ 3x = 1020 × 1440 px.
    static let cardWidth: CGFloat = 340
    static let cardHeight: CGFloat = 480

    var body: some View {
        ZStack(alignment: .bottom) {
            // Night-sky gradient background.
            Theme.Colors.backgroundGradient
                .ignoresSafeArea()

            // Decorative static city skyline along the bottom.
            staticSkyline
                .frame(height: 120)

            // Card content stacked top-to-bottom.
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.bottom, Theme.Spacing.md)

                heroRow
                    .padding(.bottom, Theme.Spacing.lg)

                if data.topTrackName != nil || data.topArtistName != nil {
                    trackAndArtistSection
                        .padding(.bottom, Theme.Spacing.md)
                }

                if data.currentStreak > 0 {
                    streakPill
                }

                Spacer()
            }
            .padding(Theme.Spacing.lg)
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Sub-views

    private var headerRow: some View {
        HStack {
            Text(AppInfo.name)
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.Colors.accent)
            Spacer()
            Text(data.periodLabel)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var heroRow: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(data.listeningTime)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("listened")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("\(data.plays)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.accentBlue)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("plays")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var trackAndArtistSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let trackName = data.topTrackName {
                infoRow(
                    icon: "music.note",
                    label: trackName,
                    sublabel: data.topTrackArtist
                )
            }
            if let artistName = data.topArtistName {
                infoRow(
                    icon: "person.fill",
                    label: artistName,
                    sublabel: nil
                )
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.Colors.surface.opacity(0.55),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card)
        )
    }

    private func infoRow(icon: String, label: String, sublabel: String?) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                if let sublabel {
                    Text(sublabel)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var streakPill: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text("\(data.currentStreak)-day streak")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Color(hex: 0xFF6B35, opacity: 0.18),
            in: Capsule()
        )
    }

    // MARK: - Static skyline Canvas

    /// A completely synchronous Canvas skyline — safe for `ImageRenderer`.
    /// Reuses `NightScene.buildings()` geometry and the same fill approach as
    /// `NightCityBackground`'s skyline, but without any animation or TimelineView.
    private var staticSkyline: some View {
        Canvas { context, size in
            let buildings = NightScene.buildings()
            let silhouette = Color(hex: 0x120A26)
            let windowGlow = Theme.Colors.accent.opacity(0.45)

            for building in buildings {
                let rect = CGRect(
                    x: building.x * size.width,
                    y: size.height * (1 - building.height),
                    width: building.width * size.width,
                    height: size.height * building.height
                )
                context.fill(Path(rect), with: .color(silhouette))

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
}

// MARK: - Preview

#Preview {
    WeeklyShareCard(data: WeeklyShareData(
        periodLabel: "Last 7 days",
        listeningTime: "2h 30m",
        plays: 42,
        topTrackName: "Nocturne",
        topTrackArtist: "EDEN",
        topArtistName: "EDEN",
        currentStreak: 5
    ))
    .preferredColorScheme(.dark)
}
