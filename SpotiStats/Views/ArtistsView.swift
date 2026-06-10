import SwiftUI

/// The Artists tab: top artists for a selected Spotify affinity window, labeled honestly.
struct ArtistsView: View {
    @Environment(\.spotifyAPI) private var api
    @State private var viewModel = ArtistsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                NightCityBackground()
                VStack(spacing: 0) {
                    TimeRangePicker(selection: $viewModel.selectedRange)
                    LoadableList(
                        state: viewModel.state,
                        emptyMessage: "No top artists for this window yet. Keep listening!",
                        retry: { await viewModel.load(using: api) },
                        row: { index, artist in ArtistRow(rank: index + 1, artist: artist) }
                    )
                }
            }
            .navigationTitle("Top Artists")
        }
        .task(id: viewModel.selectedRange) { await viewModel.load(using: api) }
    }
}

#Preview {
    ArtistsView()
        .preferredColorScheme(.dark)
}
