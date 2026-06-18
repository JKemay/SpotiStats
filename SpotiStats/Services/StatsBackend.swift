import Foundation
import Supabase

/// Reads the user's collected listening stats via the `stats_*` Postgres RPCs.
///
/// Behind a protocol so the Stats view model can be unit-tested with a mock instead of a live
/// Supabase client. All calls run as the signed-in user, so RLS scopes every row to them.
protocol StatsProviding {
    /// `days == nil` means all collected history.
    func overview(days: Int?) async throws -> StatsOverview
    func topTracks(days: Int?, limit: Int) async throws -> [StatTrack]
    func topArtists(days: Int?, limit: Int) async throws -> [StatArtist]
    func daily(days: Int) async throws -> [StatDailyPoint]
}

/// Live implementation backed by the Supabase PostgREST `rpc` endpoint.
struct LiveStatsProvider: StatsProviding {
    let client: SupabaseClient

    func overview(days: Int?) async throws -> StatsOverview {
        // The RPC returns a single-row table -> a one-element array; treat empty as the zero state.
        let rows: [StatsOverview] = try await client
            .rpc("stats_overview", params: DaysParam(days: days))
            .execute()
            .value
        return rows.first ?? .empty
    }

    func topTracks(days: Int?, limit: Int) async throws -> [StatTrack] {
        try await client
            .rpc("stats_top_tracks", params: LimitDaysParam(limit: limit, days: days))
            .execute()
            .value
    }

    func topArtists(days: Int?, limit: Int) async throws -> [StatArtist] {
        try await client
            .rpc("stats_top_artists", params: LimitDaysParam(limit: limit, days: days))
            .execute()
            .value
    }

    func daily(days: Int) async throws -> [StatDailyPoint] {
        try await client
            .rpc("stats_daily", params: DaysParam(days: days))
            .execute()
            .value
    }
}

// RPC argument payloads. A nil `days` is omitted by the synthesized encoder (Swift uses
// `encodeIfPresent` for optionals), so PostgREST falls back to the SQL default of null = all-time.
// CodingKeys map to the functions' `p_*` parameter names.
private struct DaysParam: Encodable {
    let days: Int?

    enum CodingKeys: String, CodingKey {
        case days = "p_days"
    }
}

private struct LimitDaysParam: Encodable {
    let limit: Int
    let days: Int?

    enum CodingKeys: String, CodingKey {
        case limit = "p_limit"
        case days = "p_days"
    }
}

/// Environment default: surfaces a clear error if a Stats screen renders without the live
/// provider injected (e.g. a preview or test that forgot to supply a mock).
struct UnconfiguredStatsProvider: StatsProviding {
    struct NotConfigured: LocalizedError {
        var errorDescription: String? { "Stats are unavailable. Sign in to view your listening data." }
    }

    func overview(days: Int?) async throws -> StatsOverview { throw NotConfigured() }
    func topTracks(days: Int?, limit: Int) async throws -> [StatTrack] { throw NotConfigured() }
    func topArtists(days: Int?, limit: Int) async throws -> [StatArtist] { throw NotConfigured() }
    func daily(days: Int) async throws -> [StatDailyPoint] { throw NotConfigured() }
}
