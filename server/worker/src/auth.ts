// Supabase JWT verification with the project's PUBLIC signing keys (JWKS,
// ES256) and Web Crypto only. The Worker holds no JWT secret
// (SECURITY_ARCHITECTURE §3, SUPABASE_ARCHITECTURE §3).

export interface Identity {
  userId: string;
  anonymous: boolean;
}

interface Jwk extends JsonWebKey {
  kid?: string;
}

let cache: { url: string; keys: Jwk[]; fetchedAt: number } | null = null;
const JWKS_TTL_MS = 10 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function b64urlToBytes(s: string): Uint8Array {
  const pad = s.length % 4 === 0 ? "" : "=".repeat(4 - (s.length % 4));
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function decodePart(part: string): Record<string, unknown> {
  return JSON.parse(new TextDecoder().decode(b64urlToBytes(part))) as Record<string, unknown>;
}

async function keysFor(supabaseUrl: string, kid: string): Promise<Jwk | undefined> {
  const now = Date.now();
  const fresh = cache && cache.url === supabaseUrl && now - cache.fetchedAt < JWKS_TTL_MS;
  let key = fresh ? cache!.keys.find((k) => k.kid === kid) : undefined;
  if (!key) {
    // Unknown kid: refetch once (signing key rotation).
    const res = await fetch(`${supabaseUrl}/auth/v1/.well-known/jwks.json`);
    if (!res.ok) return undefined;
    const body = (await res.json()) as { keys?: Jwk[] };
    cache = { url: supabaseUrl, keys: body.keys ?? [], fetchedAt: now };
    key = cache.keys.find((k) => k.kid === kid);
  }
  return key;
}

/** Returns the identity of a valid, unexpired Supabase access token, else null. */
export async function verifySupabaseJwt(token: unknown, supabaseUrl: string): Promise<Identity | null> {
  if (typeof token !== "string" || token.length > 4096) return null;
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const header = decodePart(parts[0]!);
    if (header.alg !== "ES256" || typeof header.kid !== "string") return null;   // allow-list: ES256 only
    const jwk = await keysFor(supabaseUrl, header.kid);
    if (!jwk) return null;
    const key = await crypto.subtle.importKey("jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
    const ok = await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" }, key, b64urlToBytes(parts[2]!), new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
    if (!ok) return null;
    const c = decodePart(parts[1]!);
    const now = Math.floor(Date.now() / 1000);
    if (typeof c.exp !== "number" || c.exp <= now) return null;
    if (c.iss !== `${supabaseUrl}/auth/v1`) return null;
    if (c.aud !== "authenticated" || c.role !== "authenticated") return null;
    if (typeof c.sub !== "string" || !UUID.test(c.sub)) return null;
    return { userId: c.sub, anonymous: c.is_anonymous === true };
  } catch {
    return null;
  }
}
