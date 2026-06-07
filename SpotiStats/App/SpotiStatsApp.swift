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
            RootView()
                // Force dark mode: the whole aesthetic is a lo-fi night scene.
                .preferredColorScheme(.dark)
        }
    }
}
