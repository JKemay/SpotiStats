import Foundation

/// The data snapshot the shareable stat card displays. Pure value type — no SwiftUI
/// imports, no async, fully testable.
struct WeeklyShareData: Equatable {
    /// Human-readable period label, e.g. "Last 7 days".
    let periodLabel: String
    /// Estimated listening time formatted for display, e.g. "2h 30m".
    let listeningTime: String
    /// Total play count in the selected window.
    let plays: Int
    /// Name of the top-played track (nil when the bundle has no top tracks).
    let topTrackName: String?
    /// Artist display string for the top track (nil when the bundle has no top tracks).
    let topTrackArtist: String?
    /// Name of the top-played artist (nil when the bundle has no top artists).
    let topArtistName: String?
    /// Number of consecutive listening days ending at today / yesterday.
    let currentStreak: Int

    // MARK: - Builder

    static func from(bundle: StatsBundle, period: StatsPeriod) -> WeeklyShareData {
        WeeklyShareData(
            periodLabel: period.shareLabel,
            listeningTime: bundle.overview.estListeningMs.asListeningTime,
            plays: bundle.overview.totalPlays,
            topTrackName: bundle.topTracks.first?.trackName,
            topTrackArtist: bundle.topTracks.first?.artistsDisplay,
            topArtistName: bundle.topArtists.first?.artistName,
            currentStreak: bundle.streaks.current
        )
    }
}

// MARK: - Period display label for sharing

private extension StatsPeriod {
    /// A friendly label suitable for the share card header.
    var shareLabel: String {
        switch self {
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .all: return "All time"
        }
    }
}
