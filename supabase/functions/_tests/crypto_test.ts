// Tests for the AES-GCM refresh-token encryption: round-trip, AAD binding (a ciphertext moved
// to another user's row must fail), and nonce uniqueness.

import { assertEquals, assertNotEquals, assertRejects } from "jsr:@std/assert@1";
import { decryptRefreshToken, encryptRefreshToken } from "../_shared/crypto.ts";

// A throwaway 32-byte key, base64 — tests only, never a real secret.
const TEST_KEY = btoa(String.fromCharCode(...new Uint8Array(32).map((_, i) => i)));
Deno.env.set("TOKEN_ENCRYPTION_KEY", TEST_KEY);

const USER_A = "aaaaaaaa-1111-2222-3333-444444444444";
const USER_B = "bbbbbbbb-1111-2222-3333-444444444444";

Deno.test("encrypt/decrypt round-trips for the owning user", async () => {
    const enc = await encryptRefreshToken("super-secret-refresh-token", USER_A);
    const plain = await decryptRefreshToken(enc.ciphertext, enc.nonce, enc.keyVersion, USER_A);
    assertEquals(plain, "super-secret-refresh-token");
});

Deno.test("AAD binds ciphertext to the user: another user's id fails decryption", async () => {
    const enc = await encryptRefreshToken("super-secret-refresh-token", USER_A);
    await assertRejects(() =>
        decryptRefreshToken(enc.ciphertext, enc.nonce, enc.keyVersion, USER_B)
    );
});

Deno.test("AAD binds ciphertext to the key version: a wrong version fails decryption", async () => {
    const enc = await encryptRefreshToken("super-secret-refresh-token", USER_A);
    await assertRejects(() =>
        decryptRefreshToken(enc.ciphertext, enc.nonce, enc.keyVersion + 1, USER_A)
    );
});

Deno.test("every encryption uses a fresh nonce", async () => {
    const first = await encryptRefreshToken("same-token", USER_A);
    const second = await encryptRefreshToken("same-token", USER_A);
    assertNotEquals(first.nonce, second.nonce);
    assertNotEquals(first.ciphertext, second.ciphertext);
});
