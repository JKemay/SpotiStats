// collect-plays
//
// The heart of the product: continuously harvests every user's recently-played tracks into
// `play_events`, because Spotify only exposes the LAST 50 plays — history not collected in time
// is gone. Invoked every 10 minutes by pg_cron (via pg_net), authenticated with a shared secret.
//
// Behavior that matters:
//   - Batches users (oldest-success first), skipping `reauth_required` / disabled rows.
//   - Uses the `after` cursor so each poll only asks for new plays.
//   - Upserts by `idempotency_key` with ON CONFLICT DO NOTHING — overlapping windows are safe.
//   - One user's failure never aborts the run (recorded per-user, summarized in collector_runs).
//   - 429: waits out small Retry-After values once; otherwise skips the user until next run.
//   - `invalid_grant` flags `reauth_required` so dead tokens are never hammered.
//
// Deploy with --no-verify-jwt (pg_net can't mint user JWTs); the secret header is the gate.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { adminClient, jsonResponse } from "../_shared/http.ts";
import { constantTimeEquals } from "../_shared/secrets.ts";
import { decryptRefreshToken, encryptRefreshToken } from "../_shared/crypto.ts";
import {
    fetchRecentlyPlayed,
    type RecentlyPlayedPage,
    refreshSpotifyAccessToken,
    SpotifyAuthError,
    SpotifyRateLimitError,
} from "../_shared/spotify.ts";
import { idempotencyKey, playEventRow } from "../_shared/plays.ts";

const USERS_PER_RUN = 20;
const PAGE_LIMIT = 50;
/// Wait out a 429 only if Spotify asks for at most this many seconds; otherwise skip the user.
const MAX_RATE_LIMIT_WAIT_SECONDS = 5;
/// Cap the per-run error list so a mass outage can't bloat collector_runs.
const MAX_RECORDED_ERRORS = 20;

interface CredentialRow {
    user_id: string;
    refresh_token_ciphertext: string;
    refresh_token_nonce: string;
    key_version: number;
    last_collected_after_ms: number | null;
}

interface RunSummary {
    processed: number;
    skipped: number;
    failed: number;
    inserted: number;
    errors: string[];
}

function isAuthorized(req: Request): boolean {
    const secret = Deno.env.get("COLLECT_PLAYS_SECRET");
    if (!secret) return false; // fail closed if the secret was never configured
    return constantTimeEquals(req.headers.get("x-collector-secret") ?? "", secret);
}

Deno.serve(async (req: Request) => {
    if (req.method !== "POST") {
        return jsonResponse({ error: "method_not_allowed" }, 405);
    }
    if (!isAuthorized(req)) {
        return jsonResponse({ error: "unauthorized" }, 401);
    }

    const admin = adminClient();
    const trigger = await triggerSource(req);

    const { data: run, error: runError } = await admin
        .from("collector_runs")
        .insert({ trigger_source: trigger })
        .select("id")
        .single();
    if (runError) {
        return jsonResponse({ error: "run_insert_failed", detail: runError.message }, 500);
    }

    const summary: RunSummary = { processed: 0, skipped: 0, failed: 0, inserted: 0, errors: [] };

    const { data: creds, error: credsError } = await admin
        .from("spotify_credentials")
        .select(
            "user_id, refresh_token_ciphertext, refresh_token_nonce, key_version, last_collected_after_ms",
        )
        .eq("enabled", true)
        .eq("reauth_required", false)
        .order("last_success_at", { ascending: true, nullsFirst: true })
        .limit(USERS_PER_RUN);

    if (credsError) {
        await finishRun(admin, run.id, "failed", summary, credsError.message);
        return jsonResponse({ error: "credentials_load_failed", detail: credsError.message }, 500);
    }

    for (const cred of (creds ?? []) as CredentialRow[]) {
        try {
            summary.inserted += await collectForUser(admin, cred);
            summary.processed += 1;
        } catch (err) {
            if (err instanceof SpotifyRateLimitError) {
                // Not a failure — the user is simply retried on the next run.
                summary.skipped += 1;
                continue;
            }
            summary.failed += 1;
            const message = err instanceof Error ? err.message : String(err);
            if (summary.errors.length < MAX_RECORDED_ERRORS) {
                summary.errors.push(`${cred.user_id}: ${message}`);
            }
            await admin
                .from("spotify_credentials")
                .update({ last_error: message })
                .eq("user_id", cred.user_id);
        }
    }

    const status = summary.failed === 0 ? "success" : summary.processed > 0 ? "partial" : "failed";
    await finishRun(admin, run.id, status, summary, null);

    return jsonResponse({ run_id: run.id, status, ...summary });
});

