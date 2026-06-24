import SwiftUI

/// The Settings tab: account, privacy controls, and app info.
///
/// Privacy controls (Phase 3.5) match PRIVACY.md: "Disconnect & forget credentials" deletes the
/// stored Spotify token (and stops collection) but keeps play history; "Delete account"
/// irreversibly wipes everything. Both are destructive, so each is gated behind a confirmation.
struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.spotifyAPI) private var spotifyAPI
    @State private var confirmingSignOut = false
    @State private var confirmingDisconnect = false
    @State private var confirmingDelete = false
    @State private var profileUser: SpotifyUser?
    @State private var profileLoading = true

    /// Spotify's "Apps with access" page — true revocation of the app's Spotify access happens
    /// there (disconnecting only forgets our stored token).
    private static let spotifyAppsURL = URL(string: "https://www.spotify.com/account/apps/")

    var body: some View {
        NavigationStack {
            ZStack {
                NightCityBackground()
                List {
                    if profileLoading || profileUser != nil {
                        profileSection
                    }
                    accountSection
                    privacySection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .task {
                do {
                    profileUser = try await spotifyAPI.currentUser()
                } catch {
                    // Silently omit the profile header on failure — Settings must always work.
                }
                profileLoading = false
            }
            .confirmationDialog(
                "Sign out of \(AppInfo.name)?",
                isPresented: $confirmingSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    HapticManager.shared.notification(.warning)
                    Task { await auth.signOut() }
                }
            } message: {
                Text("Your Spotify connection stays on the server; signing back in picks up where you left off.")
            }
            .confirmationDialog(
                "Disconnect Spotify?",
                isPresented: $confirmingDisconnect,
                titleVisibility: .visible
            ) {
                Button("Disconnect", role: .destructive) {
                    HapticManager.shared.notification(.warning)
                    Task { await auth.disconnectSpotify() }
                }
            } message: {
                Text(
                    "This deletes your stored Spotify token and stops collection. Your existing "
                    + "history is kept. You'll be signed out and can reconnect any time."
                )
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    HapticManager.shared.notification(.error)
                    Task { await auth.deleteAccount() }
                }
            } message: {
                Text(
                    "This permanently erases your play history, stored credentials, and profile. "
                    + "This cannot be undone."
                )
            }
        }
    }

    private var profileSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.md) {
                profileAvatar
                Text(profileUser?.displayName ?? (profileLoading ? "" : "Spotify user"))
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .redacted(reason: profileLoading ? .placeholder : [])
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .listRowBackground(Theme.Colors.surface)
    }

    private var profileAvatar: some View {
        let size: CGFloat = 52
        return AsyncImage(url: profileUser?.avatarURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.Colors.surface
                    if profileLoading {
                        Color.gray.opacity(0.3)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .redacted(reason: profileLoading ? .placeholder : [])
    }

    private var accountSection: some View {
        Section("Account") {
            Button(role: .destructive) {
                confirmingSignOut = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .disabled(auth.isWorking)
        }
        .listRowBackground(Theme.Colors.surface)
    }

    private var privacySection: some View {
        Section {
            Button {
                confirmingDisconnect = true
            } label: {
                Label("Disconnect Spotify", systemImage: "bolt.horizontal.circle")
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .disabled(auth.isWorking)

            if let url = Self.spotifyAppsURL {
                Link(destination: url) {
                    Label("Manage access on Spotify", systemImage: "arrow.up.right.square")
                        .foregroundStyle(Theme.Colors.accent)
                }
            }

            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete Account", systemImage: "trash")
            }
            .disabled(auth.isWorking)
        } header: {
            Text("Privacy & data")
        } footer: {
            Text(
                "Disconnect forgets your stored Spotify token and stops collection (history kept). "
                + "To fully revoke access, also remove \(AppInfo.name) from your Spotify apps. "
                + "Delete Account erases everything, permanently."
            )
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .listRowBackground(Theme.Colors.surface)
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Self.appVersion)
                .foregroundStyle(Theme.Colors.textSecondary)
        } header: {
            Text("About")
        } footer: {
            Text(
                "Top tracks and artists come from Spotify's affinity windows; "
                + "they are rankings, not lifetime play counts."
            )
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .listRowBackground(Theme.Colors.surface)
    }

    /// The marketing version from the bundle ("0.1.0"); a placeholder only in odd test contexts.
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
