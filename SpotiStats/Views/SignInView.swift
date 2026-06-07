import SwiftUI

/// The signed-out screen: a single "Connect Spotify" call to action that kicks off the OAuth flow.
struct SignInView: View {
    let auth: AuthService

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
                Text("SpotiStats")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Your music, after dark.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            if let error = auth.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await auth.connectSpotify() }
            } label: {
                Text(auth.isWorking ? "Connecting…" : "Connect Spotify")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.background)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
            .disabled(auth.isWorking)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
