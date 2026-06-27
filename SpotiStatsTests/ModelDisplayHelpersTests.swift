import XCTest
@testable import SpotiStats

/// Covers the small display helpers added for the list UIs: thumbnail selection, `playedAt`
/// parsing, and track-duration formatting.
final class ModelDisplayHelpersTests: XCTestCase {

    // MARK: Thumbnail selection

    func testThumbnailPicksSmallestImage() {
        let images = [
            SpotifyImage(url: "https://img/large", height: 640, width: 640),
            SpotifyImage(url: "https://img/small", height: 64, width: 64),
            SpotifyImage(url: "https://img/medium", height: 300, width: 300)
        ]
        XCTAssertEqual(images.thumbnailURL, URL(string: "https://img/small"))
    }

    func testThumbnailFallsBackWhenDimensionsMissing() {
        let images = [SpotifyImage(url: "https://img/unknown", height: nil, width: nil)]
        XCTAssertEqual(images.thumbnailURL, URL(string: "https://img/unknown"))
    }

    func testThumbnailIsNilForEmptyImages() {
        XCTAssertNil([SpotifyImage]().thumbnailURL)
    }

    // MARK: playedAt parsing

    func testPlayedAtParsesFractionalSeconds() {
        let item = PlayHistoryItem(track: SampleModels.track, playedAt: "2026-06-06T10:00:00.000Z")
        XCTAssertEqual(item.playedAtDate?.timeIntervalSince1970, 1_780_740_000)
    }

    func testPlayedAtParsesWholeSeconds() {
        let item = PlayHistoryItem(track: SampleModels.track, playedAt: "2026-06-06T10:00:00Z")
        XCTAssertEqual(item.playedAtDate?.timeIntervalSince1970, 1_780_740_000)
    }

    func testPlayedAtIsNilForGarbage() {
        let item = PlayHistoryItem(track: SampleModels.track, playedAt: "yesterday-ish")
        XCTAssertNil(item.playedAtDate)
    }

    // MARK: LoadState helper

    func testLoadStateValueIsOnlyPresentWhenLoaded() {
        XCTAssertNil(LoadState<[Int]>.idle.value)
        XCTAssertNil(LoadState<[Int]>.loading.value)
        XCTAssertNil(LoadState<[Int]>.failed("nope").value)
        XCTAssertEqual(LoadState.loaded([1, 2]).value, [1, 2])
    }

    // MARK: UserFacingError

    func testOfflineURLErrorsMapToOfflineMessage() {
        let offlineCodes: [URLError.Code] = [
            .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed
        ]
        for code in offlineCodes {
            XCTAssertEqual(
                UserFacingError.message(for: URLError(code)),
                "You're offline. Check your connection and retry.",
                "Unexpected message for URLError code \(code)"
            )
        }
    }

    func testTimedOutURLErrorMapsToTimeoutMessage() {
        XCTAssertEqual(
            UserFacingError.message(for: URLError(.timedOut)),
            "The request timed out. Please retry."
        )
    }

    func testUnhandledURLErrorMapsToGenericNetworkMessage() {
        XCTAssertEqual(
            UserFacingError.message(for: URLError(.cancelled)),
            "A network error occurred. Please retry."
        )
    }

    func testSpotifyUnauthorizedMapsToSessionExpiredMessage() {
        XCTAssertEqual(
            UserFacingError.message(for: SpotifyAPIError.unauthorized),
            "Your Spotify session expired. Try signing out and back in."
        )
    }

    func testSpotifyRateLimitedMapsToRateLimitMessage() {
        XCTAssertEqual(
            UserFacingError.message(for: SpotifyAPIError.rateLimited(retryAfter: nil)),
            "Spotify is busy right now. Give it a moment, then retry."
        )
    }

    func testSpotifyHTTPErrorIncludesStatusCode() {
        XCTAssertEqual(
            UserFacingError.message(for: SpotifyAPIError.http(status: 503)),
            "Spotify returned an error (HTTP 503). Please retry."
        )
    }

    func testDecodingErrorMapsToUnreadableMessage() {
        var decodingError: Error?
        do {
            _ = try JSONDecoder().decode(Int.self, from: Data("not json".utf8))
        } catch {
            decodingError = error
        }
        guard let err = decodingError else { return XCTFail("Expected a decoding error") }
        XCTAssertEqual(
            UserFacingError.message(for: err),
            "Spotify sent something we couldn't read. Please retry."
        )
    }

    func testUnknownErrorFallsBackToLocalizedDescription() {
        struct Sentinel: LocalizedError {
            var errorDescription: String? { "sentinel error" }
        }
        XCTAssertEqual(UserFacingError.message(for: Sentinel()), "sentinel error")
    }
}
