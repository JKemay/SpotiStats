import Foundation
import Supabase

/// The two privacy/account operations from PRIVACY.md, behind a protocol so `AuthService` can be
/// reasoned about (and a future test can stub it) instead of hard-wiring the Supabase client.
///
/// Both are Edge Functions that authenticate the caller via their Supabase JWT — the client never
/// touches the service-role tables directly.
protocol PrivacyBackend {
    /// "Disconnect & forget credentials": deletes the stored Spotify refresh token (and thereby
    /// stops collection). Play history is kept. Idempotent server-side.
    func disconnectSpotify() async throws
    /// "Delete account": permanently removes the user's play history, credentials, profile, and
    /// auth user (cascade from `auth.users`). Irreversible.
    func deleteAccount() async throws
}

/// Live implementation backed by the `disconnect-spotify` / `delete-account` Edge Functions.
struct LivePrivacyBackend: PrivacyBackend {
    let client: SupabaseClient

    func disconnectSpotify() async throws {
        let _: EmptyPrivacyResponse = try await client.functions.invoke(
            "disconnect-spotify",
            options: FunctionInvokeOptions()
        )
    }

    func deleteAccount() async throws {
        let _: EmptyPrivacyResponse = try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions()
        )
    }
}

/// The functions return `{ "ok": true }`; we only care that the call succeeded (a non-2xx makes
/// `functions.invoke` throw), so any extra keys are ignored.
private struct EmptyPrivacyResponse: Decodable {}
