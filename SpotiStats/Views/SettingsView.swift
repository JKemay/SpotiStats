import SwiftUI

/// The Settings tab: account controls (sign out, for now) and app info.
///
/// Phase 3.5 will grow this into full privacy controls ("Disconnect & forget credentials",
/// "Delete account"), so account actions get a tab rather than a buried toolbar button.
struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundGradient.ignoresSafeArea()
                List {
                    Section("Account") {
                        Button(role: .destructive) {
                            confirmingSignOut = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .disabled(auth.isWorking)
                    }
                    .listRowBackground(Theme.Colors.surface)

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
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Sign out of SpotiStats?",
                isPresented: $confirmingSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await auth.signOut() }
                }
            } message: {
                Text("Your Spotify connection stays on the server; signing back in picks up where you left off.")
            }
        }
    }

    /// The marketing version from the bundle ("0.1.0"); a placeholder only in odd test contexts.
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
