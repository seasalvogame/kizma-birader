// Local end-to-end test of the game server under `wrangler dev` (workerd).
// Real Supabase guest accounts provide the JWTs (public JWKS verification);
// everything else runs locally. Test users are deleted at the end.
//
//   node test/local_ws_test.mjs <supabase-project-ref>
//
// Covers: health, dev-route auth and colour rules, JWT rejection, seat binding,
// out-of-turn and forged messages, idempotent resend, a full 2-player match
// between two real clients (dice bound after two sixes checked on every roll),
// reconnect with snapshot, server restart with persisted state, and turn
// timeouts -> autopilot -> a bot match that finishes by itself.

import { execFileSync, spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join as joinPath, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const workerDir = resolve(here, "..");
const repo = resolve(workerDir, "../..");
const ref = process.argv[2];
if (!/^[a-z]{20}$/.test(ref ?? "")) throw new Error("usage: node test/local_ws_test.mjs <project-ref>");
const SUPABASE = `https://${ref}.supabase.co`;
const PORT = 8787;
const BASE = `http://127.0.0.1:${PORT}`;
const WIN = process.platform === "win32";
const npx = WIN ? "npx.cmd" : "npx";

let passed = 0;
const check = (cond, label) => {
  if (!cond) throw new Error(`FAIL ${label}`);
  passed++;
  console.log(`  ok  ${label}`);
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ------------------------------------------------------------ wrangler dev
let devProc = null;
async function startDev() {
  devProc = spawn(npx, ["wrangler", "dev", "--port", String(PORT), "--ip", "127.0.0.1", "--var", "BOT_DELAY_MS:20"],
    { cwd: workerDir, shell: WIN, stdio: ["ignore", "pipe", "pipe"] });
  let log = "";
  devProc.stdout.on("data", (d) => { log += d; });
  devProc.stderr.on("data", (d) => { log += d; });
  for (let i = 0; i < 180; i++) {
    try {
      const r = await fetch(`${BASE}/v1/health`);
      if (r.ok) return;
    } catch { /* not up yet */ }
    await sleep(500);
  }
  throw new Error("wrangler dev did not start:\n" + log.slice(-2000));
}
async function stopDev() {
  if (!devProc) return;
  if (WIN) { try { execFileSync("taskkill", ["/PID", String(devProc.pid), "/T", "/F"], { stdio: "ignore" }); } catch { /* gone */ } }
  else devProc.kill("SIGTERM");
  devProc = null;
  for (let i = 0; i < 40; i++) {
    try { await fetch(`${BASE}/v1/health`); await sleep(250); } catch { return; }
  }
}

// --------------------------------------------------------- supabase users
const cli = (args) => execFileSync(npx, ["supabase", ...args], { cwd: repo, encoding: "utf8", shell: WIN });
const keysOut = cli(["projects", "api-keys", "--project-ref", ref, "-o", "json"]);
const keys = JSON.parse(keysOut.slice(keysOut.indexOf("[")));
const publishable = keys.find((k) => k.type === "publishable")?.api_key ?? keys.find((k) => k.name === "anon")?.api_key;
const createdUsers = [];
async function guest() {
  const r = await fetch(`${SUPABASE}/auth/v1/signup`, { method: "POST", headers: { apikey: publishable, "content-type": "application/json" }, body: JSON.stringify({ data: {} }) });
  const j = await r.json();
  if (!j.access_token) throw new Error(`guest sign-in failed (${r.status})`);
  createdUsers.push(j.user.id);
  return { id: j.user.id, token: j.access_token };
}
function deleteUsers() {
  if (!createdUsers.length) return;
  const dir = mkdtempSync(joinPath(tmpdir(), "kb-ws-"));
  const file = joinPath(dir, "cleanup.sql");
  writeFileSync(file, `delete from auth.users where id in (${createdUsers.map((i) => `'${i}'`).join(",")});\n`);
  try { cli(["db", "query", "--remote", "--yes", "-f", file]); } finally { rmSync(dir, { recursive: true, force: true }); }
  console.log(`cleanup: deleted ${createdUsers.length} test users`);
}

// --------------------------------------------------------------- client
let reqNo = 0;
class Client {
  constructor(matchId) {
    this.msgs = [];
    this.waiters = [];
    this.closed = false;
    this.ws = new WebSocket(`ws://127.0.0.1:${PORT}/v1/match/${matchId}`);
    this.ws.addEventListener("message", (e) => {
      const m = JSON.parse(e.data);
      // A message goes to the first matching waiter, otherwise into the queue (never both).
      const w = this.waiters.find((x) => x.pred(m));
      if (w) { this.waiters.splice(this.waiters.indexOf(w), 1); w.resolve(m); } else this.msgs.push(m);
    });
    this.ws.addEventListener("close", () => { this.closed = true; });
    this.open = new Promise((res, rej) => { this.ws.addEventListener("open", res); this.ws.addEventListener("error", rej); });
  }
  send(t, p, id = `r${++reqNo}`) { this.ws.send(JSON.stringify({ v: 1, t, id, p })); return id; }
  sendRaw(o) { this.ws.send(JSON.stringify(o)); }
  wait(pred, ms = 8000) {
    const found = this.msgs.find(pred);
    if (found) { this.msgs.splice(this.msgs.indexOf(found), 1); return Promise.resolve(found); }
    return new Promise((resolve, reject) => {
      const w = { pred, resolve };
      this.waiters.push(w);
      setTimeout(() => { const i = this.waiters.indexOf(w); if (i >= 0) { this.waiters.splice(i, 1); reject(new Error("timeout waiting for message")); } }, ms);
    });
  }
  reply(id, ms) { return this.wait((m) => m.re === id, ms); }
  close() { try { this.ws.close(); } catch { /* ignore */ } }
}

async function createMatch(token, seats, extra = {}) {
  const r = await fetch(`${BASE}/v1/dev/matches`, { method: "POST", headers: { authorization: `Bearer ${token}`, "content-type": "application/json" }, body: JSON.stringify({ seats, ...extra }) });
  return { status: r.status, body: await r.json() };
}

async function join(matchId, user) {
  const c = new Client(matchId);
  await c.open;
  const id = c.send("hello", { token: user.token });
  const welcome = await c.reply(id);
  const snap = await c.wait((m) => m.t === "match.snapshot");
  return { c, welcome, snap };
}

// ------------------------------------------------------------------ run
try {
  console.log("Server");
  await startDev();
  check(true, "wrangler dev (local workerd) started and /v1/health answers");

  const A = await guest(), B = await guest(), C = await guest();
  console.log("Dev route and colour rules");
  const seatsAB = [{ color: "red", user_id: A.id, name: "A" }, { color: "yellow", user_id: B.id, name: "B" }];
  check((await createMatch("not-a-jwt", seatsAB)).status === 401, "match creation without a valid JWT is refused (401)");
  check((await createMatch(A.token, [{ color: "red", user_id: A.id }, { color: "green", user_id: B.id }])).body.error === "COLOR_INVALID", "2 players must sit opposite (red–green refused)");
  check((await createMatch(C.token, seatsAB)).status === 403, "a user cannot create a match they are not in (403)");
  const created = await createMatch(A.token, seatsAB, { first_seat: 0 });
  check(created.status === 200 && /^[0-9a-f]{64}$/.test(created.body.matchId), "match created as its own Durable Object");
  const matchId = created.body.matchId;

  console.log("Authentication and seat binding");
  const bad = new Client(matchId);
  await bad.open;
  const tampered = A.token.slice(0, -4) + (A.token.endsWith("AAAA") ? "BBBB" : "AAAA");
  const badId = bad.send("hello", { token: tampered });
  check((await bad.reply(badId)).p.code === "AUTH_INVALID", "tampered JWT -> AUTH_INVALID");
  const cc = new Client(matchId);
  await cc.open;
  const ccId = cc.send("hello", { token: C.token });
  check((await cc.reply(ccId)).p.code === "NOT_IN_MATCH", "valid JWT of a non-player -> NOT_IN_MATCH");
  const noAuth = new Client(matchId);
  await noAuth.open;
  const naId = noAuth.send("action.roll", { turnId: 1 });
  check((await noAuth.reply(naId)).p.code === "AUTH_REQUIRED", "actions before hello are refused");
  noAuth.close();
  let a = await join(matchId, A), b = await join(matchId, B);
  check(a.welcome.p.seat === 0 && b.welcome.p.seat === 1, "each JWT is bound to its own seat");
  check(a.snap.p.state.turn.seat === 0 && a.snap.p.state.turn.phase === "roll", "snapshot: red to roll");

  console.log("Server authority");
  const oot = b.c.send("action.roll", { turnId: 1 });
  check((await b.c.reply(oot)).p.code === "NOT_YOUR_TURN", "rolling out of turn -> NOT_YOUR_TURN");
  const forged = `f${++reqNo}`;
  a.c.sendRaw({ v: 1, t: "action.roll", id: forged, p: { turnId: 1, dice: 6 } });
  check((await a.c.reply(forged)).p.code === "INVALID_MESSAGE", "a dice value from the client is rejected (INVALID_MESSAGE)");
  const seatField = `f${++reqNo}`;
  a.c.sendRaw({ v: 1, t: "action.roll", id: seatField, p: { turnId: 1, seat: 1 } });
  check((await a.c.reply(seatField)).p.code === "INVALID_MESSAGE", "a seat number from the client is rejected");
  const first = a.c.send("action.roll", { turnId: 1 }, "same-id-1");
  const r1 = await a.c.reply(first);
  check(r1.t === "ok", "roll accepted");
  const ev1 = await a.c.wait((m) => m.t === "match.events");
  const seqAfter = ev1.seq;
  const again = a.c.send("action.roll", { turnId: 1 }, "same-id-1");
  const r2 = await a.c.reply(again);
  check(r2.p.duplicate === true && r2.p.seq === r1.p.seq, "resent request id -> first result again, no second roll");

  console.log("Rate limiting");
  const flood = [];
  for (let i = 0; i < 40; i++) flood.push(b.c.send("action.roll", { turnId: 999 }));
  const floodReplies = await Promise.all(flood.map((id) => b.c.reply(id)));
  const limitedCount = floodReplies.filter((m) => m.p.code === "RATE_LIMITED").length;
  check(limitedCount >= 5, `a burst of 40 messages is cut by the rate limiter (${limitedCount} refused)`);
  await sleep(3500);   // let the bucket refill

  console.log("Full 2-player match between two real clients");
  let state = { turn: ev1.p.turn, legal: ev1.p.legal, seq: seqAfter };
  let actions = 1, rolls = 1, limited = 0, badDice = 0, reconnected = false, restarted = false;
  const clients = () => [a.c, b.c];
  const track = (m) => {
    for (const e of m.p.events) {
      if (e.type === "dice_rolled" && (e.value < 1 || e.value > 6)) badDice++;
    }
    state = { turn: m.p.turn, legal: m.p.legal, seq: m.seq };
  };
  while (state.turn.phase !== "game_over" && actions < 3000) {
    const seat = state.turn.seat;
    const me = clients()[seat];
    const before = state.turn.sixes;
    const id = state.turn.phase === "roll"
      ? me.send("action.roll", { turnId: state.turn.turn_id })
      : me.send("action.move", { turnId: state.turn.turn_id, pawn: state.legal[0].pawn });
    const res = await me.reply(id);
    if (res.t !== "ok") throw new Error(`action refused: ${res.p.code}`);
    const ev = await me.wait((m) => m.t === "match.events" && m.seq === res.p.seq);
    clients()[1 - seat].msgs = clients()[1 - seat].msgs.filter((m) => m.t !== "match.events");
    const rolled = ev.p.events.find((e) => e.type === "dice_rolled");
    if (rolled && state.turn.phase === "roll") {
      rolls++;
      if (before === 2) { limited++; if (rolled.value === 6) badDice++; }
    }
    track(ev);
    actions++;
    await sleep(120);
    if (!reconnected && actions === 60) {
      a.c.close();
      await sleep(200);
      a = await join(matchId, A);
      check(a.snap.seq === state.seq && a.snap.p.state.turn.turn_id === state.turn.turn_id, `reconnect after ${actions} actions -> full snapshot at seq ${state.seq}`);
      reconnected = true;
    }
    if (!restarted && actions === 120) {
      const seqBefore = state.seq;
      await stopDev();
      await startDev();
      a = await join(matchId, A);
      b = await join(matchId, B);
      check(a.snap.seq === seqBefore && a.snap.p.state.turn.turn_id === state.turn.turn_id, `server restart after ${actions} actions -> match continues from seq ${seqBefore}`);
      state = { turn: a.snap.p.state.turn, legal: a.snap.p.state.legal, seq: a.snap.seq };
      restarted = true;
    }
  }
  check(state.turn.phase === "game_over", `match finished on the server (${actions} actions, ${rolls} rolls)`);
  check(badDice === 0, `every die was 1..6 and the ${limited} rolls after two sixes were never 6`);

  console.log("Timeouts, autopilot and bots (alarms)");
  const t = await createMatch(A.token, [{ color: "green", user_id: A.id, name: "A" }, { color: "blue", is_bot: true }],
    { first_seat: 0, ruleset: { turn_roll_seconds: 1, turn_move_seconds: 1 } });
  const tm = await join(t.body.matchId, A);
  let autopilot = false, over = false, timedOut = false;
  const deadline = Date.now() + 180000;
  while (!over && Date.now() < deadline) {
    const m = await tm.c.wait((x) => x.t === "match.events", 20000);
    for (const e of m.p.events) {
      if (e.type === "dice_rolled" && e.auto && e.seat === 0) timedOut = true;
      if (e.type === "autopilot_changed" && e.on && e.seat === 0) autopilot = true;
    }
    if (m.p.turn.phase === "game_over") over = true;
  }
  check(timedOut, "an idle player's turn is played by the server when the timer runs out");
  check(autopilot, "after 3 timeouts the player switches to autopilot");
  check(over, "bot + autopilot match runs to the end on server alarms alone");
  tm.c.close();
  for (const c of [a.c, b.c, bad, cc]) c.close();
  console.log(`LOCAL_WS_PASSED ${passed}`);
} finally {
  await stopDev();
  deleteUsers();
}
