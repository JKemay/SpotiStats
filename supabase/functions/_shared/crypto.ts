// AES-GCM encryption for Spotify refresh tokens.
//
// The key is a 32-byte value provided as the base64 Edge Function secret TOKEN_ENCRYPTION_KEY.
// Each encryption uses a fresh random 12-byte IV (nonce) — a nonce is NEVER reused with the same
// key. Additional Authenticated Data (AAD) binds each ciphertext to its user id + key version, so
// a ciphertext copied to another user's row fails to decrypt.

export const CURRENT_KEY_VERSION = 1;

function base64ToBytes(b64: string): Uint8Array {
    const binary = atob(b64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
}

function bytesToBase64(bytes: Uint8Array): string {
    let binary = "";
    for (const b of bytes) binary += String.fromCharCode(b);
    return btoa(binary);
}

function keyBytes(): Uint8Array {
    const b64 = Deno.env.get("TOKEN_ENCRYPTION_KEY");
    if (!b64) throw new Error("TOKEN_ENCRYPTION_KEY is not set");
    const raw = base64ToBytes(b64);
    if (raw.length !== 32) {
        throw new Error("TOKEN_ENCRYPTION_KEY must decode to 32 bytes");
    }
    return raw;
}

async function importKey(): Promise<CryptoKey> {
    return await crypto.subtle.importKey("raw", keyBytes(), { name: "AES-GCM" }, false, [
        "encrypt",
        "decrypt",
    ]);
}

function aad(userId: string, keyVersion: number): Uint8Array {
    return new TextEncoder().encode(`${userId}|${keyVersion}|spotify_refresh_token`);
}

export interface EncryptedToken {
    ciphertext: string; // base64
    nonce: string; // base64
    keyVersion: number;
}

export async function encryptRefreshToken(plaintext: string, userId: string): Promise<EncryptedToken> {
    const key = await importKey();
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const cipher = await crypto.subtle.encrypt(
        { name: "AES-GCM", iv, additionalData: aad(userId, CURRENT_KEY_VERSION) },
        key,
        new TextEncoder().encode(plaintext),
    );
    return {
        ciphertext: bytesToBase64(new Uint8Array(cipher)),
        nonce: bytesToBase64(iv),
        keyVersion: CURRENT_KEY_VERSION,
    };
}

export async function decryptRefreshToken(
    ciphertext: string,
    nonce: string,
    keyVersion: number,
    userId: string,
): Promise<string> {
    const key = await importKey();
    const iv = base64ToBytes(nonce);
    const data = base64ToBytes(ciphertext);
    const plain = await crypto.subtle.decrypt(
        { name: "AES-GCM", iv, additionalData: aad(userId, keyVersion) },
        key,
        data,
    );
    return new TextDecoder().decode(plain);
}
