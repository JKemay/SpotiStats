import SwiftUI

/// Injects a `SpotifyAPI` into the SwiftUI environment.
///
/// `SpotifyAPIClient` is a plain (non-`@Observable`) class, so the object-based
/// `.environment(_:)` overload can't carry it — a custom `EnvironmentKey` can. `RootGateView`
/// injects the one live client; screens read it with `@Environment(\.spotifyAPI)`.
private struct SpotifyAPIKey: EnvironmentKey {
    static let defaultValue: any SpotifyAPI = UnconfiguredSpotifyAPI()
}

extension EnvironmentValues {
    var spotifyAPI: any SpotifyAPI {
        get { self[SpotifyAPIKey.self] }
        set { self[SpotifyAPIKey.self] = newValue }
    }
}

/// Injects a `StatsProviding` into the SwiftUI environment (same rationale as `spotifyAPI`:
/// the live provider wraps a non-`@Observable` Supabase client). Built from `AuthService`'s
/// authenticated client and injected by `RootGateView` in the signed-in branch.
private struct StatsProviderKey: EnvironmentKey {
    static let defaultValue: any StatsProviding = UnconfiguredStatsProvider()
}

extension EnvironmentValues {
    var statsProvider: any StatsProviding {
        get { self[StatsProviderKey.self] }
        set { self[StatsProviderKey.self] = newValue }
    }
}

/// The default environment value: every call fails loudly.
///
/// Hitting this means a view was shown without `RootGateView` injecting the live client
/// (or a preview/test forgot to provide a mock). Failing with a clear message beats crashing
/// or silently returning empty data.
struct UnconfiguredSpotifyAPI: SpotifyAPI {
    struct NotConfigured: LocalizedError {
        var errorDescription: String? {
            "Spotify API not configured. Sign in to connect your account."
        }
    }

    func topTracks(range: SpotifyTimeRange, limit: Int) async throws -> [SpotifyTrack] {
        throw NotConfigured()
    }

    func topArtists(range: SpotifyTimeRange, limit: Int) async throws -> [SpotifyArtist] {
        throw NotConfigured()
    }

    func recentlyPlayed(limit: Int) async throws -> [PlayHistoryItem] {
        throw NotConfigured()
    }
}
