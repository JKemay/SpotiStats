import SwiftUI

/// The Home tab: the user's recently played tracks (Spotify returns at most the last 50 plays).
struct HomeView: View {
    @Environment(\.spotifyAPI) private var api
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundGradient.ignoresSafeArea()
                LoadableList(
                    state: viewModel.state,
                    emptyMessage: "Nothing played recently. Put something on and come back!",
                    retry: { await viewModel.load(using: api) },
                    row: { _, item in RecentlyPlayedRow(item: item) }
                )
            }
            .navigationTitle("Recently Played")
        }
        .task { await viewModel.load(using: api) }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
