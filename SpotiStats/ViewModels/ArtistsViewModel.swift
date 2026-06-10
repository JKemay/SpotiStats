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
            state = .loaded(try await api.topArtists(range: selectedRange))
        } catch {
            state = .failed(UserFacingError.message(for: error))
        }
    }
}
