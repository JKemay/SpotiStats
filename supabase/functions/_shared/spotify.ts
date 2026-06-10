// Spotify token + API helpers used by the Edge Functions.

import type { SpotifyPlayItem } from "./plays.ts";

/// Raised when Spotify rejects the refresh token (e.g. `invalid_grant`), meaning the user must
/// reconnect. The collector and the interactive refresh both use this to flip `reauth_required`.
export class SpotifyAuthError extends Error {
    constructor(public code: string, message: string) {
        super(message);
        this.name = "SpotifyAuthError";
    }
}

/// Raised on HTTP 429. `retryAfterSeconds` echoes Spotify's Retry-After header when present.
export class SpotifyRateLimitError extends Error {
    constructor(public retryAfterSeconds: number | null) {
        super(`Spotify rate limited (retry after ${retryAfterSeconds ?? "?"}s)`);
        this.name = "SpotifyRateLimitError";
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

export interface RecentlyPlayedPage {
    items: SpotifyPlayItem[];
    /// Spotify's own next-poll cursor (epoch ms as a string); preferred over deriving one.
    cursorAfterMs: number | null;
}

/// Fetches the user's recently-played items, optionally only those after the given cursor.
/// Throws `SpotifyRateLimitError` on 429 and `SpotifyAuthError` on 401/403 so callers can
/// distinguish "back off" from "re-auth".
export async function fetchRecentlyPlayed(
    accessToken: string,
    afterMs?: number | null,
    limit = 50,
): Promise<RecentlyPlayedPage> {
    const url = new URL("https://api.spotify.com/v1/me/player/recently-played");
    url.searchParams.set("limit", String(limit));
    if (afterMs) url.searchParams.set("after", String(afterMs));

    const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });

    if (res.status === 429) {
        const header = res.headers.get("Retry-After");
        const seconds = header === null ? NaN : Number(header);
        throw new SpotifyRateLimitError(Number.isFinite(seconds) ? seconds : null);
    }
    if (res.status === 401 || res.status === 403) {
        throw new SpotifyAuthError(`http_${res.status}`, "Spotify rejected the access token");
    }
    if (!res.ok) {
        throw new Error(`recently-played failed (http ${res.status})`);
    }

    const data = await res.json();
    const cursor = Number(data?.cursors?.after);
    return {
        items: (data?.items ?? []) as SpotifyPlayItem[],
        cursorAfterMs: Number.isFinite(cursor) ? cursor : null,
    };
}
