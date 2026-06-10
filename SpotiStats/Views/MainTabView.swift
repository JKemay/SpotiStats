import SwiftUI

/// The app's root navigation shell: a tab bar over the three data screens plus Settings.
struct MainTabView: View {
    enum Tab: String {
        case home, tracks, artists, settings
    }

    @State private var selection: Tab = MainTabView.initialTab

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            TracksView()
                .tabItem { Label("Tracks", systemImage: "music.note") }
                .tag(Tab.tracks)

            ArtistsView()
                .tabItem { Label("Artists", systemImage: "person.2.fill") }
                .tag(Tab.artists)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        // Neon-purple selection tint to match the lo-fi night palette.
        .tint(Theme.Colors.accent)
    }

    /// Debug builds can open on a specific tab (`-initialTab tracks` as a launch argument), so
    /// simulator-driven verification and future UI tests can reach any screen directly.
    private static var initialTab: Tab {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "initialTab"), let tab = Tab(rawValue: raw) {
            return tab
        }
        #endif
        return .home
    }
}
