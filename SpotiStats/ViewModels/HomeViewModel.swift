import Foundation
import Observation

/// Everything the Home dashboard renders, loaded together from our own collected data.
struct HomeDashboard: Equatable, Sendable {
    /// This-week headline counters (7-day window).
    let week: StatsOverview
    /// The single most-played track over the last 7 days (the "on repeat" highlight), if any.
    let onRepeat: StatTrack?
    /// The most recent plays from our full collected history (newest first).
    let recent: [CollectedPlay]

    /// True when there's nothing collected yet — Home shows a welcoming gathering state.
    var isEmpty: Bool { recent.isEmpty && week.isEmpty }
}

/// Drives the Home tab. Reads our collected history (not Spotify's ephemeral last-50), so the
/// feed is unbounded and the snapshot reflects real play counts.
@MainActor
@Observable
final class HomeViewModel {
    private(set) var state: LoadState<HomeDashboard> = .idle

    private let recentLimit = 25
    private let weekDays = 7

    func load(using provider: any StatsProviding) async {
        state = .loading
        do {
            async let week = provider.overview(days: weekDays)
            async let onRepeat = provider.topTracks(days: weekDays, limit: 1)
            async let recent = provider.recentPlays(limit: recentLimit)

            let dashboard = HomeDashboard(
                week: try await week,
                onRepeat: try await onRepeat.first,
                recent: try await recent
            )
            state = .loaded(dashboard)
        } catch {
            state = .failed(UserFacingError.message(for: error))
        }
    }
}
