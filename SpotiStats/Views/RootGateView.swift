import Observation
import SwiftUI

/// Decides what to show based on auth state: a loading indicator while we check for a restored
/// session, the sign-in screen when signed out, and the tab shell once signed in.
struct RootGateView: View {
    @State private var model = RootGateModel()

    var body: some View {
        ZStack {
            NightCityBackground()
            content
        }
        .task { await model.start() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView().tint(Theme.Colors.accent)
        case .configError(let message):
            errorView(message)
        case .ready(let auth):
            ready(auth)
        }
    }

    @ViewBuilder
    private func ready(_ auth: AuthService) -> some View {
        switch auth.state {
        case .unknown:
            ProgressView().tint(Theme.Colors.accent)
        case .signedOut:
            SignInView(auth: auth)
        case .signedIn:
            MainTabView()
                .environment(auth)
                .environment(\.spotifyAPI, model.spotifyAPI)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.Colors.accent)
            Text("Configuration error")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }
}

/// Creates the `AuthService` (surfacing config errors) and restores any persisted session.
@MainActor
@Observable
final class RootGateModel {
    enum Phase {
        case loading
        case configError(String)
        case ready(AuthService)
    }

    private(set) var phase: Phase = .loading

    /// The one live Spotify client, built alongside `AuthService` and held here so it isn't
    /// recreated on every render. Until sign-in completes, the unconfigured default just throws.
    private(set) var spotifyAPI: any SpotifyAPI = UnconfiguredSpotifyAPI()

    func start() async {
        if case .ready = phase { return }
        do {
            let auth = try AuthService.live()
            spotifyAPI = SpotifyAPIClient(tokenProvider: auth.tokenProvider)
            phase = .ready(auth)
            await auth.restoreSession()
        } catch {
            phase = .configError(error.localizedDescription)
        }
    }
}
