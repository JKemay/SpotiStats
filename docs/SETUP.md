# Setup

End-to-end setup for building and running SpotiStats. Steps marked **(you)** require manual action
in a dashboard or on your Mac.

## 1. Toolchain (you, on the Mac)

- Install **Xcode 15+** from the App Store.
- Install tooling:
  ```sh
  brew install xcodegen swiftlint swift-format xcbeautify
  ```

## 2. Generate and open the project

```sh
xcodegen generate
cp SpotiStats/Resources/Secrets.xcconfig.example SpotiStats/Resources/Secrets.xcconfig
open SpotiStats.xcodeproj
```

Fill in `Secrets.xcconfig` after the Supabase steps below.

## 3. Spotify Developer app (you)

In the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard):

- Use your existing app (or create one).
- **Redirect URI:** add your Supabase auth callback:
  `https://<project-ref>.supabase.co/auth/v1/callback`
- Required scopes (least-privilege): `user-top-read`, `user-read-recently-played`.
- Note the **Client ID** and **Client Secret** (the secret is entered only in Supabase — never in
  the app or this repo).

## 4. Supabase project

The project is provisioned via the Supabase MCP. After it exists:

- **Auth → Providers → Spotify** (you): enable it, paste the Spotify **Client ID + Secret**.
- **Auth → URL Configuration** (you): add the app's redirect URL `spotistats://login-callback`
  to the allowed redirect list.
- **Edge Function secrets** (you/CLI): set
  - `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET` — for server-side token refresh + collection.
  - `TOKEN_ENCRYPTION_KEY` — a 32-byte key (base64) used to encrypt stored Spotify refresh tokens
    (AES-GCM). Generate with: `openssl rand -base64 32`.
- Copy the project **ref** and **anon key** into `Secrets.xcconfig`.

## 5. Run

Build and run on a simulator or a device (device builds need a Development Team set in Xcode).

## Notes

- `Secrets.xcconfig` and the generated `SpotiStats.xcodeproj` are git-ignored by design.
- CI generates the project, lints, builds, and tests on every push.
