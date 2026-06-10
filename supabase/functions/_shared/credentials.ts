// The shared "stored credential -> fresh access token" flow used by every function that talks
// to Spotify on a user's behalf (refresh-spotify-token, collect-plays, future spotify-proxy).
//
// Centralized because the two non-obvious obligations MUST happen everywhere, every time:
//   - refresh-token ROTATION: when Spotify returns a new refresh token, re-encrypt and persist
//     it immediately, or the stored one eventually goes stale.
//   - DEAD tokens: on `invalid_grant`, flag `reauth_required` so the user is never hammered.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { decryptRefreshToken, encryptRefreshToken } from "./crypto.ts";
import { type RefreshResult, refreshSpotifyAccessToken, SpotifyAuthError } from "./spotify.ts";

/// The columns a caller must select from `spotify_credentials` to mint a token.
export interface StoredCredential {
    user_id: string;
    refresh_token_ciphertext: string;
    refresh_token_nonce: string;
    key_version: number;
}

/// Decryption failed (key or AAD mismatch) — distinct from Spotify auth errors so callers can
/// report it as a server-side problem rather than a re-auth condition.
export class CredentialDecryptError extends Error {
    constructor() {
        super("stored refresh token could not be decrypted (key/AAD mismatch)");
        this.name = "CredentialDecryptError";
    }
}

/// Decrypts the stored refresh token and mints a fresh access token.
///
/// Side effects on `spotify_credentials`:
///   - rotated refresh token -> re-encrypted and persisted before returning.
///   - `invalid_grant` -> `reauth_required` flagged (then the error is rethrown).
/// Success bookkeeping (`last_success_at`, `last_error`) stays with the caller — what
/// "success" means differs per function (a mint vs a full collection pass).
export async function mintAccessTokenFromStored(
    admin: SupabaseClient,
    cred: StoredCredential,
): Promise<RefreshResult> {
    let refreshToken: string;
    try {
        refreshToken = await decryptRefreshToken(
            cred.refresh_token_ciphertext,
            cred.refresh_token_nonce,
            cred.key_version,
            cred.user_id,
        );
    } catch {
        throw new CredentialDecryptError();
    }

    let minted: RefreshResult;
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

    return minted;
}
