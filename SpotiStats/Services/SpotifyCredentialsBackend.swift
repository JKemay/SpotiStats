import Foundation
import Supabase

/// A freshly minted Spotify access token and how long it's valid for.
struct MintedToken: Equatable {
    let token: String
    let expiresIn: TimeInterval
}

/// The two server-side credential operations the app performs, behind a protocol so `AuthService`
/// and `SpotifyTokenProvider` can be unit-tested with a stub instead of a live Supabase client.
///
/// Both are implemented by Edge Functions: the client never touches the service-role
/// `spotify_credentials` table directly (see HANDOFF.md "Token ownership").
protocol SpotifyCredentialsBackend {
    /// Hand the captured Spotify `provider_refresh_token` to `store-spotify-credentials`, which
    /// encrypts and stores it server-side.
    func storeRefreshToken(_ refreshToken: String, spotifyUserID: String?) async throws
    /// Ask `refresh-spotify-token` to mint a fresh, short-lived Spotify access token.
    func mintAccessToken() async throws -> MintedToken
}

/// Live implementation backed by Supabase Edge Functions.
struct LiveSpotifyCredentialsBackend: SpotifyCredentialsBackend {
    let client: SupabaseClient

    func storeRefreshToken(_ refreshToken: String, spotifyUserID: String?) async throws {
        let body = StoreCredentialsBody(refreshToken: refreshToken, spotifyUserId: spotifyUserID)
        let _: EmptyEdgeResponse = try await client.functions.invoke(
            "store-spotify-credentials",
            options: FunctionInvokeOptions(body: body)
        )
    }

    func mintAccessToken() async throws -> MintedToken {
        let response: RefreshTokenResponse = try await client.functions.invoke(
            "refresh-spotify-token",
            options: FunctionInvokeOptions()
        )
        return MintedToken(token: response.accessToken, expiresIn: TimeInterval(response.expiresIn))
    }
}

// Wire shapes for the Edge Functions, kept file-private and top-level (so `CodingKeys` stays
// within SwiftLint's nesting limit).

private struct StoreCredentialsBody: Encodable {
    let refreshToken: String
    let spotifyUserId: String?

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case spotifyUserId = "spotify_user_id"
    }
}

private struct EmptyEdgeResponse: Decodable {}

private struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}
