// Phase 5 end-to-end test: private rooms (2 and 4 players), room codes, colours,
// ready / start rules, leaving, reconnecting, the match started from a room (the
// normal MatchRoom), and — when the server has its database — friends (Supabase
// RPCs over REST), live presence, invites (send / accept / duplicate / decline /
// expiry / not friends / blocked) and the Phase 4 match record of a private match.
// Real Supabase guest accounts; every test user and match record is deleted at the end.
//
//   node test/social_room_test.mjs <supabase-project-ref>                       (local wrangler dev, no database)
//   node test/social_room_test.mjs <supabase-project-ref> --remote https://...  (Cloudflare + Supabase)

import { execFileSync, spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join as joinPath, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const workerDir = resolve(here, "..");
const repo = resolve(workerDir, "../..");
const ref = process.argv[2];
if (!/^[a-z]{20}$/.test(ref ?? "")) throw new Error("usage: node test/social_room_test.mjs <project-ref> [--remote <url>]");
const SUPABASE = `https://${ref}.supabase.co`;
const PORT = 8788;
const remoteArg = process.argv.indexOf("--remote");
const REMOTE = remoteArg > 0 ? process.argv[remoteArg + 1].replace(/\/$/, "") : "";
const BASE = REMOTE || `http://127.0.0.1:${PORT}`;
const WS_BASE = BASE.replace(/^http/, "ws");
const WIN = process.platform === "win32";
const npx = WIN ? "npx.cmd" : "npx";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let passed = 0;
const check = (cond, label) => {
  if (!cond) throw new Error(`FAIL ${label}`);
  passed++;
  console.log(`  ok  ${label}`);
};

// ------------------------------------------------------------ server
let devProc = null;
async function startServer() {
  if (!REMOTE) {
    devProc = spawn(npx, ["wrangler", "dev", "--port", String(PORT), "--ip", "127.0.0.1", "--var", "DB_DISABLED:true", "--var", "BOT_DELAY_MS:20"],
      { cwd: workerDir, shell: WIN, stdio: "ignore" });
  }
  for (let i = 0; i < 180; i++) {
    try { const r = await fetch(`${BASE}/v1/health`); if (r.ok) return await r.json(); } catch { /* starting */ }
    await sleep(500);
  }
  throw new Error("server not reachable");
}
function stopServer() {
  if (!devProc) return;
  if (WIN) { try { execFileSync("taskkill", ["/PID", String(devProc.pid), "/T", "/F"], { stdio: "ignore" }); } catch { /* gone */ } }
  else devProc.kill("SIGTERM");
}

// ---------------------------------------------------------- supabase
const cli = (args) => execFileSync(npx, ["supabase", ...args], { cwd: repo, encoding: "utf8", shell: WIN });
const keysOut = cli(["projects", "api-keys", "--project-ref", ref, "-o", "json"]);
const keys = JSON.parse(keysOut.slice(keysOut.indexOf("[")));
const publishable = keys.find((k) => k.type === "publishable")?.api_key ?? keys.find((k) => k.name === "anon")?.api_key;
const users = [];
async function guest(label) {
  const r = await fetch(`${SUPABASE}/auth/v1/signup`, { method: "POST", headers: { apikey: publishable, "content-type": "application/json" }, body: JSON.stringify({ data: {} }) });
  const j = await r.json();
  if (!j.access_token) throw new Error(`guest sign-in failed (${r.status})`);
  users.push(j.user.id);
  return { id: j.user.id, token: j.access_token, label };
}
async function rpc(user, fn, args = {}) {
  const r = await fetch(`${SUPABASE}/rest/v1/rpc/${fn}`, { method: "POST", headers: { apikey: publishable, authorization: `Bearer ${user.token}`, "content-type": "application/json" }, body: JSON.stringify(args) });
  const text = await r.text();
  let data = null;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: r.status, data, error: r.ok ? null : String(data?.message ?? text) };
}
function sql(query, write = false) {
  const dir = mkdtempSync(joinPath(tmpdir(), "kb-sql-"));
  const file = joinPath(dir, "q.sql");
  writeFileSync(file, `${query};`);
  try {
    const out = cli(["db", "query", "--remote", write ? "--yes" : "--read-only", "-f", file, "-o", "json"]);
    return JSON.parse(out.slice(out.indexOf("{"))).rows ?? [];
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
function cleanup() {
  if (!users.length) return;
  const ids = users.map((i) => `'${i}'`).join(",");
  sql(`delete from public.matches where id in (select match_id from public.match_players where user_id in (${ids}))`, true);
  sql(`delete from auth.users where id in (${ids})`, true);
  console.log(`cleanup: deleted ${users.length} test users and their match records`);
}

// ------------------------------------------------------------ client
let reqNo = 0;
class Client {
  constructor(path) {
    this.msgs = []; this.waiters = []; this.closed = false;
    this.ws = new WebSocket(`${WS_BASE}${path}`);
    this.ws.addEventListener("message", (e) => {
      const m = JSON.parse(e.data);
      const w = this.waiters.find((x) => x.pred(m));
      if (w) { this.waiters.splice(this.waiters.indexOf(w), 1); w.resolve(m); } else this.msgs.push(m);
    });
    this.ws.addEventListener("close", () => { this.closed = true; });
    this.open = new Promise((res, rej) => { this.ws.addEventListener("open", res); this.ws.addEventListener("error", rej); });
  }
  send(t, p = {}) { const id = `r${++reqNo}`; this.ws.send(JSON.stringify({ v: 1, t, id, p })); return id; }
  wait(pred, ms = 10000) {
    const i = this.msgs.findIndex(pred);
    if (i >= 0) return Promise.resolve(this.msgs.splice(i, 1)[0]);
    return new Promise((resolve, reject) => {
      const w = { pred, resolve };
      this.waiters.push(w);
      setTimeout(() => { const k = this.waiters.indexOf(w); if (k >= 0) { this.waiters.splice(k, 1); reject(new Error("timeout waiting for message")); } }, ms);
    });
  }
  reply(id, ms) { return this.wait((m) => m.re === id, ms); }
  /** Latest room.state (drops older ones). */
  async state(pred = () => true, ms = 10000) {
    for (;;) {
      const m = await this.wait((x) => x.t === "room.state", ms);
      if (this.msgs.some((x) => x.t === "room.state")) continue;   // a newer state is already queued
      if (pred(m.p)) return m.p;
    }
  }
  close() { try { this.ws.close(); } catch { /* ignore */ } }
}
async function hello(c, user) {
  await c.open;
  return c.reply(c.send("hello", { token: user.token }));
}
async function createRoom(user, players) {
  const r = await fetch(`${BASE}/v1/rooms`, { method: "POST", headers: { authorization: `Bearer ${user.token}`, "content-type": "application/json" }, body: JSON.stringify({ players }) });
  return { status: r.status, body: await r.json() };
}
async function enter(user, code) {
  const c = new Client(`/v1/room/${code}`);
  const w = await hello(c, user);
  return { c, w };
}
function otherCode(code) {
  const a = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  let x = "";
  do { x = Array.from({ length: 6 }, () => a[Math.floor(Math.random() * a.length)]).join(""); } while (x === code);
  return x;
}
/** Plays a started match on the normal MatchRoom by leaving with every seat but `winner`. */
async function finishByLeaving(started, players, winner) {
  const conns = [];
  for (const [u, s] of started) {
    const c = new Client(`/v1/match/${s.matchId}`);
    const w = await hello(c, u);
    const snap = await c.wait((m) => m.t === "match.snapshot");
    conns.push({ u, c, w, snap, seat: s.seat });
  }
  for (const x of conns) if (x.u !== winner) { await x.c.reply(x.c.send("action.leave")); await sleep(150); }
  const w = conns.find((x) => x.u === winner);
  for (;;) {
    const m = await w.c.wait((x) => x.t === "match.events" || x.t === "match.snapshot", 20000);
    const st = m.p.state;
    if (st?.turn?.phase === "game_over") break;
  }
  for (const x of conns) x.c.close();
  return conns;
}

// ------------------------------------------------------------------ run
const clients = [];
try {
  console.log(REMOTE ? `Server: Cloudflare ${BASE}` : "Server: local wrangler dev (no database)");
  const health = await startServer();
  const DB = !!health.db;
  const [A, B, C, D, E] = await Promise.all(["A", "B", "C", "D", "E"].map(guest));

  console.log("Private room, 2 players");
  check((await createRoom({ token: "bad" }, 2)).status === 401, "room creation without a valid JWT is refused");
  check((await createRoom(A, 3)).body.error === "BAD_PLAYERS", "only 2- or 4-player rooms");
  const r2 = await createRoom(A, 2);
  const code = r2.body.code;
  check(r2.status === 200 && /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/.test(code), `room created with an unguessable 6-character code (${code})`);
  check((await createRoom(A, 2)).body.error === "ALREADY_IN_ROOM", "one room per player at a time");
  const a = await enter(A, code); clients.push(a.c);
  let st = await a.c.state();
  check(st.host === A.id && st.members.length === 1 && st.members[0].color === "red", "host is in the lobby (red)");
  const wrong = await enter(B, otherCode(code)); clients.push(wrong.c);
  check(wrong.w.p?.code === "ROOM_NOT_FOUND", "a wrong code is refused (ROOM_NOT_FOUND)");
  const b = await enter(B, code); clients.push(b.c);
  st = await a.c.state((s) => s.members.length === 2);
  const mb = st.members.find((m) => m.userId === B.id);
  check(mb && mb.color === "yellow", "second player joins by code and gets the opposite colour (yellow)");
  await a.c.reply(a.c.send("room.color", { color: "green" }));
  st = await b.c.state((s) => s.members.some((m) => m.userId === A.id && m.color === "green"));
  check(st.members.find((m) => m.userId === B.id).color === "blue", "2 players: picking green moves the other player to blue (opposite only)");
  const full = await enter(C, code); clients.push(full.c);
  check(full.w.p?.code === "ROOM_FULL", "a third player cannot enter a full 2-player room");
  check((await b.c.reply(b.c.send("room.start"))).p?.code === "NOT_HOST", "only the host can start (NOT_HOST)");
  check((await a.c.reply(a.c.send("room.start"))).p?.code === "NOT_READY", "start is refused while the other player is not ready");
  check((await b.c.reply(b.c.send("room.color", { color: "purple" }))).p?.code === "INVALID_MESSAGE", "an unknown colour is refused");
  // reconnect: the member stays in the room
  b.c.close();
  await sleep(300);
  const b2 = await enter(B, code); clients.push(b2.c);
  st = await b2.c.state();
  check(st.members.some((m) => m.userId === B.id && m.connected), "a dropped player reconnects to the same seat in the lobby");
  await b2.c.reply(b2.c.send("room.ready", { ready: true }));
  await a.c.state((s) => s.members.find((m) => m.userId === B.id)?.ready);
  check((await a.c.reply(a.c.send("room.start"))).t === "ok", "host starts when the room is full and the other player is ready");
  const sa = await a.c.wait((m) => m.t === "room.started");
  const sb = await b2.c.wait((m) => m.t === "room.started");
  check(sa.p.matchId === sb.p.matchId && /^[0-9a-f]{64}$/.test(sa.p.matchId), "both players get the same match (normal MatchRoom)");
  check(sa.p.color === "green" && sb.p.color === "blue", "the match uses the colours chosen in the lobby");
  const mine = await (await fetch(`${BASE}/v1/rooms/mine`, { headers: { authorization: `Bearer ${A.token}` } })).json();
  check(mine.match === sa.p.matchId, "the directory knows the player is in a match");
  const busy = await createRoom(A, 4);
  check(busy.body.error === "ALREADY_IN_ROOM" || busy.body.error === "IN_MATCH", "a player in a room / match cannot open another room");
  const conns = await finishByLeaving([[A, sa.p], [B, sb.p]], 2, A);
  check(conns.length === 2, "match played on the server until game over (B left)");
  st = await a.c.state((s) => s.phase === "lobby" && s.games === 1, 20000);
  check(st.members.length === 2 && st.members.every((m) => !m.ready), "after the match the room is a lobby again (play again)");
  if (DB) {
    let row = null;
    for (let i = 0; i < 20 && !row; i++) {
      [row] = sql(`select m.mode, m.players, m.end_reason, (select string_agg(mp.color || ':' || mp.rank, ',' order by mp.rank) from public.match_players mp where mp.match_id = m.id) as ranks
        from public.matches m join public.match_players p on p.match_id = m.id where p.user_id = '${A.id}' and m.mode = 'private'`);
      if (!row) await sleep(1500);
    }
    check(row && row.mode === "private" && row.players === 2 && row.ranks === "green:1,blue:2", "private match recorded in Supabase (mode private, places)");
    const [stats] = sql(`select matches_2p, wins_2p from public.player_stats where user_id = '${A.id}'`);
    check(stats.matches_2p === 1 && stats.wins_2p === 1, "private match counted once in the player's stats");
  }

  console.log("Leaving and host change");
  await b2.c.reply(b2.c.send("room.leave"));
  st = await a.c.state((s) => s.members.length === 1);
  check(st.host === A.id, "a member leaves the lobby");
  const b3 = await enter(B, code); clients.push(b3.c);
  await a.c.state((s) => s.members.length === 2);
  await a.c.reply(a.c.send("room.leave"));
  st = await b3.c.state((s) => s.members.length === 1);
  check(st.host === B.id, "when the host leaves, the next player becomes host");
  await b3.c.reply(b3.c.send("room.leave"));
  const gone = await enter(D, code); clients.push(gone.c);
  check(gone.w.p?.code === "ROOM_NOT_FOUND", "an empty room is closed and its code no longer works");

  console.log("Private room, 4 players");
  const r4 = await createRoom(A, 4);
  const code4 = r4.body.code;
  const p = [A, B, C, D];
  const cs = [];
  for (const u of p) { const x = await enter(u, code4); clients.push(x.c); cs.push(x.c); }
  st = await cs[0].state((s) => s.members.length === 4);
  check(new Set(st.members.map((m) => m.color)).size === 4, "four players join and get four different colours");
  const colorOf = (s, u) => s.members.find((m) => m.userId === u.id).color;
  check((await cs[2].reply(cs[2].send("room.color", { color: colorOf(st, A) }))).p?.code === "COLOR_TAKEN", "a colour that is taken is refused (COLOR_TAKEN)");
  const extra = await enter(E, code4); clients.push(extra.c);
  check(extra.w.p?.code === "ROOM_FULL", "a fifth player cannot enter");
  for (const c of cs.slice(1, 3)) await c.reply(c.send("room.ready", { ready: true }));
  check((await cs[0].reply(cs[0].send("room.start"))).p?.code === "NOT_READY", "4 players: start refused while one player is not ready");
  await cs[3].reply(cs[3].send("room.ready", { ready: true }));
  await cs[0].state((s) => s.members.filter((m) => m.ready).length === 3);
  check((await cs[0].reply(cs[0].send("room.start"))).t === "ok", "host starts the 4-player match");
  const started = [];
  for (const [i, c] of cs.entries()) started.push([p[i], (await c.wait((m) => m.t === "room.started")).p]);
  check(new Set(started.map(([, s]) => s.matchId)).size === 1 && started[0][1].seats.length === 4, "all four get the same 4-player match");
  check(started[0][1].seats.map((s) => s.color).join(",") === "red,green,yellow,blue", "seats follow the board order (clockwise colours)");
  await finishByLeaving(started, 4, C);
  check(true, "4-player match ended on the server (three players left)");
  if (DB) {
    let rows = [];
    for (let i = 0; i < 20 && rows.length === 0; i++) {
      rows = sql(`select m.id from public.matches m join public.match_players mp on mp.match_id = m.id where m.players = 4 and m.mode = 'private' and mp.user_id = '${C.id}' and mp.rank = 1`);
      if (!rows.length) await sleep(1500);
    }
    check(rows.length === 1, "4-player private match recorded with the winner in first place");
  }
  for (const c of cs) { await c.reply(c.send("room.leave")).catch(() => {}); }

  console.log("Room code rate limit");
  let limited = false;
  for (let i = 0; i < 10 && !limited; i++) {
    const x = await enter(E, otherCode(""));
    clients.push(x.c);
    limited = x.w.p?.code === "RATE_LIMITED";
  }
  const r5 = await createRoom(D, 2);
  const tryValid = await enter(E, r5.body.code); clients.push(tryValid.c);
  check(limited && tryValid.w.p?.code === "RATE_LIMITED", "after 8 wrong codes even a valid code is refused for that player (RATE_LIMITED)");

  if (DB) {
    console.log("Friends, presence and invites (Supabase + hub)");
    const req = await rpc(A, "send_friend_request", { p_to: B.id });
    check(req.status === 200 && req.data.status === "pending", "A sends B a friend request (REST RPC, user from JWT)");
    check((await rpc(A, "send_friend_request", { p_to: B.id })).error?.includes("ALREADY_PENDING"), "a second request is refused");
    const ha = new Client("/v1/hub"); clients.push(ha);
    check((await hello(ha, A)).t === "welcome", "A connects to the social hub");
    const hb = new Client("/v1/hub"); clients.push(hb);
    await hello(hb, B);
    await ha.reply(ha.send("poke", { to: B.id, kind: "friend_request" }));
    check((await hb.wait((m) => m.t === "social.changed")).p.kind === "friend_request", "B is told live that a request arrived");
    const inc = await rpc(B, "my_friend_requests");
    check(inc.data.some((x) => x.direction === "in" && x.user_id === A.id), "B sees the incoming request");
    check((await rpc(B, "respond_friend_request", { p_request_id: req.data.request_id, p_accept: true })).data.status === "accepted", "B accepts");
    await hb.reply(hb.send("friends.changed", { other: A.id }));
    const pres = await ha.wait((m) => m.t === "presence.list" && m.p.friends.some((f) => f.userId === B.id));
    check(pres.p.friends.find((f) => f.userId === B.id).status === "online", "A sees B online right after the friendship (no polling)");
    hb.close();
    check((await ha.wait((m) => m.t === "presence" && m.p.userId === B.id && m.p.status === "offline")).p.status === "offline", "A sees B go offline when B's app disconnects");
    const hb2 = new Client("/v1/hub"); clients.push(hb2);
    await hello(hb2, B);
    await ha.wait((m) => m.t === "presence" && m.p.userId === B.id && m.p.status === "online");
    check(true, "A sees B online again");

    const ri = await createRoom(A, 2);
    const ci = ri.body.code;
    const ai = await enter(A, ci); clients.push(ai.c);
    const sent = await ha.reply(ha.send("invite.send", { to: B.id, code: ci }));
    check(sent.t === "invite.sent", "A invites friend B to the private room");
    const inv = await hb2.wait((m) => m.t === "invite.new");
    check(inv.p.invite.code === ci && inv.p.invite.from === A.id, "B receives the invite live");
    check((await ha.reply(ha.send("invite.send", { to: B.id, code: ci }))).p.duplicate === true, "inviting again does not create a second invite");
    check((await ha.reply(ha.send("invite.send", { to: C.id, code: ci }))).p.code === "NOT_FRIENDS", "only friends can be invited");
    const acc = await hb2.reply(hb2.send("invite.accept", { inviteId: inv.p.invite.id }));
    check(acc.t === "invite.accepted" && acc.p.code === ci, "B accepts and gets the room code");
    check((await ha.wait((m) => m.t === "invite.update")).p.status === "accepted", "A is told that B accepted");
    check((await hb2.reply(hb2.send("invite.accept", { inviteId: inv.p.invite.id }))).p.repeated === true, "accepting twice is processed once");
    const bi = await enter(B, acc.p.code); clients.push(bi.c);
    st = await ai.c.state((s) => s.members.length === 2);
    check(st.members.some((m) => m.userId === B.id), "B joins the room through the invite");
    await bi.c.reply(bi.c.send("room.leave"));
    await ai.c.state((s) => s.members.length === 1);
    const inv2 = await ha.reply(ha.send("invite.send", { to: B.id, code: ci }));
    await hb2.wait((m) => m.t === "invite.new");
    await hb2.reply(hb2.send("invite.decline", { inviteId: inv2.p.invite.id }));
    check((await ha.wait((m) => m.t === "invite.update" && m.p.status === "declined")).p.status === "declined", "a declined invite is reported to the sender");
    // B is in another room -> accepting an invite is refused
    const rb = await createRoom(B, 2);
    const inv3 = await ha.reply(ha.send("invite.send", { to: B.id, code: ci }));
    await hb2.wait((m) => m.t === "invite.new");
    check((await hb2.reply(hb2.send("invite.accept", { inviteId: inv3.p.invite.id }))).p.code === "ALREADY_IN_ROOM", "a player already in a room cannot accept (ALREADY_IN_ROOM)");
    const bb = await enter(B, rb.body.code); clients.push(bb.c);
    await bb.c.reply(bb.c.send("room.leave"));
    // block: no more invites
    await rpc(B, "block_player", { p_other: A.id });
    await hb2.reply(hb2.send("friends.changed", { other: A.id }));
    check((await ha.reply(ha.send("invite.send", { to: B.id, code: ci }))).p.code === "NOT_ALLOWED", "a blocked player cannot be invited");
    await rpc(B, "unblock_player", { p_other: A.id });
    // expiry (2 minutes)
    await rpc(A, "send_friend_request", { p_to: B.id });
    const reqs = await rpc(B, "my_friend_requests");
    await rpc(B, "respond_friend_request", { p_request_id: reqs.data.find((x) => x.user_id === A.id).id, p_accept: true });
    await hb2.reply(hb2.send("friends.changed", { other: A.id }));
    const inv4 = await ha.reply(ha.send("invite.send", { to: B.id, code: ci }));
    check(inv4.t === "invite.sent", "friends again: invite sent (waiting 2 minutes for it to expire)");
    const exp = await hb2.wait((m) => m.t === "invite.update" && m.p.inviteId === inv4.p.invite.id && m.p.status === "expired", 150000);
    check(exp.p.status === "expired", "an unanswered invite expires after 2 minutes and both players are told");
    check((await hb2.reply(hb2.send("invite.accept", { inviteId: inv4.p.invite.id }))).p.code === "INVITE_EXPIRED", "an expired invite cannot be accepted");
    await ai.c.reply(ai.c.send("room.leave"));
  } else {
    console.log("(no database on this server: friends, presence and invites are checked with --remote)");
  }
  console.log(`SOCIAL_ROOM_PASSED ${passed}`);
} finally {
  for (const c of clients) c.close();
  stopServer();
  try { cleanup(); } catch (e) { console.log("cleanup failed:", e.message); }
}
