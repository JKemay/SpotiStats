import Foundation
import Supabase

/// Builds the configured Supabase client from `AppConfig`.
///
/// The client uses the PKCE flow and a redirect URL matching our registered URL scheme. On Apple
/// platforms supabase-swift persists the session in the Keychain by default, which is what lets the
/// session survive app relaunches (one of the things the auth spike verifies).
enum Backend {
    static func makeClient(_ config: AppConfig) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: config.supabaseURL,
            supabaseKey: config.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: config.oauthRedirectURL,
                    flowType: .pkce
                )
            )
        )
    }
}
