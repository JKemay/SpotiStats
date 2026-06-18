import Foundation
import Observation

/// Drives the Artists tab: top artists for the selected Spotify affinity window.
@MainActor
@Observable
final class ArtistsViewModel {
    var selectedRange: SpotifyTimeRange = .shortTerm
    private(set) var state: LoadState<[SpotifyArtist]> = .idle

    func load(using api: any SpotifyAPI) async {
        state = .loading
        do {
            // 50 is Spotify's per-request maximum for the top-items endpoint.
            state = .loaded(try await api.topArtists(range: selectedRange, limit: 50))
        } catch {
            state = .failed(UserFacingError.message(for: error))
        }
    }
}
