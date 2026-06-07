import XCTest
@testable import SpotiStats

/// Tests the in-memory access-token caching/expiry logic. The backend is stubbed and the clock is
/// injected, so we can prove the caching rules without a live Supabase client or real waiting.
final class SpotifyTokenProviderTests: XCTestCase {

    /// Hands out incrementing tokens and counts how often a mint was requested.
    final class StubBackend: SpotifyCredentialsBackend {
        private(set) var mintCount = 0
        private(set) var storedRefreshTokens: [String] = []
        var expiresIn: TimeInterval = 3600

        func storeRefreshToken(_ refreshToken: String, spotifyUserID: String?) async throws {
            storedRefreshTokens.append(refreshToken)
        }

        func mintAccessToken() async throws -> MintedToken {
            mintCount += 1
            return MintedToken(token: "token-\(mintCount)", expiresIn: expiresIn)
        }
    }

    @MainActor
    func testFirstAccessTokenMintsThenCaches() async throws {
        let backend = StubBackend()
        let provider = SpotifyTokenProvider(backend: backend)

        let first = try await provider.accessToken()
        let second = try await provider.accessToken()

        XCTAssertEqual(first, "token-1")
        XCTAssertEqual(second, "token-1")
        XCTAssertEqual(backend.mintCount, 1)
    }

    @MainActor
    func testExpiredTokenIsReminted() async throws {
        let backend = StubBackend()
        backend.expiresIn = 60
        var fakeNow = Date(timeIntervalSince1970: 0)
        let provider = SpotifyTokenProvider(backend: backend, now: { fakeNow })

        _ = try await provider.accessToken()
        fakeNow = fakeNow.addingTimeInterval(120) // past expiry
        _ = try await provider.accessToken()

        XCTAssertEqual(backend.mintCount, 2)
    }

    @MainActor
    func testTokenWithinLeewayIsTreatedAsExpired() async throws {
        let backend = StubBackend()
        backend.expiresIn = 10 // shorter than the 30s leeway
        let provider = SpotifyTokenProvider(backend: backend)

        _ = try await provider.accessToken()
        _ = try await provider.accessToken()

        XCTAssertEqual(backend.mintCount, 2)
    }

    @MainActor
    func testRefreshedAccessTokenAlwaysMints() async throws {
        let backend = StubBackend()
        let provider = SpotifyTokenProvider(backend: backend)

        _ = try await provider.accessToken()
        _ = try await provider.refreshedAccessToken()

        XCTAssertEqual(backend.mintCount, 2)
    }

    @MainActor
    func testClearForcesRemint() async throws {
        let backend = StubBackend()
        let provider = SpotifyTokenProvider(backend: backend)

        _ = try await provider.accessToken()
        provider.clear()
        _ = try await provider.accessToken()

        XCTAssertEqual(backend.mintCount, 2)
    }
}
