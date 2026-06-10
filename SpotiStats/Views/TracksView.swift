import SwiftUI

/// The Tracks tab: top tracks for a selected Spotify affinity window, labeled honestly.
struct TracksView: View {
    @Environment(\.spotifyAPI) private var api
    @State private var viewModel = TracksViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundGradient.ignoresSafeArea()
                VStack(spacing: 0) {
                    TimeRangePicker(selection: $viewModel.selectedRange)
                    LoadableList(
                        state: viewModel.state,
                        emptyMessage: "No top tracks for this window yet. Keep listening!",
                        retry: { await viewModel.load(using: api) },
                        row: { index, track in TrackRow(rank: index + 1, track: track) }
                    )
                }
            }
            .navigationTitle("Top Tracks")
        }
        // Re-runs on first appearance and whenever the selected window changes.
        .task(id: viewModel.selectedRange) { await viewModel.load(using: api) }
    }
}

#Preview {
    TracksView()
        .preferredColorScheme(.dark)
}
