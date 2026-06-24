import SwiftUI

// Small presentational pieces shared by the Stats and Home dashboards. Kept here (not private to
// one screen) so both surfaces stay visually consistent — a tweak restyles every card at once.

/// A compact headline metric tile (e.g. "Est. listening · 2h 30m").
struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}

/// A titled translucent panel that hosts a chart, list, or carousel section.
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            content()
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

/// "N plays" pill with correct singular/plural.
struct PlayCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count) \(count == 1 ? "play" : "plays")")
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.Colors.accent)
    }
}
