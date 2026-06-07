# Privacy & Data Policy

This document describes what SpotiStats stores, why, and how to remove it. Your listening history
is personal data and is treated as such.

## What we access (Spotify scopes)

SpotiStats requests the **minimum** Spotify permissions needed, and nothing else:

| Scope | Why it is needed |
|-------|------------------|
| `user-top-read` | To show your top tracks and artists (Spotify's own affinity windows). |
| `user-read-recently-played` | To collect your recently played tracks so the app can build real listening history over time. |

We do **not** request profile email, country, or subscription scopes unless a feature that needs
them is added — and if it is, this table is updated to justify it.

## What we store

- **Account:** a Supabase user id and your Spotify user id (to link your account and for support
  diagnostics), plus your Spotify display name / avatar for the profile screen.
- **Spotify credentials:** your Spotify refresh token, **encrypted at rest** (AES-GCM). It is only
  ever decrypted inside our backend functions to fetch your data. Short-lived access tokens are
  never written to disk on your device.
- **Play history:** the tracks you recently played (title, artist, album, artwork URL, duration,
  and when they were played). This is what powers your statistics.

## How statistics work (and their limits)

- **Top tracks/artists** come directly from Spotify's affinity windows (short / medium / longer
  term). These are Spotify's numbers, not ours.
- **Listening time, trends, and all-time stats** are computed only from the play history we collect
  **after you connect**. They therefore start at connection time, not at your account's beginning.
- **Listening time is an estimate.** Spotify reports that a track was played and when, but not
  whether you listened to the whole thing. Durations shown are labeled "estimated."
- The collector polls periodically. During very heavy listening some plays can fall out of
  Spotify's recent-tracks window before we capture them, so there may be small gaps.

## Your controls

- **Disconnect & forget credentials:** removes your stored Spotify refresh token and stops
  collection. To fully revoke the app's access to your Spotify account, also remove it from your
  Spotify account's "Apps with access" page.
- **Delete account:** permanently deletes your play history, stored credentials, and profile, and
  removes your account.

## Contact

This is a personal project. Questions can be directed to the repository owner.
