// Tests for the idempotency-key scheme and play_events row mapping.
//
// The key scheme is load-bearing: if it ever changes, previously stored plays stop matching and
// history duplicates. These tests pin both the scheme's stability properties AND one exact known
// hash, so an accidental change fails loudly.

import { assertEquals, assertMatch, assertNotEquals, assertThrows } from "jsr:@std/assert@1";
import {
    canonicalKeyMaterial,
    idempotencyKey,
    playEventRow,
    type SpotifyPlayItem,
} from "../_shared/plays.ts";

const USER = "11111111-2222-3333-4444-555555555555";

function catalogItem(overrides: Partial<SpotifyPlayItem> = {}): SpotifyPlayItem {
    return {
        track: {
            id: "track1",
            name: "Sicko Mode",
            duration_ms: 312820,
            explicit: true,
            is_local: false,
            artists: [{ id: "art1", name: "Travis Scott" }],
            album: {
                name: "ASTROWORLD",
                images: [{ url: "https://img/640", width: 640, height: 640 }],
            },
        },
        played_at: "2026-06-06T10:00:00.000Z",
        context: { uri: "spotify:playlist:abc" },
        ...overrides,
    };
}

function localItem(): SpotifyPlayItem {
    return {
        track: {
            id: null,
            name: "Bootleg Demo",
            duration_ms: 200000,
            is_local: true,
            artists: [{ id: null, name: "Zeta" }, { id: null, name: "Alpha" }],
        },
        played_at: "2026-06-06T10:00:00.000Z",
    };
}

Deno.test("canonical material sorts keys and normalizes played_at to epoch ms", () => {
    const material = canonicalKeyMaterial(USER, catalogItem());
    assertEquals(
        material,
        `{"played_at_ms":1780740000000,"track_id":"track1","user_id":"${USER}"}`,
    );
});

Deno.test("same play with different ISO formatting hashes identically", async () => {
    const a = await idempotencyKey(USER, catalogItem({ played_at: "2026-06-06T10:00:00.000Z" }));
    const b = await idempotencyKey(USER, catalogItem({ played_at: "2026-06-06T10:00:00Z" }));
    assertEquals(a, b);
});

Deno.test("key is 64-char lowercase hex and matches the pinned value", async () => {
    const key = await idempotencyKey(USER, catalogItem());
    assertMatch(key, /^[0-9a-f]{64}$/);
    // Pinned: changing the scheme MUST break this test (see file header for why).
    assertEquals(key, "7498a67c891f6f7ffc0d5c25f590bef85ab8cea51ea89d80af5f70574eed5727");
});

Deno.test("different played_at means a different key", async () => {
    const a = await idempotencyKey(USER, catalogItem());
    const b = await idempotencyKey(USER, catalogItem({ played_at: "2026-06-06T10:03:00.000Z" }));
    assertNotEquals(a, b);
});

Deno.test("different users never share a key for the same play", async () => {
    const a = await idempotencyKey(USER, catalogItem());
    const b = await idempotencyKey("99999999-2222-3333-4444-555555555555", catalogItem());
    assertNotEquals(a, b);
});

Deno.test("user id casing does not change the key", async () => {
    const a = await idempotencyKey(USER, catalogItem());
    const b = await idempotencyKey(USER.toUpperCase(), catalogItem());
    assertEquals(a, b);
});

Deno.test("catalog tracks ignore name/metadata churn (id wins)", async () => {
    const renamed = catalogItem();
    renamed.track.name = "Sicko Mode (Remastered)";
    assertEquals(await idempotencyKey(USER, catalogItem()), await idempotencyKey(USER, renamed));
});

Deno.test("local-track fallback sorts artist names so order can't fork the key", async () => {
    const reversed = localItem();
    reversed.track.artists = [{ id: null, name: "Alpha" }, { id: null, name: "Zeta" }];
    assertEquals(await idempotencyKey(USER, localItem()), await idempotencyKey(USER, reversed));
});

Deno.test("local tracks with different names get different keys", async () => {
    const other = localItem();
    other.track.name = "Bootleg Demo 2";
    assertNotEquals(await idempotencyKey(USER, localItem()), await idempotencyKey(USER, other));
});

Deno.test("unparseable played_at throws instead of hashing garbage", () => {
    assertThrows(() => canonicalKeyMaterial(USER, catalogItem({ played_at: "yesterday-ish" })));
});

Deno.test("playEventRow maps a catalog item to the full snapshot", () => {
    const row = playEventRow(USER, catalogItem(), "key123");
    assertEquals(row, {
        user_id: USER,
        played_at: "2026-06-06T10:00:00.000Z",
        track_id: "track1",
        track_name: "Sicko Mode",
        artist_ids: ["art1"],
        artist_names: ["Travis Scott"],
        album_name: "ASTROWORLD",
        album_art_url: "https://img/640",
        duration_ms: 312820,
        explicit: true,
        is_local: false,
        context_uri: "spotify:playlist:abc",
        idempotency_key: "key123",
    });
});

Deno.test("playEventRow handles sparse local tracks with safe defaults", () => {
    const row = playEventRow(USER, localItem(), "key456");
    assertEquals(row.track_id, null);
    assertEquals(row.artist_ids, []); // null ids filtered out
    assertEquals(row.artist_names, ["Zeta", "Alpha"]); // display order preserved (NOT sorted)
    assertEquals(row.album_name, null);
    assertEquals(row.album_art_url, null);
    assertEquals(row.explicit, false);
    assertEquals(row.is_local, true);
    assertEquals(row.context_uri, null);
});
