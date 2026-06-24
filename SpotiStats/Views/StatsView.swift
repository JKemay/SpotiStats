import Charts
import SwiftUI

/// The Stats tab: listening analytics computed from the plays the backend has collected since
/// the user connected — deliberately distinct from Spotify's affinity windows (Tracks/Artists).
/// Everything time-based is an estimate and labeled as such.
struct StatsView: View {
    @Environment(\.statsProvider) private var provider
    @State private var viewModel = StatsViewModel()
    @State private var shareURL: URL?
    @State private var isShowingShareSheet = false

    // DEBUG flag: set `-previewShareCard YES` as a launch argument to overlay the share card.
    #if DEBUG
    private var previewShareCard: Bool {
        UserDefaults.standard.bool(forKey: "previewShareCard")
    }
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                NightCityBackground()
                content
                #if DEBUG
                if previewShareCard, case .loaded(let bundle) = viewModel.state, !bundle.overview.isEmpty {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    WeeklyShareCard(
                        data: WeeklyShareData.from(bundle: bundle, period: viewModel.selectedPeriod)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
                }
                #endif
            }
            .navigationTitle("Stats")
            .toolbar {
                if case .loaded(let bundle) = viewModel.state, !bundle.overview.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        shareButton(bundle: bundle)
                    }
                }
            }
        }
        .task(id: viewModel.selectedPeriod) { await viewModel.load(using: provider) }
        .sheet(
            isPresented: $isShowingShareSheet,
            onDismiss: { shareURL = nil },
            content: {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        )
    }

    private func shareButton(bundle: StatsBundle) -> some View {
        Button {
            renderAndShare(bundle: bundle)
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .tint(Theme.Colors.accent)
    }

    private func renderAndShare(bundle: StatsBundle) {
        let data = WeeklyShareData.from(bundle: bundle, period: viewModel.selectedPeriod)
        let card = WeeklyShareCard(data: data)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3

        guard let uiImage = renderer.uiImage,
              let pngData = uiImage.pngData() else { return }

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nocturne-stats.png")
        do {
            try pngData.write(to: tmpURL, options: .atomic)
            shareURL = tmpURL
            HapticManager.shared.success()
            isShowingShareSheet = true
        } catch {
            // If we can't write to tmp, silently skip — no force-unwrap, no crash.
        }
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
                Button("Retry") {
                    HapticManager.shared.tap()
                    Task { await viewModel.load(using: provider) }
                }
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
                streaks(bundle.streaks)
                trendChart(bundle.daily)
                listeningClock(bundle.clock)
                topTracks(bundle.topTracks)
                topAlbums(bundle.topAlbums)
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
        .onChange(of: viewModel.selectedPeriod) { _, _ in HapticManager.shared.selection() }
    }

    private func summaryGrid(_ overview: StatsOverview) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: Theme.Spacing.sm
        ) {
            StatTile(
                title: "Est. listening",
                value: overview.estListeningMs.asListeningTime,
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
    private func streaks(_ streaks: ListeningStreaks) -> some View {
        if streaks.longest > 0 {
            SectionCard(title: "Streaks") {
                HStack(spacing: Theme.Spacing.sm) {
                    StatTile(
                        title: "Current",
                        value: dayLabel(streaks.current),
                        systemImage: "flame.fill"
                    )
                    StatTile(
                        title: "Longest",
                        value: dayLabel(streaks.longest),
                        systemImage: "trophy.fill"
                    )
                }
            }
        }
    }

    private func dayLabel(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
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
                .accessibilityLabel(chartAccessibilityLabel(bars))
            }
        }
    }

    private func chartAccessibilityLabel(_ bars: [DayBar]) -> String {
        let total = bars.reduce(0) { $0 + $1.playCount }
        guard let busiest = bars.max(by: { $0.playCount < $1.playCount }) else {
            return "Daily plays chart."
        }
        let busiestFormatted = busiest.date.formatted(.dateTime.month(.abbreviated).day())
        return "Daily plays chart. \(total) total plays. Busiest day: \(busiestFormatted) with \(busiest.playCount) plays."
    }

    @ViewBuilder
    private func listeningClock(_ clock: ListeningClock) -> some View {
        if !clock.isEmpty {
            SectionCard(title: "Listening clock") {
                ListeningClockGrid(clock: clock)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(clockAccessibilityLabel(clock))
                Text("Times shown in UTC.")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private func clockAccessibilityLabel(_ clock: ListeningClock) -> String {
        // Find the (weekday, hour) bucket with the highest intensity.
        let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        var bestWeekday = 0
        var bestHour = 0
        var bestIntensity = 0.0
        for weekday in 0..<7 {
            for hour in 0..<24 {
                let intensity = clock.intensity(weekday: weekday, hour: hour)
                if intensity > bestIntensity {
                    bestIntensity = intensity
                    bestWeekday = weekday
                    bestHour = hour
                }
            }
        }
        let day = weekdayNames[bestWeekday]
        let hour = bestHour == 0 ? "midnight" : bestHour < 12
            ? "\(bestHour) AM"
            : bestHour == 12 ? "noon" : "\(bestHour - 12) PM"
        return "Listening clock. Most active on \(day) around \(hour)."
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
    private func topAlbums(_ albums: [StatAlbum]) -> some View {
        if !albums.isEmpty {
            SectionCard(title: "Top albums") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Theme.Spacing.md) {
                        ForEach(albums) { album in
                            TopAlbumCard(album: album)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
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

/// 7-row × 24-column heatmap grid.  One cell per (weekday, hour) bucket.
/// The view is deliberately dumb: it only reads `clock.intensity(weekday:hour:)`.
private struct ListeningClockGrid: View {
    let clock: ListeningClock

    // Single-letter day labels in Sunday-first order (mirrors PostgreSQL DOW 0…6).
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    // Cell size chosen so 24 columns + a ~12pt label column fit a ≈360pt card width:
    // 12 (label) + 4 (gap) + 24 * (10 + 2) = 12 + 4 + 288 = 304pt — comfortably fits.
    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { weekday in
                HStack(spacing: cellSpacing) {
                    Text(dayLabels[weekday])
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 10, alignment: .trailing)
                        .accessibilityHidden(true)
                    ForEach(0..<24, id: \.self) { hour in
                        let intensity = clock.intensity(weekday: weekday, hour: hour)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.accent.opacity(0.12 + 0.88 * intensity))
                            .frame(width: cellSize, height: cellSize)
                            .accessibilityHidden(true)
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

/// A single album-cover tile in the top-albums carousel.
private struct TopAlbumCard: View {
    let album: StatAlbum

    private static let cardWidth: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ArtworkThumbnail(
                url: album.albumArtURL.flatMap(URL.init(string:)),
                size: Self.cardWidth,
                cornerRadius: Theme.Radius.card
            )
            Text(album.albumName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            PlayCountBadge(count: album.playCount)
        }
        .frame(width: Self.cardWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(album.albumName) by \(album.artistsDisplay), \(album.playCount) \(album.playCount == 1 ? "play" : "plays")"
        )
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(rank). \(track.trackName) by \(track.artistsDisplay), \(track.playCount) \(track.playCount == 1 ? "play" : "plays")"
        )
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(rank). \(artist.artistName), \(artist.playCount) \(artist.playCount == 1 ? "play" : "plays")"
        )
    }
}

#Preview {
    StatsView()
        .preferredColorScheme(.dark)
}