/// Collects new plays for one user. Returns the number of NEW events inserted.
async function collectForUser(admin: SupabaseClient, cred: CredentialRow): Promise<number> {
    const refreshToken = await decryptRefreshToken(
        cred.refresh_token_ciphertext,
        cred.refresh_token_nonce,
        cred.key_version,
        cred.user_id,
    );

    let minted;
    try {
        minted = await refreshSpotifyAccessToken(refreshToken);
    } catch (err) {
        if (err instanceof SpotifyAuthError && err.code === "invalid_grant") {
            await admin
                .from("spotify_credentials")
                .update({
                    reauth_required: true,
                    token_refresh_failed_at: new Date().toISOString(),
                    last_error: `${err.code}: ${err.message}`,
                })
                .eq("user_id", cred.user_id);
        }
        throw err;
    }

    if (minted.newRefreshToken) {
        const enc = await encryptRefreshToken(minted.newRefreshToken, cred.user_id);
        await admin
            .from("spotify_credentials")
            .update({
                refresh_token_ciphertext: enc.ciphertext,
                refresh_token_nonce: enc.nonce,
                key_version: enc.keyVersion,
                encrypted_at: new Date().toISOString(),
            })
            .eq("user_id", cred.user_id);
    }

    const page = await fetchPageWithOneRetry(minted.accessToken, cred.last_collected_after_ms);

    let inserted = 0;
    if (page.items.length > 0) {
        const rows = [];
        for (const item of page.items) {
            rows.push(playEventRow(cred.user_id, item, await idempotencyKey(cred.user_id, item)));
        }

        const { count, error: insertError } = await admin
            .from("play_events")
            .upsert(rows, { onConflict: "idempotency_key", ignoreDuplicates: true, count: "exact" });
        if (insertError) {
            throw new Error(`play_events insert failed: ${insertError.message}`);
        }
        inserted = count ?? 0;
    }

    // Advance the cursor only when Spotify gave us one (or we saw items); an empty page keeps
    // the old cursor so nothing is skipped.
    const nextCursor = page.cursorAfterMs ?? maxPlayedAtMs(page) ?? cred.last_collected_after_ms;
    await admin
        .from("spotify_credentials")
        .update({
            last_collected_after_ms: nextCursor,
            last_success_at: new Date().toISOString(),
            last_error: null,
        })
        .eq("user_id", cred.user_id);

    return inserted;
}

/// One bounded retry on 429: wait if Spotify asks for a short pause, otherwise rethrow
/// (the caller skips the user until the next run).
async function fetchPageWithOneRetry(
    accessToken: string,
    afterMs: number | null,
): Promise<RecentlyPlayedPage> {
    try {
        return await fetchRecentlyPlayed(accessToken, afterMs, PAGE_LIMIT);
    } catch (err) {
        if (
            err instanceof SpotifyRateLimitError &&
            err.retryAfterSeconds !== null &&
            err.retryAfterSeconds <= MAX_RATE_LIMIT_WAIT_SECONDS
        ) {
            await new Promise((resolve) => setTimeout(resolve, err.retryAfterSeconds! * 1000));
            return await fetchRecentlyPlayed(accessToken, afterMs, PAGE_LIMIT);
        }
        throw err;
    }
}

function maxPlayedAtMs(page: RecentlyPlayedPage): number | null {
    let max: number | null = null;
    for (const item of page.items) {
        const ms = Date.parse(item.played_at);
        if (!Number.isNaN(ms) && (max === null || ms > max)) max = ms;
    }
    return max;
}

async function finishRun(
    admin: SupabaseClient,
    runId: number,
    status: "success" | "partial" | "failed",
    summary: RunSummary,
    fatal: string | null,
): Promise<void> {
    await admin
        .from("collector_runs")
        .update({
            finished_at: new Date().toISOString(),
            status,
            users_processed: summary.processed,
            users_skipped: summary.skipped,
            users_failed: summary.failed,
            events_inserted: summary.inserted,
            error_summary: summary.errors.length > 0 || fatal
                ? { errors: summary.errors, fatal }
                : null,
        })
        .eq("id", runId);
}

/// Only the two values we emit ourselves; anything else (even with a valid secret) is "manual".
async function triggerSource(req: Request): Promise<string> {
    try {
        const body = await req.json();
        return body?.trigger === "cron" ? "cron" : "manual";
    } catch {
        return "manual";
    }
}
