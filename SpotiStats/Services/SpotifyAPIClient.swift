import Foundation

// MARK: - Token provider

/// Supplies Spotify access tokens to the API client.
///
/// The concrete implementation (the Phase 1 `AuthService`) keeps an access token in memory and
/// mints fresh ones via the `refresh-spotify-token` Edge Function. Abstracting it behind a protocol
/// keeps `SpotifyAPIClient` decoupled from auth and trivially unit-testable with a stub.
protocol SpotifyTokenProviding {
    /// A currently-valid access token (cached if possible).
    func accessToken() async throws -> String
    /// Force a refresh (e.g. after a 401) and return the new token.
    func refreshedAccessToken() async throws -> String
}

// MARK: - Errors

/// Errors surfaced by `SpotifyAPIClient`. Decoding and transport (`URLError`) failures propagate
/// as their own thrown types, so this enum stays `Equatable` for easy assertions in tests.
enum SpotifyAPIError: Error, Equatable {
    /// A request URL could not be constructed (programmer error).
    case invalidURL
    /// Still 401 after one forced token refresh — the caller should trigger re-auth.
    case unauthorized
    /// Rate limited and out of retry budget; `retryAfter` echoes Spotify's header if present.
    case rateLimited(retryAfter: TimeInterval?)
    /// Any other non-2xx status.
    case http(status: Int)
    /// The response was not an HTTP response (should not happen in practice).
    case nonHTTPResponse
}

// MARK: - API surface

/// The read-only Spotify endpoints the app needs in Phase 1.
protocol SpotifyAPI {
    func topTracks(range: SpotifyTimeRange, limit: Int) async throws -> [SpotifyTrack]
    func topArtists(range: SpotifyTimeRange, limit: Int) async throws -> [SpotifyArtist]
    func recentlyPlayed(limit: Int) async throws -> [PlayHistoryItem]
}

extension SpotifyAPI {
    /// Convenience overloads with sensible defaults (Spotify caps these endpoints at 50).
    func topTracks(range: SpotifyTimeRange) async throws -> [SpotifyTrack] {
        try await topTracks(range: range, limit: 20)
    }

    func topArtists(range: SpotifyTimeRange) async throws -> [SpotifyArtist] {
        try await topArtists(range: range, limit: 20)
    }

    func recentlyPlayed() async throws -> [PlayHistoryItem] {
        try await recentlyPlayed(limit: 20)
    }
}

// MARK: - Client

/// Talks to the Spotify Web API with a native `URLSession`.
///
/// Behavior that matters:
/// - **401 -> refresh-and-retry-once.** Access tokens are short-lived; on a 401 we ask the token
///   provider for a fresh one and retry exactly once before giving up with `.unauthorized`.
/// - **429 -> honor `Retry-After`.** We back off for the header's duration and retry, up to a small
///   fixed budget, then surface `.rateLimited`.
final class SpotifyAPIClient: SpotifyAPI {
    private let tokenProvider: SpotifyTokenProviding
    private let session: URLSession
    private let baseURL: String
    private let decoder: JSONDecoder

    /// How many times we'll back off and retry on HTTP 429 before giving up.
    private static let maxRateLimitRetries = 2

    /// Kept as a `String` (not a force-unwrapped `URL`) so request URLs are built safely in `makeURL`.
    static let defaultBaseURL = "https://api.spotify.com/v1"

    init(
        tokenProvider: SpotifyTokenProviding,
        session: URLSession = .shared,
        baseURL: String = SpotifyAPIClient.defaultBaseURL
    ) {
        self.tokenProvider = tokenProvider
        self.session = session
        self.baseURL = baseURL
        let decoder = JSONDecoder()
        // Spotify uses snake_case (duration_ms, played_at); map it to our camelCase properties.
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    // MARK: Endpoints

    func topTracks(range: SpotifyTimeRange, limit: Int) async throws -> [SpotifyTrack] {
        let page: SpotifyPage<SpotifyTrack> = try await get(
            "me/top/tracks",
            query: [
                URLQueryItem(name: "time_range", value: range.queryValue),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
        return page.items
    }

    func topArtists(range: SpotifyTimeRange, limit: Int) async throws -> [SpotifyArtist] {
        let page: SpotifyPage<SpotifyArtist> = try await get(
            "me/top/artists",
            query: [
                URLQueryItem(name: "time_range", value: range.queryValue),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
        return page.items
    }

    func recentlyPlayed(limit: Int) async throws -> [PlayHistoryItem] {
        let response: RecentlyPlayedResponse = try await get(
            "me/player/recently-played",
            query: [URLQueryItem(name: "limit", value: String(limit))]
        )
        return response.items
    }

    // MARK: Request plumbing

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        let data = try await performWithRetries(path: path, query: query)
        return try decoder.decode(T.self, from: data)
    }

    private func performWithRetries(path: String, query: [URLQueryItem]) async throws -> Data {
        var token = try await tokenProvider.accessToken()
        var didRefresh = false
        var rateLimitAttempts = 0

        while true {
            let (data, response) = try await send(path: path, query: query, token: token)
            switch response.statusCode {
            case 200...299:
                return data
            case 401 where !didRefresh:
                didRefresh = true
                token = try await tokenProvider.refreshedAccessToken()
            case 401:
                throw SpotifyAPIError.unauthorized
            case 429:
                let retryAfter = Self.retryAfterSeconds(from: response)
                guard rateLimitAttempts < Self.maxRateLimitRetries else {
                    throw SpotifyAPIError.rateLimited(retryAfter: retryAfter)
                }
                rateLimitAttempts += 1
                try await Self.sleep(seconds: retryAfter ?? 1)
            default:
                throw SpotifyAPIError.http(status: response.statusCode)
            }
        }
    }

    private func send(
        path: String,
        query: [URLQueryItem],
        token: String
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = makeURL(path: path, query: query) else {
            throw SpotifyAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAPIError.nonHTTPResponse
        }
        return (data, http)
    }

    private func makeURL(path: String, query: [URLQueryItem]) -> URL? {
        guard let base = URL(string: "\(baseURL)/\(path)"),
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = query.isEmpty ? nil : query
        return components.url
    }

    private static func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(value) else {
            return nil
        }
        return seconds
    }

    private static func sleep(seconds: TimeInterval) async throws {
        let clamped = max(0, seconds)
        try await Task.sleep(nanoseconds: UInt64((clamped * 1_000_000_000).rounded()))
    }
}
