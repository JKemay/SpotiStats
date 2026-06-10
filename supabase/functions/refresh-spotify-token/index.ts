// refresh-spotify-token
//
// Mints a fresh Spotify access token for the calling user from their stored (encrypted) refresh
// token. The iOS app calls this when it needs a token for a direct Spotify request, and caches the
// result in memory until it expires.
//
// Handles the two things naive implementations miss:
//   - refresh-token ROTATION: if Spotify returns a new refresh token, we re-encrypt and store it.
//   - DEAD tokens: on `invalid_grant` we flag the user `reauth_required` and stop, so we never
//     hammer a revoked token.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, jsonResponse, requireUser } from "../_shared/http.ts";
import { decryptRefreshToken, encryptRefreshToken } from "../_shared/crypto.ts";
import { refreshSpotifyAccessToken, SpotifyAuthError } from "../_shared/spotify.ts";

Deno.serve(async (req: Request) => {
    if (req.method !== "POST") {
        return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    const admin = adminClient();

    const auth = await requireUser(req, admin);
    if (auth.error !== null) return jsonResponse({ error: auth.error }, 401);

    const { data: cred, error: loadError } = await admin
        .from("spotify_credentials")
        .select("refresh_token_ciphertext, refresh_token_nonce, key_version, reauth_required, enabled")
        .eq("user_id", auth.userId)
        .maybeSingle();

    if (loadError) return jsonResponse({ error: "load_failed", detail: loadError.message }, 500);
    if (!cred) return jsonResponse({ error: "not_connected" }, 409);
    if (cred.reauth_required) return jsonResponse({ error: "reauth_required" }, 409);

    let refreshToken: string;
    try {
        refreshToken = await decryptRefreshToken(
            cred.refresh_token_ciphertext,
            cred.refresh_token_nonce,
            cred.key_version,
            auth.userId,
        );
    } catch {
        return jsonResponse({ error: "decrypt_failed" }, 500);
    }

    try {
        const result = await refreshSpotifyAccessToken(refreshToken);

        // Persist a rotated refresh token if Spotify returned one; always record success.
        const update: Record<string, unknown> = {
            last_success_at: new Date().toISOString(),
            last_error: null,
        };
        if (result.newRefreshToken) {
            const enc = await encryptRefreshToken(result.newRefreshToken, auth.userId);
            update.refresh_token_ciphertext = enc.ciphertext;
            update.refresh_token_nonce = enc.nonce;
            update.key_version = enc.keyVersion;
            update.encrypted_at = new Date().toISOString();
        }
        await admin.from("spotify_credentials").update(update).eq("user_id", auth.userId);

        return jsonResponse({
            access_token: result.accessToken,
            expires_in: result.expiresIn,
            expires_at: result.expiresAt,
        });
    } catch (err) {
        if (err instanceof SpotifyAuthError && err.code === "invalid_grant") {
            await admin
                .from("spotify_credentials")
                .update({
                    reauth_required: true,
                    token_refresh_failed_at: new Date().toISOString(),
                    last_error: `${err.code}: ${err.message}`,
                })
                .eq("user_id", auth.userId);
            return jsonResponse({ error: "reauth_required" }, 409);
        }
        const message = err instanceof Error ? err.message : "unknown_error";
        await admin
            .from("spotify_credentials")
            .update({ last_error: message, token_refresh_failed_at: new Date().toISOString() })
            .eq("user_id", auth.userId);
        return jsonResponse({ error: "refresh_failed", detail: message }, 502);
    }
});
