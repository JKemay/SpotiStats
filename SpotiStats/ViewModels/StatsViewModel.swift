import Foundation
import Observation

/// Drives the Stats tab: loads the overview, top tracks/artists, and daily trend for the
/// selected window, all scoped server-side to the signed-in user.
///
/// The four RPCs are independent, so they run concurrently and the view shows a single
/// loading/error state for the whole bundle.
@MainActor
@Observable
final class StatsViewModel {
    var selectedPeriod: StatsPeriod = .month
    private(set) var state: LoadState<StatsBundle> = .idle

    /// Top-N size for the lists.
    private let listLimit = 10

    func load(using provider: any StatsProviding) async {
        state = .loading
        let period = selectedPeriod
        // The daily trend always shows a bounded recent window (all-time would be an unwieldy
        // x-axis); 30 days for the month/all views, 7 for the week view.
        let dailyDays = period.days ?? 30

        do {
            async let overview = provider.overview(days: period.days)
            async let topTracks = provider.topTracks(days: period.days, limit: listLimit)
            async let topAlbums = provider.topAlbums(days: period.days, limit: listLimit)
            async let topArtists = provider.topArtists(days: period.days, limit: listLimit)
            async let daily = provider.daily(days: dailyDays)
            async let clockCells = provider.listeningClock(days: period.days)
            async let days = provider.playDays(limit: 365)

            let bundle = StatsBundle(
                overview: try await overview,
                topTracks: try await topTracks,
                topAlbums: try await topAlbums,
                topArtists: try await topArtists,
                daily: try await daily,
                clock: ListeningClock(cells: try await clockCells),
                streaks: StreakCalculator.streaks(playDays: try await days, today: Date())
            )
            // Guard against a stale write if the user switched periods mid-flight.
            guard period == selectedPeriod else { return }
            state = .loaded(bundle)
        } catch {
            guard period == selectedPeriod else { return }
            state = .failed(UserFacingError.message(for: error))
        }
    }
}
