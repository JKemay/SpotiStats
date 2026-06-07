# SpotiStats

A Spotify listening-analytics app for iOS. It shows your top tracks and artists, your recently
played songs, and listening statistics that build up over time from your own play history.

> **Status:** early development. The name shown here is a working codename and will change before
> any public release.

## Why this exists

The Spotify Web API only exposes top items over a few fixed windows and your most recent ~50
plays. It does not expose true long-term listening history or accurate "time listened." SpotiStats
solves this the way analytics apps do in practice: a small backend service **continuously collects
your recently-played tracks and stores them**, so real history and statistics accrue over time.

## Architecture

```
  iOS app (SwiftUI + MVVM)            Supabase backend
  ------------------------            ----------------------------
  Views  -> ViewModels  -> Services   Postgres (history, profiles)
                              |        Auth (Spotify sign-in)
                              |        Edge Functions (token + collector)
                              v        pg_cron (scheduled collection)
                         Supabase / Spotify Web API
```

- **iOS:** SwiftUI, MVVM, modern Swift concurrency (`async/await`, `@Observable`), protocol-driven
  services with dependency injection. Networking via `URLSession` + `Codable`. Secure session
  storage in the Keychain.
- **Backend:** Supabase. Handles Spotify sign-in, owns the Spotify token lifecycle (refresh tokens
  are encrypted at rest), and runs a scheduled "collector" that records play history.

See [`docs`](docs/) and the in-repo design notes for details. Data handling is documented in
[`PRIVACY.md`](PRIVACY.md).

## Requirements

- macOS with **Xcode 15+** (iOS 17 deployment target).
- [**XcodeGen**](https://github.com/yonsm/XcodeGen) (`brew install xcodegen`) — the Xcode project is
  generated from [`project.yml`](project.yml), so it is never hand-edited or committed.
- A **Supabase** project and a **Spotify Developer** app (see Setup).

## Setup

1. Generate the Xcode project:
   ```sh
   xcodegen generate
   open SpotiStats.xcodeproj
   ```
2. Copy the secrets template and fill in your values (this file is git-ignored):
   ```sh
   cp SpotiStats/Resources/Secrets.xcconfig.example SpotiStats/Resources/Secrets.xcconfig
   ```
3. Configure Supabase Auth (Spotify provider) and the Edge Function secrets — see
   [`docs/SETUP.md`](docs/SETUP.md).
4. Build and run on a simulator or device.

## Development

- Lint: `swiftlint`
- Format: `swift-format format -i -r SpotiStats`
- Tests: run from Xcode (Cmd-U) or `xcodebuild test` (see CI).

CI runs build, tests, and lint on every push.

## License

TBD.
