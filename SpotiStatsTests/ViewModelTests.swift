import XCTest
@testable import SpotiStats

/// Each tab's view model must reach `.loaded` on success and `.failed` (with a friendly message)
/// on error. The API is the scriptable `MockSpotifyAPI`, so no networking is involved.
final class ViewModelTests: XCTestCase {

    // MARK: Home

    @MainActor
    func testHomeLoadSuccess() async {
        let api = MockSpotifyAPI()
        api.recentlyPlayedResult = .success([SampleModels.playHistoryItem])
        let viewModel = HomeViewModel()

        await viewModel.load(using: api)

        XCTAssertEqual(viewModel.state, .loaded([SampleModels.playHistoryItem]))
        XCTAssertEqual(api.recentlyPlayedCallCount, 1)
    }

    @MainActor
    func testHomeLoadFailureIsOfflineFriendly() async {
        let api = MockSpotifyAPI()
        api.recentlyPlayedResult = .failure(URLError(.notConnectedToInternet))
        let viewModel = HomeViewModel()

        await viewModel.load(using: api)

        XCTAssertEqual(viewModel.state, .failed("You're offline. Check your connection and retry."))
    }

    // MARK: Tracks

    @MainActor
    func testTracksLoadSuccessUsesSelectedRange() async {
        let api = MockSpotifyAPI()
        api.topTracksResult = .success([SampleModels.track])
        let viewModel = TracksViewModel()
        viewModel.selectedRange = .longTerm

        await viewModel.load(using: api)

        XCTAssertEqual(viewModel.state, .loaded([SampleModels.track]))
        XCTAssertEqual(api.requestedTrackRanges, [.longTerm])
    }

    @MainActor
    func testTracksLoadFailure() async {
        let api = MockSpotifyAPI()
        api.topTracksResult = .failure(SpotifyAPIError.unauthorized)
        let viewModel = TracksViewModel()

        await viewModel.load(using: api)

        XCTAssertEqual(viewModel.state, .failed("Your Spotify session expired. Try signing out and back in."))
    }

    // MARK: Artists

    @MainActor
    func testArtistsLoadSuccessUsesSelectedRange() async {
        let api = MockSpotifyAPI()
        api.topArtistsResult = .success([SampleModels.artist])
        let viewModel = ArtistsViewModel()
        viewModel.selectedRange = .mediumTerm

        await viewModel.load(using: api)

        XCTAssertEqual(viewModel.state, .loaded([SampleModels.artist]))
        XCTAssertEqual(api.requestedArtistRanges, [.mediumTerm])
    }

    @MainActor
    func testArtistsLoadFailure() async {
        let api = MockSpotifyAPI()
        api.topArtistsResult = .failure(SpotifyAPIError.rateLimited(retryAfter: 5))
        let viewModel = ArtistsViewModel()

        await viewModel.load(using: api)

        XCTAssertEqual(viewModel.state, .failed("Spotify is busy right now. Give it a moment, then retry."))
    }

    // MARK: Reload after failure

    @MainActor
    func testReloadAfterFailureRecovers() async {
        let api = MockSpotifyAPI()
        api.recentlyPlayedResult = .failure(URLError(.timedOut))
        let viewModel = HomeViewModel()

        await viewModel.load(using: api)
        XCTAssertEqual(viewModel.state, .failed("The request timed out. Please retry."))

        api.recentlyPlayedResult = .success([SampleModels.playHistoryItem])
        await viewModel.load(using: api)
        XCTAssertEqual(viewModel.state, .loaded([SampleModels.playHistoryItem]))
    }

    // MARK: Unconfigured default

    @MainActor
    func testUnconfiguredAPISurfacesAsFailure() async {
        let viewModel = HomeViewModel()

        await viewModel.load(using: UnconfiguredSpotifyAPI())

        guard case .failed = viewModel.state else {
            return XCTFail("Expected .failed, got \(viewModel.state)")
        }
    }
}
