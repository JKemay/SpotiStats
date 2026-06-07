import SwiftUI

/// A themed "coming soon" screen shared by the Phase 1 tab placeholders.
///
/// Centralizing this layout keeps every tab visually consistent now, and lets each screen file
/// stay tiny until it gets real data and an `@Observable` view model in the next Phase 1 steps.
struct PlaceholderScreen: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        ZStack {
            Theme.Colors.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)

                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.xl)
        }
    }
}

#Preview {
    PlaceholderScreen(
        title: "Home",
        subtitle: "Your music, after dark.",
        systemImage: "house.fill"
    )
    .preferredColorScheme(.dark)
}
