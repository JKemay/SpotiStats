import XCTest
@testable import SpotiStats

/// Tests for the pure configuration logic.
///
/// We deliberately test the parts that don't need a real app bundle. This is the habit:
/// keep logic pure where you can, so it's trivial to test.
final class AppConfigTests: XCTestCase {

    func testSupabaseURLIsBuiltFromRef() {
        let url = AppConfig.supabaseURL(forRef: "abcdefghijklmnop")
        XCTAssertEqual(url.absoluteString, "https://abcdefghijklmnop.supabase.co")
    }

    func testOAuthRedirectURLUsesScheme() {
        let config = AppConfig(
            supabaseProjectRef: "ref",
            supabaseAnonKey: "key",
            oauthCallbackScheme: "spotistats"
        )
        XCTAssertEqual(config.oauthRedirectURL.absoluteString, "spotistats://login-callback")
    }

    func testSupabaseURLComputedPropertyMatchesStaticBuilder() {
        let config = AppConfig(
            supabaseProjectRef: "myref",
            supabaseAnonKey: "key",
            oauthCallbackScheme: "spotistats"
        )
        XCTAssertEqual(config.supabaseURL, AppConfig.supabaseURL(forRef: "myref"))
    }
}
