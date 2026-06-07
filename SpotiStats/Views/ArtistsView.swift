import SwiftUI

/// The Artists tab — will list top artists across Spotify's affinity windows. Placeholder for now.
struct ArtistsView: View {
    var body: some View {
        PlaceholderScreen(
            title: "Top Artists",
            subtitle: "Your most-played artists will appear here.",
            systemImage: "person.2.fill"
        )
    }
}

#Preview {
    ArtistsView()
        .preferredColorScheme(.dark)
}
