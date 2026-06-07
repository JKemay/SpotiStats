import SwiftUI

/// The Tracks tab — will list top tracks across Spotify's affinity windows (short / medium / long),
/// each window labeled honestly. Placeholder for now.
struct TracksView: View {
    var body: some View {
        PlaceholderScreen(
            title: "Top Tracks",
            subtitle: "Your most-played tracks will appear here.",
            systemImage: "music.note"
        )
    }
}

#Preview {
    TracksView()
        .preferredColorScheme(.dark)
}
