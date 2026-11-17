// Phase 6 cloud test of player progression with the reusable test accounts:
// a real quick match between two test accounts on the deployed server (queue ->
// MatchRoom -> played to the end by both clients), then over REST / RPC:
//  - XP and level from the match (server-side; client cannot change them),
//  - quest progress from the match, claiming once (5 concurrent claims -> exactly one),
//  - forged JWT / another player's JWT / direct table writes are refused.
// Later sub-phases add daily login, achievements and the leaderboard here.
//
//   node test/progress_cloud_test.mjs <supabase-project-ref> --remote https://...

import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { resetSql, testAccounts } from "./test_accounts.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "../../..");
const ref = process.argv[2];
const remoteArg = process.argv.indexOf("--remote");
if (!/^[a-z]{20}$/.test(ref ?? "") || remoteArg < 0) throw new Error("usage: node test/progress_cloud_test.mjs <project-ref> --remote <url>");
const BASE = process.argv[remoteArg + 1].replace(/\/$/, "");
const WS_BASE = BASE.replace(/^http/, "ws");
const SUPABASE = `https://${ref}.supabase.co`;
const WIN = process.platform === "win32";
const npx = WIN ? "npx.cmd" : "npx";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let passed = 0;
const check = (cond, label) => { if (!cond) throw new Error(`FAIL ${label}`); passed++; console.log(`  ok  ${label}`); };

const cli = (args) => execFileSync(npx, ["supabase", ...args], { cwd: repo, encoding: "utf8", shell: WIN });
const keysOut = cli(["projects", "api-keys", "--project-ref", ref, "-o", "json"]);
const publishable = JSON.parse(keysOut.slice(keysOut.indexOf("["))).find((k) => k.type === "publishable")?.api_key;
function sql(query, write = false) {
  const d = mkdtempSync(join(tmpdir(), "kb-sql-"));
  const f = join(d, "q.sql");
  writeFileSync(f, `${query};`);
  try {
    const out = cli(["db", "query", "--remote", write ? "--yes" : "--read-only", "-f", f, "-o", "json"]);
    return JSON.parse(out.slice(out.indexOf("{"))).rows ?? [];
  } finally { rmSync(d, { recursive: true, force: true }); }
}
async function rpc(token, fn, args = {}) {
  const r = await fetch(`${SUPABASE}/rest/v1/rpc/${fn}`, { method: "POST", headers: { apikey: publishable, authorization: `Bearer ${token}`, "content-type": "application/json" }, body: JSON.stringify(args) });
  const text = await r.text();
  let data = null;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: r.status, data, error: r.ok ? null : String(data?.message ?? text) };
}
async function rest(token, method, path, body) {
  const r = await fetch(`${SUPABASE}/rest/v1/${path}`, { method, headers: { apikey: publishable, authorization: `Bearer ${token}`, "content-type": "application/json", prefer: "return=minimal" }, body: body ? JSON.stringify(body) : undefined });
  return r.status;
}

let reqNo = 0;
class Client {
  constructor(path) {
    this.msgs = []; this.waiters = [];
    this.ws = new WebSocket(`${WS_BASE}${path}`);
    this.ws.addEventListener("message", (e) => {
      const m = JSON.parse(e.data);
      const w = this.waiters.find((x) => x.pred(m));
      if (w) { this.waiters.splice(this.waiters.indexOf(w), 1); w.resolve(m); } else this.msgs.push(m);
    });
    this.open = new Promise((res, rej) => { this.ws.addEventListener("open", res); this.ws.addEventListener("error", rej); });
  }
  send(t, p = {}) { const id = `r${++reqNo}`; this.ws.send(JSON.stringify({ v: 1, t, id, p })); return id; }
  wait(pred, ms = 20000) {
    const i = this.msgs.findIndex(pred);
    if (i >= 0) return Promise.resolve(this.msgs.splice(i, 1)[0]);
    return new Promise((resolve, reject) => {
      const w = { pred, resolve };
      this.waiters.push(w);
      setTimeout(() => { const k = this.waiters.indexOf(w); if (k >= 0) { this.waiters.splice(k, 1); reject(new Error("timeout")); } }, ms);
    });
  }
  close() { try { this.ws.close(); } catch { /* closed */ } }
}

/** Both players queue, get paired and play the match to the end; returns {matchId, seats, recorded: {userId: progress}}. */
async function playQuickMatch(A, B) {
  const q = [A, B].map((u) => ({ u, c: new Client("/v1/queue") }));
  await Promise.all(q.map((x) => x.c.open));
  for (const x of q) { x.c.send("hello", { token: x.u.token }); await x.c.wait((m) => m.t === "welcome"); }
  for (const x of q) x.c.send("queue.join", { mode: "2p", name: x.u.label });
  const found = await Promise.all(q.map((x) => x.c.wait((m) => m.t === "match.found", 30000)));
  for (const x of q) x.c.close();
  const matchId = found[0].p.matchId;
  const players = [];
  for (const [i, x] of q.entries()) {
    const c = new Client(`/v1/match/${matchId}`);
    await c.open;
    c.send("hello", { token: x.u.token });
    const snap = await c.wait((m) => m.t === "match.snapshot");
    players.push({ u: x.u, c, seat: found[i].p.seat, state: snap.p.state });
  }
  const recorded = {};
  for (const p of players) p.c.ws.addEventListener("message", (e) => { const m = JSON.parse(e.data); if (m.t === "match.recorded") recorded[p.u.id] = m.p.progress; });
  let over = false;
  const deadline = Date.now() + 8 * 60000;
  while (!over && Date.now() < deadline) {
    for (const p of players) {
      for (const m of p.c.msgs.splice(0)) if (m.p?.state) p.state = m.p.state;
    }
    const s = players[0].state.turn.phase === "game_over" || players[1].state.turn.phase === "game_over";
    if (s) { over = true; break; }
    const me = players.find((p) => p.state.turn.seat === p.seat);
    if (me) {
      const t = me.state.turn;
      if (t.phase === "roll") me.c.send("action.roll", { turnId: t.turn_id });
      else if (t.phase === "move" && me.state.legal?.length) me.c.send("action.move", { turnId: t.turn_id, pawn: me.state.legal[0].pawn });
    }
    await sleep(130);
  }
  for (let i = 0; i < 100 && Object.keys(recorded).length < 2; i++) await sleep(200);
  for (const p of players) p.c.close();
  return { matchId, players, recorded, over };
}

