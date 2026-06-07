import SwiftUI

/// The Home tab. Phase 1 will fill this with a snapshot (recently played + quick stats);
/// for now it is a themed placeholder so the navigation shell is real and runnable.
struct HomeView: View {
    var body: some View {
        PlaceholderScreen(
            title: "SpotiStats",
            subtitle: "Your music, after dark.",
            systemImage: "house.fill"
        )
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
