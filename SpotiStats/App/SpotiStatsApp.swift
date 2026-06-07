import SwiftUI

/// The app entry point.
///
/// `@main` tells Swift this struct launches the app. A SwiftUI `App` describes the app's
/// scenes (top-level windows). The Phase 0.5 auth/token proof spike is done, so we now launch the
/// real navigation shell; auth gating and live data arrive in the next Phase 1 steps.
@main
struct SpotiStatsApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                // Force dark mode: the whole aesthetic is a lo-fi night scene.
                .preferredColorScheme(.dark)
        }
    }
}
