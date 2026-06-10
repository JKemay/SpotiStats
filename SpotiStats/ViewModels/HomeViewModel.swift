import Foundation
import Observation

/// Drives the Home tab: the user's recently played tracks.
///
/// The API client arrives as a `load(using:)` parameter (not stored) because the view owns the
/// model with `@State` but the client lives in the SwiftUI environment — passing it per-call
/// keeps the model free of environment plumbing and trivially testable with a `MockSpotifyAPI`.
@MainActor
@Observable
final class HomeViewModel {
    private(set) var state: LoadState<[PlayHistoryItem]> = .idle

    func load(using api: any SpotifyAPI) async {
        state = .loading
        do {
            state = .loaded(try await api.recentlyPlayed())
        } catch {
            state = .failed(UserFacingError.message(for: error))
        }
    }
}