let accounts = [];
try {
  console.log(`Server: ${BASE}`);
  accounts = await testAccounts(SUPABASE, publishable, 2);
  const [A, B] = accounts;
  sql(resetSql([A.id, B.id]), true);
  sql(`delete from public.player_quests where user_id in ('${A.id}', '${B.id}')`, true);

  console.log("1. A real quick match between two test accounts");
  const g = await playQuickMatch(A, B);
  check(g.over, "match played to the end on the deployed server");
  check(Object.keys(g.recorded).length === 2, "both players got match.recorded with their progress");
  const xps = [A, B].map((u) => g.recorded[u.id]?.xp);
  check(xps.includes(40) && xps.includes(15), `XP from the server: winner 40, loser 15 (${xps.join(" / ")})`);

  console.log("2. Progress and quests (server-side)");
  const pa = await rpc(A.token, "my_progress");
  check(pa.status === 200 && pa.data.xp === g.recorded[A.id].xp && pa.data.level === 1, "my_progress shows the XP from the match");
  const qa = await rpc(A.token, "my_quests");
  check(qa.status === 200 && qa.data.daily.length === 3 && qa.data.weekly.length === 4, "3 daily and 4 weekly quests assigned by the server");
  const matchQuests = [...qa.data.daily, ...qa.data.weekly].filter((q) => q.metric === "matches");
  check(matchQuests.every((q) => q.progress === Math.min(1, q.target)), "the 'complete matches' quests advanced by exactly one match");
  const rolls = sql(`select rolls from public.match_players mp join public.matches m on m.id = mp.match_id where mp.user_id = '${A.id}' and m.mode = 'quick'`)[0]?.rolls ?? 0;
  check(rolls > 0 && [...qa.data.daily].filter((q) => q.metric === "rolls").every((q) => q.progress === Math.min(rolls, q.target)), `dice-roll quest counts the player's own rolls (${rolls})`);

  console.log("3. Claiming: exactly once, also concurrently");
  // a completed quest for A (test data): mark one of A's open daily quests as reached
  const target = qa.data.daily.find((q) => !q.completed) ?? qa.data.daily[0];
  sql(`update public.player_quests set progress = target, completed_at = coalesce(completed_at, now()) where user_id = '${A.id}' and period = 'daily' and quest_id = '${target.quest_id}'`, true);
  const goldBefore = sql(`select coins from public.wallets where user_id = '${A.id}'`)[0].coins;
  const args = { p_period: "daily", p_period_key: target.period_key, p_quest_id: target.quest_id };
  const forged = A.token.split(".").slice(0, 2).join(".") + ".invalidsignature";
  check((await rpc(forged, "claim_quest", args)).status === 401, "a forged JWT cannot claim");
  const other = await rpc(B.token, "claim_quest", args);
  check(other.status >= 400 && /QUEST_NOT_FOUND|NOT_COMPLETED/.test(other.error), "another player's JWT cannot claim A's quest");
  const results = await Promise.all(Array.from({ length: 5 }, () => rpc(A.token, "claim_quest", args)));
  const ok = results.filter((r) => r.status === 200);
  check(ok.length === 1 && results.filter((r) => /ALREADY_CLAIMED/.test(r.error ?? "")).length === 4, "5 concurrent claims: exactly one succeeds, four get ALREADY_CLAIMED");
  const goldAfter = sql(`select coins from public.wallets where user_id = '${A.id}'`)[0].coins;
  check(goldAfter - goldBefore === target.gold + (ok[0].data.level_gold ?? 0), `gold paid once (+${goldAfter - goldBefore})`);

  console.log("4. Direct writes from the client are refused");
  check([401, 403].includes(await rest(A.token, "PATCH", `profiles?user_id=eq.${A.id}`, { xp: 99999, level: 50 })), "client cannot change its XP / level");
  check([401, 403].includes(await rest(A.token, "PATCH", `player_quests?user_id=eq.${A.id}`, { progress: 99 })), "client cannot change quest progress");
  check([401, 403].includes(await rest(A.token, "POST", "xp_events", { user_id: A.id, amount: 500, reason: "match", ref_id: "x", level_after: 3 })), "client cannot write XP events");
  check([401, 403, 404].includes((await rpc(A.token, "_grant_xp", { p_user: A.id, p_amount: 999, p_reason: "match", p_ref: "x" })).status), "client cannot call server-only XP functions");
  console.log(`PROGRESS_CLOUD_PASSED ${passed}`);
} finally {
  if (accounts.length) { sql(resetSql(accounts.map((a) => a.id)), true); sql(`delete from public.player_quests where user_id in (${accounts.map((a) => `'${a.id}'`).join(",")})`, true); console.log("cleanup: test accounts reset"); }
}
