// End-to-end check against the real dev project, through the public APIs the
// game client uses: Auth (anonymous sign-in) + Data API (PostgREST) with RLS.
// Also verifies the issued JWT with the project's public JWKS using Web Crypto
// only — the same method the Cloudflare Worker will use (no shared secret).
//
//   node supabase/tests/api_e2e_test.mjs <project-ref>
//
// Requires `npx supabase login`. Only the PUBLISHABLE key is used; the secret
// key is never read into a variable that is printed. Test users are deleted
// at the end (through the CLI, as the database owner).

import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const ref = process.argv[2];
if (!/^[a-z]{20}$/.test(ref ?? "")) throw new Error("usage: node api_e2e_test.mjs <project-ref>");
const base = `https://${ref}.supabase.co`;
const npx = process.platform === "win32" ? "npx.cmd" : "npx";
const cli = (args) => execFileSync(npx, ["supabase", ...args], { encoding: "utf8", shell: process.platform === "win32" });

// Publishable key only.
const keysOut = cli(["projects", "api-keys", "--project-ref", ref, "-o", "json"]);
const keys = JSON.parse(keysOut.slice(keysOut.indexOf("[")));
const publishable = keys.find((k) => k.type === "publishable")?.api_key ?? keys.find((k) => k.name === "anon")?.api_key;
if (!publishable) throw new Error("publishable key not found");

let passed = 0;
const created = [];
function check(cond, label) {
  if (!cond) throw new Error(`FAIL ${label}`);
  passed++;
  console.log(`  ok  ${label}`);
}

async function api(path, { method = "GET", token, body } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: {
      apikey: publishable,
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* not json */ }
  return { status: res.status, json };
}

const b64urlBytes = (s) => Uint8Array.from(Buffer.from(s, "base64url"));
const decode = (part) => JSON.parse(Buffer.from(part, "base64url").toString("utf8"));

