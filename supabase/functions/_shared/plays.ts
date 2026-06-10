// Play-event mapping + idempotency for the collector.
//
// The idempotency key is the heart of "store every play exactly once": collection windows
// overlap on purpose (we re-fetch from a cursor), so inserts MUST be deduplicatable. The key is
// a SHA-256 of a canonical JSON object identifying the play. Canonical means: fixed key set,
// keys sorted, `played_at` normalized to epoch milliseconds (so ISO formatting drift can't
// change the hash), artist names sorted in the fallback. NEVER change this scheme casually —
// a new scheme makes every previously stored play look "new" and duplicates history.

/// The slice of Spotify's recently-played item the collector consumes (snake_case wire shape).
export interface SpotifyPlayItem {
    track: {
        id?: string | null;
        name: string;
        duration_ms?: number | null;
        explicit?: boolean | null;
        is_local?: boolean | null;
        artists?: { id?: string | null; name: string }[] | null;
        album?: {
            name?: string | null;
            images?: { url: string; width?: number | null; height?: number | null }[] | null;
        } | null;
    };
    played_at: string;
    context?: { uri?: string | null } | null;
}

/// The canonical pre-hash material. Exported for tests; production code uses `idempotencyKey`.
export function canonicalKeyMaterial(userId: string, item: SpotifyPlayItem): string {
    const playedAtMs = Date.parse(item.played_at);
    if (Number.isNaN(playedAtMs)) {
        throw new Error(`unparseable played_at: ${item.played_at}`);
    }

    const material: Record<string, unknown> = {
        played_at_ms: playedAtMs,
        user_id: userId.toLowerCase(),
    };
    if (item.track.id) {
        material.track_id = item.track.id;
    } else {
        // Local tracks have no catalog id; fall back to the play's observable identity.
        material.track_name = item.track.name;
        material.artist_names = (item.track.artists ?? []).map((a) => a.name).sort();
        material.duration_ms = item.track.duration_ms ?? 0;
    }

    return JSON.stringify(material, Object.keys(material).sort());
}

/// SHA-256 hex (64 chars) of the canonical material.
export async function idempotencyKey(userId: string, item: SpotifyPlayItem): Promise<string> {
    const bytes = new TextEncoder().encode(canonicalKeyMaterial(userId, item));
    const digest = await crypto.subtle.digest("SHA-256", bytes);
    return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/// Maps one recently-played item to a `play_events` row (denormalized snapshot).
export function playEventRow(
    userId: string,
    item: SpotifyPlayItem,
    key: string,
): Record<string, unknown> {
    const track = item.track;
    const artists = track.artists ?? [];
    return {
        user_id: userId,
        played_at: new Date(Date.parse(item.played_at)).toISOString(),
        track_id: track.id ?? null,
        track_name: track.name,
        artist_ids: artists.map((a) => a.id).filter((id): id is string => Boolean(id)),
        artist_names: artists.map((a) => a.name),
        album_name: track.album?.name ?? null,
        album_art_url: track.album?.images?.[0]?.url ?? null,
        duration_ms: track.duration_ms ?? null,
        explicit: track.explicit ?? false,
        is_local: track.is_local ?? false,
        context_uri: item.context?.uri ?? null,
        idempotency_key: key,
    };
}
