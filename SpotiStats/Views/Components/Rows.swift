import SwiftUI

// The three list rows (top track, top artist, recent play) plus their shared pieces.
// They live together because they share the artwork/rank building blocks and must stay
// visually consistent — a spacing tweak here restyles every list in the app.

/// Square artwork thumbnail with a themed placeholder while loading (or when there's no image).
struct ArtworkThumbnail: View {
    let url: URL?
    var size: CGFloat = 48
    var cornerRadius: CGFloat = 8

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.Colors.surface
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// The list position, styled as a fixed-width neon rank so titles align vertically.
struct RankLabel: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Theme.Colors.accent)
            .frame(width: 28, alignment: .trailing)
    }
}

/// A top track: rank, album art, title + artists, and the track length.
struct TrackRow: View {
    let rank: Int
    let track: SpotifyTrack

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            RankLabel(rank: rank)
            ArtworkThumbnail(url: track.album.images.thumbnailURL)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(track.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if track.explicit {
                        ExplicitBadge()
                    }
                }
                Text(track.artistNames)
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.durationMs.asTrackLength)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

/// A top artist: rank, photo, name, and up to two genres.
struct ArtistRow: View {
    let rank: Int
    let artist: SpotifyArtist

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            RankLabel(rank: rank)
            ArtworkThumbnail(url: artist.images.thumbnailURL, cornerRadius: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                if !artist.genres.isEmpty {
                    Text(artist.genres.prefix(2).joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

/// A recent play: album art, title + artists, and a relative "when" (omitted if unparseable).
struct RecentlyPlayedRow: View {
    let item: PlayHistoryItem

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ArtworkThumbnail(url: item.track.album.images.thumbnailURL)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(item.track.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if item.track.explicit {
                        ExplicitBadge()
                    }
                }
                Text(item.track.artistNames)
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if let playedAt = item.playedAtDate {
                Text(playedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

/// Spotify-style "E" marker for explicit tracks.
struct ExplicitBadge: View {
    var body: some View {
        Text("E")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Theme.Colors.background)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(Theme.Colors.textSecondary, in: RoundedRectangle(cornerRadius: 3))
            .accessibilityLabel("Explicit")
    }
}
