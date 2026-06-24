import SwiftUI

/// The signed-out screen: branded hero, three value-prop rows, and the "Connect Spotify" CTA.
struct SignInView: View {
    let auth: AuthService

    var body: some View {
        ZStack {
            NightCityBackground()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: Theme.Spacing.xl)

                    heroSection
                        .padding(.bottom, Theme.Spacing.xl)

                    valuePropSection
                        .padding(.bottom, Theme.Spacing.xl)

                    Spacer(minLength: Theme.Spacing.xl)

                    footerSection
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Colors.accent, Theme.Colors.accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, Theme.Spacing.xs)

            Text(AppInfo.name)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Your music, after dark.")
                .font(.title3)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var valuePropSection: some View {
        VStack(spacing: 0) {
            ValuePropRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Your real listening history",
                detail: "We collect every play so your stats grow over time."
            )

            Divider()
                .background(Theme.Colors.accent.opacity(0.15))
                .padding(.leading, Theme.Spacing.xl + Theme.Spacing.lg)

            ValuePropRow(
                icon: "music.note.list",
                title: "Top tracks, artists & albums",
                detail: "Across Spotify's windows and your own play counts."
            )

            Divider()
                .background(Theme.Colors.accent.opacity(0.15))
                .padding(.leading, Theme.Spacing.xl + Theme.Spacing.lg)

            ValuePropRow(
                icon: "lock.shield",
                title: "Private by design",
                detail: "Your Spotify token is encrypted; disconnect or delete anytime."
            )
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surface.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .strokeBorder(Theme.Colors.accent.opacity(0.18), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var footerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let error = auth.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await auth.connectSpotify() }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    if auth.isWorking {
                        ProgressView()
                            .tint(Theme.Colors.background)
                            .scaleEffect(0.85)
                    }
                    Text(auth.isWorking ? "Connecting…" : "Connect Spotify")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.background)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)
                .background(
                    Theme.Colors.accent,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card)
                )
            }
            .disabled(auth.isWorking)

            Text("Listening time is estimated and starts when you connect.")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - Value prop row

private struct ValuePropRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: Theme.Spacing.xl, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    // AuthService.live() reads bundled config; falls back to a stub placeholder in preview
    // harnesses that don't bundle the real Secrets.xcconfig.
    if let auth = try? AuthService.live() {
        SignInView(auth: auth)
            .preferredColorScheme(.dark)
    } else {
        Text("Preview unavailable — Secrets.xcconfig not bundled")
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)
            .preferredColorScheme(.dark)
    }
}
