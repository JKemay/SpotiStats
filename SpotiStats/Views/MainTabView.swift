import SwiftUI

/// The app's root navigation shell: a tab bar over the three primary screens.
///
/// Each tab is its own screen type (and, in later Phase 1 steps, will own an `@Observable`
/// `@MainActor` view model). For now the screens are themed placeholders so the real shell is
/// visible and navigable in the simulator.
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            TracksView()
                .tabItem { Label("Tracks", systemImage: "music.note") }

            ArtistsView()
                .tabItem { Label("Artists", systemImage: "person.2.fill") }
        }
        // Neon-purple selection tint to match the lo-fi night palette.
        .tint(Theme.Colors.accent)
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
