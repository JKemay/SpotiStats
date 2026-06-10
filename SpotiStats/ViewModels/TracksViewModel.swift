import Foundation
import Observation

/// Drives the Tracks tab: top tracks for the selected Spotify affinity window.
///
/// The view re-runs `load` whenever `selectedRange` changes (via `.task(id:)`), so this model
/// just exposes the selection and fetches — no change-observation logic needed here.
@MainActor
@Observable
final class TracksViewModel {
    var selectedRange: SpotifyTimeRange = .shortTerm
    private(set) var state: LoadState<[SpotifyTrack]> = .idle

    func load(using api: any SpotifyAPI) async {
        state = .loading
        do {
            state = .loaded(try await api.topTracks(range: selectedRange))
        } catch {
            state = .failed(UserFacingError.message(for: error))
        }
    }
}
