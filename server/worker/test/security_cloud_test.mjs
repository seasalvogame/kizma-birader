// Cloud check of the two post-Phase-5 security fixes, with the reusable test accounts
// (test/test_accounts.mjs; no new guests unless the pool is missing):
//  1. dev route: a test match with another human seat needs that player's JWT (consent);
//  2. quick-match queue: four players (one of them with two connections) join at the same
//     moment, several rounds: nobody is paired twice, every player gets exactly one match.
// Every match created here is ended (a player leaves) and its database record deleted.
//
//   node test/security_cloud_test.mjs <supabase-project-ref> --remote https://...

import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { testAccounts } from "./test_accounts.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "../../..");
const ref = process.argv[2];
const remoteArg = process.argv.indexOf("--remote");
if (!/^[a-z]{20}$/.test(ref ?? "") || remoteArg < 0) throw new Error("usage: node test/security_cloud_test.mjs <project-ref> --remote <url>");
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
function sqlWrite(query) {
  const dir = mkdtempSync(join(tmpdir(), "kb-sql-"));
  const file = join(dir, "q.sql");
  writeFileSync(file, `${query};`);
  try { cli(["db", "query", "--remote", "--yes", "-f", file]); } finally { rmSync(dir, { recursive: true, force: true }); }
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
  wait(pred, ms = 15000) {
    const i = this.msgs.findIndex(pred);
    if (i >= 0) return Promise.resolve(this.msgs.splice(i, 1)[0]);
    return new Promise((resolve, reject) => {
      const w = { pred, resolve };
      this.waiters.push(w);
      setTimeout(() => { const k = this.waiters.indexOf(w); if (k >= 0) { this.waiters.splice(k, 1); reject(new Error("timeout")); } }, ms);
    });
  }
  all(t) { return this.msgs.filter((m) => m.t === t); }
  close() { try { this.ws.close(); } catch { /* closed */ } }
}

const matchIds = new Set();
async function endMatch(matchId, user) {
  const c = new Client(`/v1/match/${matchId}`);
  await c.open;
  c.send("hello", { token: user.token });
  await c.wait((m) => m.t === "match.snapshot");
  c.send("action.leave");
  await c.wait((m) => m.t === "match.events" && m.p.state?.turn?.phase === "game_over").catch(() => {});
  c.close();
}

try {
  console.log(`Server: ${BASE}`);
  const [A, B, C, D] = await testAccounts(SUPABASE, publishable, 4);

  console.log("1. Dev route: consent of every seated player");
  const seats = [{ color: "red", user_id: A.id }, { color: "yellow", user_id: B.id }];
  const post = (headers) => fetch(`${BASE}/v1/dev/matches`, { method: "POST", headers: { authorization: `Bearer ${A.token}`, "content-type": "application/json", ...headers }, body: JSON.stringify({ seats }) });
  let r = await post({});
  check(r.status === 403 && (await r.json()).error === "SEAT_NOT_CONSENTED", "A cannot put B into a match without B's JWT (403 SEAT_NOT_CONSENTED)");
  r = await post({ "x-seat-tokens": "not-a-jwt" });
  check(r.status === 403, "a forged consent token is not accepted");
  r = await post({ "x-seat-tokens": C.token });
  check(r.status === 403, "another player's token does not count as B's consent");
  r = await post({ "x-seat-tokens": B.token });
  const ok = await r.json();
  check(r.status === 200 && /^[0-9a-f]{64}$/.test(ok.matchId), "with B's own JWT the match is created");
  await endMatch(ok.matchId, A);

  console.log("2. Quick-match queue: simultaneous joins, 5 rounds");
  const users = [A, B, C, D];
  for (let round = 1; round <= 5; round++) {
    const conns = users.map((u) => ({ u, c: new Client("/v1/queue") }));
    conns.push({ u: A, c: new Client("/v1/queue"), extra: true });   // A twice: the older connection is replaced
    await Promise.all(conns.map((x) => x.c.open));
    await Promise.all(conns.map(async (x) => { x.c.send("hello", { token: x.u.token }); await x.c.wait((m) => m.t === "welcome"); }));
    // all joins at the same moment
    for (const x of conns) x.c.send("queue.join", { mode: "2p", name: x.u.label });
    await sleep(6000);
    const found = conns.flatMap((x) => x.c.all("match.found").map((m) => ({ user: x.u.id, extra: !!x.extra, ...m.p })));
    if (process.env.KB_DEBUG) console.log(JSON.stringify({ found: found.map((f) => [f.user.slice(0, 4), f.extra, f.matchId.slice(0, 6)]), other: conns.map((x) => [x.u.label, !!x.extra, x.c.msgs.map((m) => m.t + (m.p?.code ? ":" + m.p.code : "") + (m.p?.reason ? ":" + m.p.reason : ""))]) }));
    const perUser = new Map();
    for (const f of found) perUser.set(f.user, (perUser.get(f.user) ?? 0) + 1);
    const byMatch = new Map();
    for (const f of found) byMatch.set(f.matchId, [...(byMatch.get(f.matchId) ?? []), f.user]);
    check(users.every((u) => perUser.get(u.id) === 1), `round ${round}: every player got exactly one match (${found.length} match.found for 4 players)`);
    check(byMatch.size === 2 && [...byMatch.values()].every((us) => us.length === 2 && us[0] !== us[1]), `round ${round}: two matches, each with two different players`);
    for (const [id, us] of byMatch) { matchIds.add(id); await endMatch(id, users.find((u) => u.id === us[0])); }
    for (const x of conns) x.c.close();
    await sleep(500);
  }
  console.log(`SECURITY_CLOUD_PASSED ${passed}`);
} finally {
  // the test matches end by a leave; delete their database records (test accounts only)
  await sleep(4000);
  try {
    const { poolIds } = await import("./test_accounts.mjs");
    const ids = poolIds().slice(0, 4).map((i) => `'${i}'`).join(",");
    if (ids) sqlWrite(`delete from public.matches where id in (select match_id from public.match_players where user_id in (${ids}))`);
    console.log("cleanup: test match records of the test accounts deleted (accounts kept for reuse)");
  } catch (e) { console.log("cleanup failed:", e.message); }
}
