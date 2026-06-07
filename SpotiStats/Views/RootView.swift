import SwiftUI

/// Placeholder root screen for Phase 0.
///
/// It just proves the app launches into the themed night-city look. Real navigation
/// (Home / Tracks / Artists / Stats / Settings) and the animated rain/smoke scene come later.
struct RootView: View {
    var body: some View {
        ZStack {
            Theme.Colors.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                Text("SpotiStats")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Your music, after dark.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.xl)
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
