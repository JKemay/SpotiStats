import SwiftUI

/// The app entry point.
///
/// `@main` tells Swift this struct launches the app. A SwiftUI `App` describes the app's
/// scenes (top-level windows). `RootGateView` decides between the sign-in screen and the tab shell
/// based on auth state. Live data inside the tabs arrives in the next Phase 1 step.
@main
struct SpotiStatsApp: App {
    var body: some Scene {
        WindowGroup {
            RootGateView()
                // Force dark mode: the whole aesthetic is a lo-fi night scene.
                .preferredColorScheme(.dark)
        }
    }
}
