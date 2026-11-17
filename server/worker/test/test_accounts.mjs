// Reusable test accounts (Supabase guests) for cloud tests, so tests do not create
// new guest accounts every run (Supabase limits anonymous sign-ups per IP and hour).
//
// The pool lives in server/worker/.test-accounts.json (git-ignored, file mode 600):
// [{ id, refresh_token, label }]. Each run signs every account in again with its
// refresh token (Supabase rotates it; the new one is saved). Missing accounts are
// created one at a time and named "KBTest<n>" so they are recognisable as test
// accounts. Nothing secret is printed.

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
export const POOL_FILE = resolve(here, "../.test-accounts.json");

function readPool() {
  if (!existsSync(POOL_FILE)) return [];
  try { return JSON.parse(readFileSync(POOL_FILE, "utf8")); } catch { return []; }
}

export function savePool(pool) {
  writeFileSync(POOL_FILE, JSON.stringify(pool.map(({ id, refresh_token, label }) => ({ id, refresh_token, label })), null, 2), { mode: 0o600 });
}

async function auth(supabase, publishable, endpoint, body) {
  const r = await fetch(`${supabase}/auth/v1/${endpoint}`, { method: "POST", headers: { apikey: publishable, "content-type": "application/json" }, body: JSON.stringify(body) });
  const j = await r.json().catch(() => ({}));
  return { status: r.status, j };
}

/** n accounts {id, token (access), refresh_token, label}; refreshed or created as needed. */
export async function testAccounts(supabase, publishable, n) {
  const pool = readPool();
  const out = [];
  let created = 0;
  for (let i = 0; i < n; i++) {
    const label = `KBTest${i + 1}`;
    let acc = pool[i];
    let session = null;
    if (acc?.refresh_token) {
      const r = await auth(supabase, publishable, "token?grant_type=refresh_token", { refresh_token: acc.refresh_token });
      if (r.j.access_token && r.j.user?.id === acc.id) session = r.j;
    }
    if (!session) {
      const r = await auth(supabase, publishable, "signup", { data: {} });
      if (!r.j.access_token) throw new Error(`test account ${label}: sign-up failed (${r.status})`);
      session = r.j;
      created++;
      await fetch(`${supabase}/rest/v1/rpc/update_my_profile`, {
        method: "POST", headers: { apikey: publishable, authorization: `Bearer ${session.access_token}`, "content-type": "application/json" },
        body: JSON.stringify({ p_display_name: label }),
      });
    }
    acc = { id: session.user.id, refresh_token: session.refresh_token, label };
    pool[i] = acc;
    savePool(pool);
    out.push({ ...acc, token: session.access_token });
  }
  console.log(`test accounts: ${n} ready (${created} newly created, ${n - created} reused)`);
  return out;
}

/** Stores refresh tokens rotated elsewhere (e.g. by a Godot client) back into the pool. */
export function updateRefreshToken(id, refreshToken) {
  const pool = readPool();
  const acc = pool.find((a) => a.id === id);
  if (acc && refreshToken) { acc.refresh_token = refreshToken; savePool(pool); }
}

export function poolIds() { return readPool().map((a) => a.id); }

export const poolPath = (...p) => join(dirname(POOL_FILE), ...p);

/** SQL that resets the test accounts (never other players' data): their match records,
 *  friendships, requests, blocks, XP, level, unlocks and online stats. */
export function resetSql(ids) {
  const l = ids.map((i) => `'${i}'`).join(",");
  return `delete from public.matches where id in (select match_id from public.match_players where user_id in (${l}));
delete from public.friendships where user_low in (${l}) or user_high in (${l});
delete from public.friend_requests where from_id in (${l}) or to_id in (${l});
delete from public.blocks where blocker_id in (${l}) or blocked_id in (${l});
delete from public.xp_events where user_id in (${l});
delete from public.player_unlocks where user_id in (${l});
update public.profiles set xp = 0, level = 1 where user_id in (${l});
update public.player_stats set matches_2p = 0, wins_2p = 0, matches_4p = 0, wins_4p = 0, leaves = 0 where user_id in (${l})`;
}

