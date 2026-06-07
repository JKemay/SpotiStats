// store-spotify-credentials
//
// The OAuth handoff. The iOS app, immediately after Spotify sign-in, sends its Spotify
// `provider_refresh_token` here. This function:
//   1. authenticates the caller via their Supabase JWT,
//   2. encrypts the refresh token (AES-GCM, bound to the user),
//   3. upserts it into the service-role-only `spotify_credentials` table.
//
// The client never writes that table directly — this function is its only writer.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, jsonResponse, requireUser } from "../_shared/http.ts";
import { encryptRefreshToken } from "../_shared/crypto.ts";

interface Body {
    refresh_token?: string;
    spotify_user_id?: string;
}

Deno.serve(async (req: Request) => {
    if (req.method !== "POST") {
        return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    const admin = adminClient();

    const auth = await requireUser(req, admin);
    if (auth.error) return jsonResponse({ error: auth.error }, 401);

    let body: Body;
    try {
        body = await req.json();
    } catch {
        return jsonResponse({ error: "invalid_body" }, 400);
    }
    if (!body.refresh_token) {
        return jsonResponse({ error: "missing_refresh_token" }, 400);
    }

    const enc = await encryptRefreshToken(body.refresh_token, auth.userId);

    const { error } = await admin.from("spotify_credentials").upsert(
        {
            user_id: auth.userId,
            spotify_user_id: body.spotify_user_id ?? null,
            refresh_token_ciphertext: enc.ciphertext,
            refresh_token_nonce: enc.nonce,
            key_version: enc.keyVersion,
            encrypted_at: new Date().toISOString(),
            reauth_required: false,
            token_refresh_failed_at: null,
            last_error: null,
            enabled: true,
        },
        { onConflict: "user_id" },
    );

    if (error) {
        return jsonResponse({ error: "store_failed", detail: error.message }, 500);
    }

    return jsonResponse({ ok: true }, 200);
});
