// delete-account
//
// "Delete account" (PRIVACY.md): permanently removes the caller's play history, stored
// credentials, profile, and auth user. Implemented as a single auth-user deletion — every
// user table (`profiles`, `spotify_credentials`, `play_events`) references `auth.users`
// with ON DELETE CASCADE, so the database guarantees nothing is left behind. New user tables
// MUST keep that cascade for this guarantee to hold.
//
// The caller's session becomes invalid the moment this succeeds; the app signs out locally
// after a 200.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, jsonResponse, requireUser } from "../_shared/http.ts";

Deno.serve(async (req: Request) => {
    if (req.method !== "POST") {
        return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    const admin = adminClient();

    const auth = await requireUser(req, admin);
    if (auth.error !== null) return jsonResponse({ error: auth.error }, 401);

    const { error } = await admin.auth.admin.deleteUser(auth.userId);
    if (error) {
        return jsonResponse({ error: "delete_failed", detail: error.message }, 500);
    }

    return jsonResponse({ ok: true });
});
