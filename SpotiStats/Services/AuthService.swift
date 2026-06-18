import Foundation
import Observation
import Supabase

/// Owns the auth/session lifecycle for the app: Spotify sign-in (Supabase OAuth, PKCE), the
/// `store-spotify-credentials` handoff, session restore, and sign-out. Exposes a
/// `SpotifyTokenProvider` that `SpotifyAPIClient` uses to authorize Spotify calls.
///
/// This is the production wiring of the spine the Phase 0.5 spike proved.
@MainActor
@Observable
final class AuthService {
    enum State: Equatable {
        /// Before we've checked the Keychain for a restored session.
        case unknown
        case signedOut
        case signedIn(userID: String)
    }

    private(set) var state: State = .unknown
    private(set) var isWorking = false
    private(set) var lastError: String?

    /// The token source for `SpotifyAPIClient` (memory-only access tokens).
    let tokenProvider: SpotifyTokenProvider

    /// Reads the user's collected listening stats (Phase 3) via the authenticated client.
    let statsProvider: StatsProviding

    private let client: SupabaseClient
    private let backend: SpotifyCredentialsBackend
    private let config: AppConfig

    init(client: SupabaseClient, backend: SpotifyCredentialsBackend, config: AppConfig) {
        self.client = client
        self.backend = backend
        self.config = config
        self.tokenProvider = SpotifyTokenProvider(backend: backend)
        self.statsProvider = LiveStatsProvider(client: client)
    }

    /// Build the live service from the bundled config.
    static func live() throws -> AuthService {
        let config = try AppConfig.loadFromBundle()
        let client = Backend.makeClient(config)
        let backend = LiveSpotifyCredentialsBackend(client: client)
        return AuthService(client: client, backend: backend, config: config)
    }

    /// On launch: reflect whether supabase-swift restored a persisted session from the Keychain.
    func restoreSession() async {
        let session = try? await client.auth.session
        if let session {
            state = .signedIn(userID: session.user.id.uuidString)
        } else {
            state = .signedOut
        }
    }

    /// Sign in with Spotify and hand the refresh token to the backend.
    ///
    /// Spotify only returns a `provider_refresh_token` when it issues one (typically on first
    /// consent). If it's missing, we retry once forcing a fresh consent screen
    /// (`show_dialog=true`) before giving up — the nil-refresh-token fallback from HANDOFF.md.
    func connectSpotify() async {
        guard !isWorking else { return }
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            var session = try await signIn(forceConsent: false)
            if session.providerRefreshToken == nil {
                session = try await signIn(forceConsent: true)
            }
            guard let refreshToken = session.providerRefreshToken else {
                throw AuthError.missingRefreshToken
            }
            try await backend.storeRefreshToken(refreshToken, spotifyUserID: nil)
            tokenProvider.clear()
            state = .signedIn(userID: session.user.id.uuidString)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() async {
        isWorking = true
        defer { isWorking = false }
        try? await client.auth.signOut()
        tokenProvider.clear()
        state = .signedOut
    }

    private func signIn(forceConsent: Bool) async throws -> Session {
        let queryParams: [(name: String, value: String?)] = forceConsent
            ? [(name: "show_dialog", value: "true")]
            : []
        return try await client.auth.signInWithOAuth(
            provider: .spotify,
            redirectTo: config.oauthRedirectURL,
            scopes: "user-top-read user-read-recently-played",
            queryParams: queryParams
        )
    }
}

enum AuthError: LocalizedError {
    case missingRefreshToken

    var errorDescription: String? {
        switch self {
        case .missingRefreshToken:
            return "Spotify didn't return a refresh token. Please try connecting again."
        }
    }
}
