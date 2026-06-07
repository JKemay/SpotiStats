import SwiftUI

/// The app entry point.
///
/// `@main` tells Swift this struct launches the app. A SwiftUI `App` describes the app's
/// scenes (top-level windows). For now we show a single placeholder screen; real navigation
/// arrives in Phase 1.
@main
struct SpotiStatsApp: App {
    var body: some Scene {
        WindowGroup {
            // Phase 0.5: the temporary auth/token proof spike. Swapped for real navigation in Phase 1.
            AuthSpikeView()
                // Force dark mode: the whole aesthetic is a lo-fi night scene.
                .preferredColorScheme(.dark)
        }
    }
}
