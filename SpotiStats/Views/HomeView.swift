import SwiftUI

/// The Home tab — a dashboard over the user's *collected* listening data (not Spotify's
/// ephemeral last-50): a this-week snapshot, an "on repeat" highlight, and a recently-played
/// carousel drawn from our full, growing history.
struct HomeView: View {
    @Environment(\.statsProvider) private var provider
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                NightCityBackground()
                content
            }
            .navigationTitle(Self.greeting)
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await viewModel.load(using: provider) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .tint(Theme.Colors.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            StatusPanel(systemImage: "wifi.exclamationmark", message: message) {
                Button("Retry") { Task { await viewModel.load(using: provider) } }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Colors.accent)
            }
        case .loaded(let dashboard) where dashboard.isEmpty:
            StatusPanel(
                systemImage: "music.note.house",
                message: "Welcome to \(AppInfo.name). Put something on — the collector logs every "
                    + "play, and your dashboard fills in within a few minutes."
            ) { EmptyView() }
        case .loaded(let dashboard):
            loaded(dashboard)
        }
    }

    private func loaded(_ dashboard: HomeDashboard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                weekSnapshot(dashboard.week)
                if let onRepeat = dashboard.onRepeat {
                    onRepeatCard(onRepeat)
                }
                recentCarousel(dashboard.recent)
            }
            .padding(Theme.Spacing.md)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.load(using: provider) }
    }

    private func weekSnapshot(_ week: StatsOverview) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            StatTile(
                title: "This week",
                value: StatsFormat.listeningTime(milliseconds: week.estListeningMs),
                systemImage: "clock.fill"
            )
            StatTile(title: "Plays", value: "\(week.totalPlays)", systemImage: "play.fill")
        }
    }

    private func onRepeatCard(_ track: StatTrack) -> some View {
        SectionCard(title: "On repeat") {
            HStack(spacing: Theme.Spacing.md) {
                ArtworkThumbnail(url: track.albumArtURL.flatMap(URL.init(string:)), size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.trackName)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(track.artistsDisplay)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                PlayCountBadge(count: track.playCount)
            }
        }
    }

    @ViewBuilder
    private func recentCarousel(_ plays: [CollectedPlay]) -> some View {
        if !plays.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Recently played")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Theme.Spacing.md) {
                        ForEach(plays) { play in
                            RecentPlayCard(play: play)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        }
    }

    /// A time-of-day greeting used as the large title.
    private static var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night"
        }
    }
}

/// A single album-art tile in the recently-played carousel.
private struct RecentPlayCard: View {
    let play: CollectedPlay

    private static let cardWidth: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ArtworkThumbnail(
                url: play.albumArtURL.flatMap(URL.init(string:)),
                size: Self.cardWidth,
                cornerRadius: Theme.Radius.card
            )
            Text(play.trackName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            Text(play.artistsDisplay)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
            if let playedAt = play.playedAtDate {
                Text(playedAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.8))
            }
        }
        .frame(width: Self.cardWidth, alignment: .leading)
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
