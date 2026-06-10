// refresh-spotify-token
//
// Mints a fresh Spotify access token for the calling user from their stored (encrypted) refresh
// token. The iOS app calls this when it needs a token for a direct Spotify request, and caches the
// result in memory until it expires.
//
// Rotation persistence and dead-token (`invalid_grant` -> `reauth_required`) handling live in
// the shared `mintAccessTokenFromStored` (see _shared/credentials.ts); this function adds the
// user-facing auth gate, status mapping, and success bookkeeping.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, jsonResponse, requireUser } from "../_shared/http.ts";
import { CredentialDecryptError, mintAccessTokenFromStored } from "../_shared/credentials.ts";
import { SpotifyAuthError } from "../_shared/spotify.ts";

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

    try {
        const result = await mintAccessTokenFromStored(admin, {
            user_id: auth.userId,
            refresh_token_ciphertext: cred.refresh_token_ciphertext,
            refresh_token_nonce: cred.refresh_token_nonce,
            key_version: cred.key_version,
        });

        await admin
            .from("spotify_credentials")
            .update({ last_success_at: new Date().toISOString(), last_error: null })
            .eq("user_id", auth.userId);

        return jsonResponse({
            access_token: result.accessToken,
            expires_in: result.expiresIn,
            expires_at: result.expiresAt,
        });
    } catch (err) {
        if (err instanceof CredentialDecryptError) {
            return jsonResponse({ error: "decrypt_failed" }, 500);
        }
        if (err instanceof SpotifyAuthError && err.code === "invalid_grant") {
            // reauth_required was already flagged inside the shared helper.
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
