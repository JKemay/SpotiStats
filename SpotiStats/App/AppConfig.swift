import Foundation

/// Runtime configuration, loaded from values baked into `Info.plist` at build time
/// (which come from `Secrets.xcconfig`).
///
/// Design notes for a newcomer to Swift:
/// - This is a `struct` (a value type). We model config as plain data.
/// - The URL-building logic is a `static` pure function so it can be unit-tested without a bundle.
/// - We never store the Spotify client secret here; it lives only in the backend.
struct AppConfig {

    enum ConfigError: Error, Equatable {
        case missing(key: String)
        case placeholderValue(key: String)
    }

    let supabaseProjectRef: String
    let supabaseAnonKey: String
    let oauthCallbackScheme: String

    /// The full Supabase API base URL, reconstructed from the project ref.
    ///
    /// We store only the ref (not the full URL) because `.xcconfig` treats `//` as a comment,
    /// which would silently truncate `https://...`. See `Secrets.xcconfig.example`.
    var supabaseURL: URL {
        Self.supabaseURL(forRef: supabaseProjectRef)
    }

    /// The OAuth redirect URL the app registers and listens for.
    var oauthRedirectURL: URL {
        // Safe to force-unwrap a string we fully control; covered by tests.
        URL(string: "\(oauthCallbackScheme)://login-callback")! // swiftlint:disable:this force_unwrapping
    }

    /// Pure, testable URL construction.
    static func supabaseURL(forRef ref: String) -> URL {
        URL(string: "https://\(ref).supabase.co")! // swiftlint:disable:this force_unwrapping
    }

    /// Loads config from the app bundle's Info dictionary, validating that real values were set.
    static func loadFromBundle(_ bundle: Bundle = .main) throws -> AppConfig {
        // `placeholder` is the template value from Secrets.xcconfig.example. Pass nil for keys
        // whose default template value is also a valid real value (e.g. the OAuth scheme).
        func value(_ key: String, placeholder: String?) throws -> String {
            guard let raw = bundle.object(forInfoDictionaryKey: key) as? String,
                  !raw.isEmpty else {
                throw ConfigError.missing(key: key)
            }
            if let placeholder, raw == placeholder {
                throw ConfigError.placeholderValue(key: key)
            }
            return raw
        }

        return AppConfig(
            supabaseProjectRef: try value("SUPABASE_PROJECT_REF", placeholder: "your-project-ref"),
            supabaseAnonKey: try value("SUPABASE_ANON_KEY", placeholder: "your-anon-key"),
            oauthCallbackScheme: try value("OAUTH_CALLBACK_SCHEME", placeholder: nil)
        )
    }
}
