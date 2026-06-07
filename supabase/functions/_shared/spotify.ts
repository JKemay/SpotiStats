// Spotify token + API helpers used by the Edge Functions.

/// Raised when Spotify rejects the refresh token (e.g. `invalid_grant`), meaning the user must
/// reconnect. The collector and the interactive refresh both use this to flip `reauth_required`.
export class SpotifyAuthError extends Error {
    constructor(public code: string, message: string) {
        super(message);
        this.name = "SpotifyAuthError";
    }
}

export interface RefreshResult {
    accessToken: string;
    expiresIn: number; // seconds
    expiresAt: number; // epoch milliseconds
    /// Present ONLY when Spotify rotates the refresh token; persist it when it appears.
    newRefreshToken?: string;
    scope?: string;
}

function clientCredentials(): { id: string; secret: string } {
    const id = Deno.env.get("SPOTIFY_CLIENT_ID");
    const secret = Deno.env.get("SPOTIFY_CLIENT_SECRET");
    if (!id || !secret) throw new Error("SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET not set");
    return { id, secret };
}

/// Exchanges a refresh token for a fresh access token.
/// Throws `SpotifyAuthError` on auth failures (so callers can mark the user for re-auth).
export async function refreshSpotifyAccessToken(refreshToken: string): Promise<RefreshResult> {
    const { id, secret } = clientCredentials();

    const res = await fetch("https://accounts.spotify.com/api/token", {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            Authorization: "Basic " + btoa(`${id}:${secret}`),
        },
        body: new URLSearchParams({
            grant_type: "refresh_token",
            refresh_token: refreshToken,
        }),
    });

    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
        const code = (data?.error as string) ?? `http_${res.status}`;
        const message = (data?.error_description as string) ?? `Spotify token refresh failed (${res.status})`;
        throw new SpotifyAuthError(code, message);
    }

    return {
        accessToken: data.access_token,
        expiresIn: data.expires_in,
        expiresAt: Date.now() + data.expires_in * 1000,
        newRefreshToken: data.refresh_token, // undefined unless rotated
        scope: data.scope,
    };
}
