// disconnect-spotify
//
// "Disconnect & forget credentials" (PRIVACY.md): deletes the caller's stored (encrypted)
// Spotify refresh token, which also stops collection — the collector only processes rows that
// exist in `spotify_credentials`. Play history is kept; deleting everything is `delete-account`.
//
// True revocation of the app's Spotify access additionally requires removing it from the
// user's Spotify "Apps with access" page; the app links there next to this action.
//
// Idempotent: disconnecting while already disconnected succeeds.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, jsonResponse, requireUser } from "../_shared/http.ts";

Deno.serve(async (req: Request) => {
    if (req.method !== "POST") {
        return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    const admin = adminClient();

    const auth = await requireUser(req, admin);
    if (auth.error !== null) return jsonResponse({ error: auth.error }, 401);

    const { error } = await admin
        .from("spotify_credentials")
        .delete()
        .eq("user_id", auth.userId);

    if (error) {
        return jsonResponse({ error: "disconnect_failed", detail: error.message }, 500);
    }

    return jsonResponse({ ok: true });
});
