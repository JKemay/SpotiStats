import XCTest
@testable import SpotiStats

/// Each tab's view model must reach `.loaded` on success and `.failed` (with a friendly message)
/// on error. Tracks/Artists use the scriptable `MockSpotifyAPI`; Home (a dashboard over our own
/// collected data) uses `MockStatsProvider`. No networking is involved.
final class ViewModelTests: XCTestCase {

    // MARK: Home (dashboard over collected data)

    @MainActor
    func testHomeLoadSuccessAssemblesDashboard() async {
        let provider = MockStatsProvider()
        provider.overviewResult = .success(StatsSamples.overview)
        provider.topTracksResult = .success([StatsSamples.track])
        provider.recentPlaysResult = .success([StatsSamples.recentPlay])
        let viewModel = HomeViewModel()

        await viewModel.load(using: provider)

        guard case .loaded(let dashboard) = viewModel.state else {
            return XCTFail("Expected .loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(dashboard.week, StatsSamples.overview)
        XCTAssertEqual(dashboard.onRepeat, StatsSamples.track)   // first of topTracks(days:7, limit:1)
        XCTAssertEqual(dashboard.recent, [StatsSamples.recentPlay])
        XCTAssertEqual(provider.requestedOverviewDays, [7])      // this-week snapshot
        XCTAssertEqual(provider.requestedTopTrackDays, [7])      // on-repeat window
        XCTAssertEqual(provider.requestedRecentLimits, [25])
    }

    @MainActor
    func testHomeEmptyDataStaysLoadedForGatheringState() async {
        let provider = MockStatsProvider() // all defaults: empty overview, no recent
        let viewModel = HomeViewModel()

        await viewModel.load(using: provider)

        guard case .loaded(let dashboard) = viewModel.state else {
            return XCTFail("Expected .loaded, got \(viewModel.state)")
        }
        XCTAssertTrue(dashboard.isEmpty)
        XCTAssertNil(dashboard.onRepeat)
    }

    @MainActor
    func testHomeLoadFailureIsOfflineFriendly() async {
        let provider = MockStatsProvider()
        provider.recentPlaysResult = .failure(URLError(.notConnectedToInternet))
        let viewModel = HomeViewModel()

        await viewModel.load(using: provider)

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
    func testHomeReloadAfterFailureRecovers() async {
        let provider = MockStatsProvider()
        provider.recentPlaysResult = .failure(URLError(.timedOut))
        let viewModel = HomeViewModel()

        await viewModel.load(using: provider)
        XCTAssertEqual(viewModel.state, .failed("The request timed out. Please retry."))

        provider.recentPlaysResult = .success([StatsSamples.recentPlay])
        await viewModel.load(using: provider)
        guard case .loaded(let dashboard) = viewModel.state else {
            return XCTFail("Expected .loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(dashboard.recent, [StatsSamples.recentPlay])
    }

    // MARK: Unconfigured default

    @MainActor
    func testUnconfiguredProviderSurfacesAsFailure() async {
        let viewModel = HomeViewModel()

        await viewModel.load(using: UnconfiguredStatsProvider())

        guard case .failed = viewModel.state else {
            return XCTFail("Expected .failed, got \(viewModel.state)")
        }
    }
}
