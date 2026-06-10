import XCTest
@testable import SpotiStats

/// Behavior tests for `SpotifyAPIClient`: request construction, auth header, and the 401/429 retry
/// rules. All HTTP is stubbed via `MockURLProtocol`, so these run fast and offline.
final class SpotifyAPIClientTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeClient(tokenProvider: SpotifyTokenProviding) -> SpotifyAPIClient {
        SpotifyAPIClient(tokenProvider: tokenProvider, session: .mocked())
    }

    func testTopTracksHitsCorrectEndpointWithTokenAndQuery() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = try makeHTTPResponse(url: request.url, status: 200)
            return (response, Data(SpotifyFixtures.topTracks.utf8))
        }

        let client = makeClient(tokenProvider: StubTokenProvider())
        let tracks = try await client.topTracks(range: .mediumTerm, limit: 10)

        XCTAssertEqual(tracks.count, 2)
        let url = try XCTUnwrap(MockURLProtocol.capturedRequests.last?.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "/v1/me/top/tracks")
        let queryItems = components.queryItems ?? []
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "time_range", value: "medium_term")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "limit", value: "10")))
        let auth = MockURLProtocol.capturedRequests.last?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(auth, "Bearer tok-initial")
    }

    func test401RefreshesTokenAndRetriesOnce() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            if callCount == 1 {
                let unauthorized = try makeHTTPResponse(url: request.url, status: 401)
                return (unauthorized, Data("{}".utf8))
            }
            let success = try makeHTTPResponse(url: request.url, status: 200)
            return (success, Data(SpotifyFixtures.topArtists.utf8))
        }

        let provider = StubTokenProvider()
        let client = makeClient(tokenProvider: provider)
        let artists = try await client.topArtists(range: .shortTerm)

        XCTAssertEqual(artists.count, 2)
        XCTAssertEqual(provider.refreshCallCount, 1)
        XCTAssertEqual(callCount, 2)
        let lastAuth = MockURLProtocol.capturedRequests.last?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(lastAuth, "Bearer tok-refreshed")
    }

    func testPersistent401ThrowsUnauthorizedAfterOneRefresh() async {
        MockURLProtocol.requestHandler = { request in
            let unauthorized = try makeHTTPResponse(url: request.url, status: 401)
            return (unauthorized, Data("{}".utf8))
        }

        let provider = StubTokenProvider()
        let client = makeClient(tokenProvider: provider)
        do {
            _ = try await client.recentlyPlayed()
            XCTFail("Expected unauthorized error")
        } catch let error as SpotifyAPIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(provider.refreshCallCount, 1)
    }

    func test429RetriesHonoringRetryAfterThenSucceeds() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            if callCount == 1 {
                let limited = try makeHTTPResponse(
                    url: request.url,
                    status: 429,
                    headers: ["Retry-After": "0"]
                )
                return (limited, Data())
            }
            let success = try makeHTTPResponse(url: request.url, status: 200)
            return (success, Data(SpotifyFixtures.topTracks.utf8))
        }

        let client = makeClient(tokenProvider: StubTokenProvider())
        let tracks = try await client.topTracks(range: .longTerm)

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(callCount, 2)
    }

    func testPersistent429ThrowsRateLimited() async {
        MockURLProtocol.requestHandler = { request in
            let limited = try makeHTTPResponse(
                url: request.url,
                status: 429,
                headers: ["Retry-After": "0"]
            )
            return (limited, Data())
        }

        let client = makeClient(tokenProvider: StubTokenProvider())
        do {
            _ = try await client.topTracks(range: .shortTerm)
            XCTFail("Expected rateLimited error")
        } catch let error as SpotifyAPIError {
            XCTAssertEqual(error, .rateLimited(retryAfter: 0))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testServerErrorThrowsHTTPStatus() async {
        MockURLProtocol.requestHandler = { request in
            let serverError = try makeHTTPResponse(url: request.url, status: 500)
            return (serverError, Data())
        }

        let client = makeClient(tokenProvider: StubTokenProvider())
        do {
            _ = try await client.topArtists(range: .mediumTerm)
            XCTFail("Expected http error")
        } catch let error as SpotifyAPIError {
            XCTAssertEqual(error, .http(status: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
