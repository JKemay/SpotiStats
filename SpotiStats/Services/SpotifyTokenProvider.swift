import Foundation

/// Supplies Spotify access tokens to `SpotifyAPIClient`, caching one in memory until shortly before
/// it expires. Access tokens are deliberately **memory-only** (never persisted) — only the Supabase
/// session lives in the Keychain (see HANDOFF.md).
///
/// The `now` clock is injectable so expiry logic is unit-testable without waiting in real time.
@MainActor
final class SpotifyTokenProvider: SpotifyTokenProviding {
    private let backend: SpotifyCredentialsBackend
    private let now: () -> Date

    /// Refresh this many seconds before the real expiry, so an in-flight request never races the
    /// token going stale.
    private let expiryLeeway: TimeInterval = 30

    private var cachedToken: String?
    private var expiresAt: Date?

    init(backend: SpotifyCredentialsBackend, now: @escaping () -> Date = { Date() }) {
        self.backend = backend
        self.now = now
    }

    func accessToken() async throws -> String {
        if let cachedToken, let expiresAt, expiresAt > now().addingTimeInterval(expiryLeeway) {
            return cachedToken
        }
        return try await refreshedAccessToken()
    }

    func refreshedAccessToken() async throws -> String {
        let minted = try await backend.mintAccessToken()
        cachedToken = minted.token
        expiresAt = now().addingTimeInterval(minted.expiresIn)
        return minted.token
    }

    /// Drop any cached token (e.g. on sign-out or right after (re)connecting credentials).
    func clear() {
        cachedToken = nil
        expiresAt = nil
    }
}
