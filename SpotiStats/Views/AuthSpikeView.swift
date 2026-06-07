import Foundation
import Observation
import Supabase
import SwiftUI

// MARK: - Phase 0.5 auth/token PROOF spike
//
// This screen is TEMPORARY. Its only job is to prove the end-to-end auth/token spine works before
// we build the real app on top of it:
//
//   1. Sign in with Spotify (Supabase OAuth)         -> Supabase session + Spotify provider tokens
//   2. Capture provider_refresh_token                -> must be present (the linchpin assumption)
//   3. store-spotify-credentials                     -> encrypts + stores it server-side
//   4. refresh-spotify-token                         -> backend mints a fresh Spotify access token
//   5. Real Spotify API call with that token         -> proves the token actually works
//
// If all five pass, the architecture is sound and Phase 1 is mostly engineering. Once proven, this
// screen gets deleted.

// MARK: Request / response shapes

private struct StoreCredentialsBody: Encodable {
    let refreshToken: String
    let spotifyUserId: String?

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case spotifyUserId = "spotify_user_id"
    }
}

private struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

/// Decodes into "anything" — used when we only care that the call succeeded.
private struct EmptyResponse: Decodable {}

private struct RecentlyPlayedResponse: Decodable {
    let items: [Item]
    struct Item: Decodable { let track: Track }
    struct Track: Decodable { let name: String }
}

// MARK: View model

@MainActor
@Observable
final class AuthSpikeViewModel {
    private(set) var log: [String] = []
    private(set) var isRunning = false

    private var client: SupabaseClient?

    private func append(_ line: String) {
        log.append(line)
    }

    private func ensureClient() throws -> SupabaseClient {
        if let client { return client }
        let config = try AppConfig.loadFromBundle()
        let made = Backend.makeClient(config)
        client = made
        return made
    }

    /// On appear: report whether a persisted session was restored (proves Keychain persistence).
    func checkExistingSession() async {
        do {
            let client = try ensureClient()
            let session = try? await client.auth.session
            if let session {
                append("Restored persisted session for user \(session.user.id).")
            } else {
                append("No persisted session yet — tap Run to start.")
            }
        } catch {
            append("Config error: \(error.localizedDescription)")
        }
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        do {
            let client = try ensureClient()
            append("→ Step 1: Spotify sign-in…")
            let session = try await client.auth.signInWithOAuth(
                provider: .spotify,
                redirectTo: AppConfig.loadFromBundle().oauthRedirectURL,
                scopes: "user-top-read user-read-recently-played"
            )
            append("✓ Signed in. Supabase user: \(session.user.id)")

            append("→ Step 2: capture provider_refresh_token…")
            guard let providerRefresh = session.providerRefreshToken else {
                append("✗ No provider_refresh_token. Re-run forcing fresh consent (show_dialog=true).")
                return
            }
            append("✓ Got refresh token (\(providerRefresh.prefix(6))…)")

            append("→ Step 3: store-spotify-credentials (encrypt + store)…")
            let body = StoreCredentialsBody(refreshToken: providerRefresh, spotifyUserId: nil)
            let _: EmptyResponse = try await client.functions.invoke(
                "store-spotify-credentials",
                options: FunctionInvokeOptions(body: body)
            )
            append("✓ Stored encrypted credentials.")

            append("→ Step 4: refresh-spotify-token (backend mints access token)…")
            let refreshed: RefreshTokenResponse = try await client.functions.invoke(
                "refresh-spotify-token",
                options: FunctionInvokeOptions()
            )
            append("✓ Access token minted (expires in \(refreshed.expiresIn)s).")

            append("→ Step 5: real Spotify call with that token…")
            let count = try await fetchRecentlyPlayedCount(accessToken: refreshed.accessToken)
            append("✓ Spotify responded — \(count) recent track(s).")
            append("🎉 Auth spine PROVEN end-to-end.")
        } catch {
            append("✗ Error: \(error.localizedDescription)")
        }
    }

    private func fetchRecentlyPlayedCount(accessToken: String) async throws -> Int {
        let endpoint = "https://api.spotify.com/v1/me/player/recently-played?limit=5"
        guard let url = URL(string: endpoint) else { return 0 }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(RecentlyPlayedResponse.self, from: data)
        return decoded.items.count
    }
}

// MARK: View

struct AuthSpikeView: View {
    @State private var viewModel = AuthSpikeViewModel()

    var body: some View {
        ZStack {
            Theme.Colors.backgroundGradient.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("Auth Spike")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Phase 0.5 — prove the token spine")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ForEach(Array(viewModel.log.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                Button {
                    Task { await viewModel.run() }
                } label: {
                    Text(viewModel.isRunning ? "Running…" : "Run spike")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.background)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
                .disabled(viewModel.isRunning)
            }
            .padding(Theme.Spacing.lg)
        }
        .task { await viewModel.checkExistingSession() }
    }
}

#Preview {
    AuthSpikeView()
        .preferredColorScheme(.dark)
}
