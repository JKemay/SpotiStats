// Secret-handling primitives. Deliberately dependency-free so security-critical code is
// trivially testable and auditable in isolation.

/// Constant-time string comparison for secrets (a plain `===` leaks match position via timing).
export function constantTimeEquals(a: string, b: string): boolean {
    const encoder = new TextEncoder();
    const aBytes = encoder.encode(a);
    const bBytes = encoder.encode(b);
    if (aBytes.length !== bBytes.length) return false;
    let diff = 0;
    for (let i = 0; i < aBytes.length; i++) diff |= aBytes[i] ^ bBytes[i];
    return diff === 0;
}