/** Verifies an ES256 JWT against the project's JWKS with Web Crypto (Workers-compatible). */
async function verifyJwt(token) {
  const [h, p, sig] = token.split(".");
  const header = decode(h);
  if (header.alg !== "ES256") return { ok: false, why: `alg ${header.alg}` };
  const jwks = await (await fetch(`${base}/auth/v1/.well-known/jwks.json`)).json();
  const jwk = jwks.keys.find((k) => k.kid === header.kid);
  if (!jwk) return { ok: false, why: "kid not in JWKS" };
  const key = await crypto.subtle.importKey("jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  const valid = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, b64urlBytes(sig), new TextEncoder().encode(`${h}.${p}`));
  const claims = decode(p);
  const now = Math.floor(Date.now() / 1000);
  return { ok: valid && claims.exp > now && claims.iss === `${base}/auth/v1` && claims.aud === "authenticated", claims, valid };
}

async function signInAnonymously() {
  const r = await api("/auth/v1/signup", { method: "POST", body: { data: {} } });
  if (r.status !== 200 || !r.json?.access_token) throw new Error(`anonymous sign-in failed: HTTP ${r.status} ${r.json?.msg ?? r.json?.error_code ?? ""}`);
  created.push(r.json.user.id);
  return { token: r.json.access_token, id: r.json.user.id };
}

try {
  console.log("Auth");
  const A = await signInAnonymously();
  const B = await signInAnonymously();
  check(true, "two anonymous (guest) accounts created through Supabase Auth");

  const v = await verifyJwt(A.token);
  check(v.valid, "JWT signature verifies with the public JWKS (ES256, Web Crypto)");
  check(v.ok && v.claims.sub === A.id && v.claims.is_anonymous === true, "JWT claims: iss, aud, exp, sub, is_anonymous");
  const tampered = A.token.slice(0, -4) + (A.token.endsWith("AAAA") ? "BBBB" : "AAAA");
  check(!(await verifyJwt(tampered)).valid, "a tampered JWT is rejected");

  console.log("Data API + RLS");
  const wallet = await api("/rest/v1/wallets?select=user_id,coins,gems", { token: A.token });
  check(wallet.status === 200 && wallet.json.length === 1 && wallet.json[0].user_id === A.id, "player reads only own wallet");
  check(wallet.json[0].coins === 1000 && wallet.json[0].gems === 0, "new account got starting gold from config (trigger ran on real sign-up)");
  const profiles = await api("/rest/v1/profiles?select=user_id", { token: A.token });
  check(profiles.status === 200 && profiles.json.length === 1, "player reads only own profile");
  const other = await api(`/rest/v1/wallets?user_id=eq.${B.id}&select=coins`, { token: A.token });
  check(other.status === 200 && other.json.length === 0, "another player's wallet is invisible");

  const patch = await api(`/rest/v1/wallets?user_id=eq.${A.id}`, { method: "PATCH", token: A.token, body: { coins: 999999 } });
  check(patch.status === 401 || patch.status === 403, `client cannot change its balance (HTTP ${patch.status})`);
  const ins = await api("/rest/v1/wallet_transactions", { method: "POST", token: A.token,
    body: { user_id: A.id, currency: "gold", delta: 5, balance_after: 5, reason: "compensation", idempotency_key: "x" } });
  check(ins.status === 401 || ins.status === 403, `client cannot write the ledger (HTTP ${ins.status})`);
  const rpc = await api("/rest/v1/rpc/grant_purchase", { method: "POST", token: A.token, body: {} });
  check(rpc.status === 404 || rpc.status === 401 || rpc.status === 403, `server functions are not reachable from the client (HTTP ${rpc.status})`);
  const after = await api("/rest/v1/wallets?select=coins", { token: A.token });
  check(after.json[0].coins === 1000, "balance unchanged after the attempts");

  const cards = await api("/rest/v1/rpc/get_profile_cards", { method: "POST", token: A.token, body: { p_ids: [B.id] } });
  check(cards.status === 200 && cards.json.length === 1 && !("xp" in cards.json[0]), "profile card of another player: safe columns only");

  const anon = await api("/rest/v1/wallets?select=coins");
  check(anon.status === 401 || anon.status === 403 || (anon.status === 200 && anon.json.length === 0), `no session: no wallet data (HTTP ${anon.status})`);
  const cfg = await api("/rest/v1/app_config?select=key");
  check(cfg.status === 200 && cfg.json.some((r) => r.key === "features"), "no session: public config readable");

  console.log("Phase 4: profile, records, history");
  const upd = await api("/rest/v1/rpc/update_my_profile", { method: "POST", token: A.token, body: { p_display_name: "  Çağrı Test ", p_avatar_id: "fill:4" } });
  check(upd.status === 200 && upd.json.display_name === "Çağrı Test" && upd.json.avatar_id === "fill:4", "player renames itself through the validated RPC (Turkish letters, trimmed)");
  const badName = await api("/rest/v1/rpc/update_my_profile", { method: "POST", token: A.token, body: { p_display_name: "<script>" } });
  check(badName.status >= 400 && JSON.stringify(badName.json).includes("NAME_INVALID"), `invalid name refused with NAME_INVALID (HTTP ${badName.status})`);
  const otherPatch = await api(`/rest/v1/profiles?user_id=eq.${B.id}`, { method: "PATCH", token: A.token, body: { display_name: "Hacked" } });
  check(otherPatch.status === 401 || otherPatch.status === 403, `player cannot edit another profile directly (HTTP ${otherPatch.status})`);
  const ownPatch = await api(`/rest/v1/profiles?user_id=eq.${A.id}`, { method: "PATCH", token: A.token, body: { display_name: "x" } });
  check(ownPatch.status === 401 || ownPatch.status === 403, `profile changes only go through the RPC (HTTP ${ownPatch.status})`);
  const bCard = await api("/rest/v1/rpc/get_profile_cards", { method: "POST", token: A.token, body: { p_ids: [B.id] } });
  check(bCard.json?.[0]?.display_name === "Oyuncu", "the other player's name is unchanged");
  const rec = await api("/rest/v1/rpc/record_match", { method: "POST", token: A.token, body: { p_match_id: crypto.randomUUID() } });
  check(rec.status === 404 || rec.status === 401 || rec.status === 403, `client cannot record a match result (HTTP ${rec.status})`);
  const insMatch = await api("/rest/v1/matches", { method: "POST", token: A.token, body: { mode: "quick", players: 2, ruleset: {}, status: "finished" } });
  check(insMatch.status === 401 || insMatch.status === 403, `client cannot insert a match (HTTP ${insMatch.status})`);
  const stPatch = await api(`/rest/v1/player_stats?user_id=eq.${A.id}`, { method: "PATCH", token: A.token, body: { wins_2p: 50 } });
  check(stPatch.status === 401 || stPatch.status === 403, `client cannot change its stats (HTTP ${stPatch.status})`);
  const stats = await api("/rest/v1/player_stats?select=user_id,matches_2p,wins_2p", { token: A.token });
  check(stats.status === 200 && stats.json.length === 1 && stats.json[0].user_id === A.id && stats.json[0].wins_2p === 0, "player reads only own stats, unchanged");
  const hist = await api("/rest/v1/matches?select=id,match_players(user_id)&status=eq.finished", { token: A.token });
  check(hist.status === 200 && hist.json.every((m) => m.match_players.some((p) => p.user_id === A.id)), "match history: only matches the player took part in");
  const fake = await api("/auth/v1/user", { token: A.token.split(".").slice(0, 2).join(".") + ".invalidsignature" });
  check(fake.status === 401 || fake.status === 403, `Auth rejects a forged JWT (HTTP ${fake.status})`);

  console.log(`API_E2E_PASSED ${passed}`);
} finally {
  if (created.length) {
    const ids = created.map((id) => `'${id}'`).join(",");
    // SQL goes through a temp file: shell argument splitting on Windows would break it.
    const dir = mkdtempSync(join(tmpdir(), "kb-e2e-"));
    const file = join(dir, "cleanup.sql");
    writeFileSync(file, `delete from auth.users where id in (${ids});
`);
    try { cli(["db", "query", "--remote", "--yes", "-f", file]); } finally { rmSync(dir, { recursive: true, force: true }); }
    console.log(`cleanup: deleted ${created.length} test users`);
  }
}
