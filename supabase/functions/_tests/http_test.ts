// Tests for the constant-time secret comparison guarding collect-plays.

import { assert, assertFalse } from "jsr:@std/assert@1";
import { constantTimeEquals } from "../_shared/secrets.ts";

Deno.test("equal strings compare true", () => {
    assert(constantTimeEquals("collector-secret-123", "collector-secret-123"));
});

Deno.test("different strings of equal length compare false", () => {
    assertFalse(constantTimeEquals("collector-secret-123", "collector-secret-124"));
});

Deno.test("different lengths compare false", () => {
    assertFalse(constantTimeEquals("short", "much-longer-value"));
});

Deno.test("empty provided value never matches a real secret", () => {
    assertFalse(constantTimeEquals("", "real-secret"));
});

Deno.test("unicode is compared by bytes, not code units", () => {
    assert(constantTimeEquals("café-🔑", "café-🔑"));
    assertFalse(constantTimeEquals("café-🔑", "cafe-🔑"));
});
