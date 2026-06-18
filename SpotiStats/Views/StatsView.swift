import Charts
import SwiftUI

/// The Stats tab: listening analytics computed from the plays the backend has collected since
/// the user connected — deliberately distinct from Spotify's affinity windows (Tracks/Artists).
/// Everything time-based is an estimate and labeled as such.
struct StatsView: View {
    @Environment(\.statsProvider) private var provider
    @State private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                NightCityBackground()
                content
            }
            .navigationTitle("Stats")
        }
        .task(id: viewModel.selectedPeriod) { await viewModel.load(using: provider) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .tint(Theme.Colors.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            StatusPanel(systemImage: "chart.bar.xaxis", message: message) {
                Button("Retry") { Task { await viewModel.load(using: provider) } }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Colors.accent)
            }
        case .loaded(let bundle) where bundle.overview.isEmpty:
            StatusPanel(
                systemImage: "waveform.path.ecg",
                message: "Your stats are still gathering. The collector adds new plays every few "
                    + "minutes — listen to a few tracks and check back!"
            ) { EmptyView() }
        case .loaded(let bundle):
            loaded(bundle)
        }
    }

    private func loaded(_ bundle: StatsBundle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                periodPicker
                summaryGrid(bundle.overview)
                sinceCaption(bundle.overview)
                trendChart(bundle.daily)
                topTracks(bundle.topTracks)
                topArtists(bundle.topArtists)
            }
            .padding(Theme.Spacing.md)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.load(using: provider) }
    }

    private var periodPicker: some View {
        Picker("Window", selection: $viewModel.selectedPeriod) {
            ForEach(StatsPeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private func summaryGrid(_ overview: StatsOverview) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: Theme.Spacing.sm
        ) {
            StatTile(
                title: "Est. listening",
                value: StatsFormat.listeningTime(milliseconds: overview.estListeningMs),
                systemImage: "clock.fill"
            )
            StatTile(title: "Plays", value: "\(overview.totalPlays)", systemImage: "play.fill")
            StatTile(title: "Tracks", value: "\(overview.distinctTracks)", systemImage: "music.note")
            StatTile(
                title: "Artists",
                value: "\(overview.distinctArtists)",
                systemImage: "person.2.fill"
            )
        }
    }

    private func sinceCaption(_ overview: StatsOverview) -> some View {
        Text(captionText(overview))
            .font(.caption2)
            .foregroundStyle(Theme.Colors.textSecondary)
    }

    private func captionText(_ overview: StatsOverview) -> String {
        let base = "Estimated — counts each played track's full length. Stats start when you connected"
        guard let first = overview.firstPlayedDate else { return base + "." }
        return base + " (\(first.formatted(date: .abbreviated, time: .omitted)))."
    }

    @ViewBuilder
    private func trendChart(_ points: [StatDailyPoint]) -> some View {
        let bars = points.compactMap { point in
            point.date.map { DayBar(id: point.day, date: $0, playCount: point.playCount) }
        }
        if !bars.isEmpty {
            SectionCard(title: "Daily plays") {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Day", bar.date, unit: .day),
                        y: .value("Plays", bar.playCount)
                    )
                    .foregroundStyle(Theme.Colors.accent.gradient)
                }
                .chartXAxis {
                    // Date-only labels (no "12 AM"); thinned automatically when the window is wide.
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3))
                }
                .frame(height: 160)
            }
        }
    }

    @ViewBuilder
    private func topTracks(_ tracks: [StatTrack]) -> some View {
        if !tracks.isEmpty {
            SectionCard(title: "Top tracks") {
                VStack(spacing: 0) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        StatTrackRow(rank: index + 1, track: track)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func topArtists(_ artists: [StatArtist]) -> some View {
        if !artists.isEmpty {
            SectionCard(title: "Top artists") {
                VStack(spacing: 0) {
                    ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                        StatArtistRow(rank: index + 1, artist: artist)
                    }
                }
            }
        }
    }
}

/// A chartable daily bucket (only days that parsed to a real date reach here).
private struct DayBar: Identifiable {
    let id: String
    let date: Date
    let playCount: Int
}

/// A compact headline metric tile.
private struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

/// A titled translucent panel that hosts a chart or a list section.
private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            content()
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

private struct StatTrackRow: View {
    let rank: Int
    let track: StatTrack

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            RankLabel(rank: rank)
            ArtworkThumbnail(url: track.albumArtURL.flatMap(URL.init(string:)))
            VStack(alignment: .leading, spacing: 2) {
                Text(track.trackName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(track.artistsDisplay)
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            PlayCountBadge(count: track.playCount)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

private struct StatArtistRow: View {
    let rank: Int
    let artist: StatArtist

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            RankLabel(rank: rank)
            Text(artist.artistName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            Spacer()
            PlayCountBadge(count: artist.playCount)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

/// "N plays" pill, with correct singular/plural.
private struct PlayCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count) \(count == 1 ? "play" : "plays")")
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.Colors.accent)
    }
}

#Preview {
    StatsView()
        .preferredColorScheme(.dark)
}
