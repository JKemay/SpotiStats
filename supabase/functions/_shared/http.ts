// Small HTTP / auth helpers shared by the Edge Functions.

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

/// A service-role client. It bypasses RLS, so it can read/write `spotify_credentials`.
/// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by the platform.
export function adminClient(): SupabaseClient {
    return createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
        { auth: { persistSession: false, autoRefreshToken: false } },
    );
}

export function jsonResponse(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}

/// Resolves the calling user from the request's bearer token. Returns the user, or an error code
/// suitable for a 401 response.
export async function requireUser(
    req: Request,
    admin: SupabaseClient,
): Promise<{ userId: string; error: null } | { userId: null; error: string }> {
    const header = req.headers.get("Authorization") ?? "";
    const jwt = header.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) return { userId: null, error: "missing_authorization" };

    const { data, error } = await admin.auth.getUser(jwt);
    if (error || !data.user) return { userId: null, error: "invalid_token" };
    return { userId: data.user.id, error: null };
}
