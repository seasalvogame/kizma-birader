// MatchRoom — one Durable Object per match: the single authority of the game
// state (CLOUDFLARE_ARCHITECTURE §3.3). It reuses the TypeScript rules engine
// unchanged. The client only sends requests (roll / move / leave); dice are
// drawn here with the Web Crypto source and the 1..5 bound after two sixes.
//
// Persistence: the whole match record is written after every accepted action
// (strategy B, K-60: one storage write per action, timers in one alarm).
// WebSockets use the Hibernation API; nothing important lives only in memory.
//
// Match result (Phase 4): at game over the server builds the result from its
// own state and records it with game.record_match (one database transaction,
// idempotent per match). The pending record lives in this object's storage and
// is retried by the alarm until the database confirms it, so neither a dropped
// connection nor a restart can lose it or store it twice.

import { DurableObject } from "cloudflare:workers";
import {
  Action, cryptoDice, createGame, GameEngine, GameEvent, GameState, maxDiceValue, stateHash,
} from "../../game-engine/src/index.js";
import { verifySupabaseJwt } from "./auth.js";
import { dbConfigured, PlayerProgress, recordMatch } from "./db.js";
import { ClientMessage, parseClientMessage, ProtocolError } from "./protocol.js";

export interface Env {
  MATCH_ROOM: DurableObjectNamespace<MatchRoom>;
  MATCHMAKER: DurableObjectNamespace;
  SOCIAL_HUB: DurableObjectNamespace;
  PRIVATE_ROOM: DurableObjectNamespace;
  SUPABASE_URL: string;
  ALLOW_DEV_ROUTES: string;
  BOT_DELAY_MS: string;
  /** Worker secret: postgres connection of the restricted game_server role (never in git). */
  DATABASE_URL?: string;
  HYPERDRIVE?: Hyperdrive;          // Postgres via Cloudflare Hyperdrive (game_server role)
  DB_DISABLED?: string;
  CF_VERSION_METADATA?: { id: string; tag?: string };
}

export type MatchMode = "quick" | "private" | "test";

export interface SeatInfo {
  seat: number;
  color: "red" | "green" | "yellow" | "blue";
  user_id: string | null;
  is_bot: boolean;
  name: string;
  /** Server-verified purely visual choices, fixed for this match. */
  cosmetics?: Record<string, string>;
  /** Phrases allowed by the same server-verified emote set. */
  emotes?: string[];
}

interface StoredResult { ok: boolean; error?: string; seq: number }

interface MatchRecord {
  id: string;
  state: GameState;
  seats: SeatInfo[];
  seq: number;                 // increases with every accepted action
  deadline: number;            // epoch ms of the current turn timer (0 = none)
  seen: Record<string, Record<string, StoredResult>>;   // seat -> request id -> first result (idempotency)
  created_at: number;
  mode: MatchMode;
  db_id: string;               // uuid of the database record (fixed at creation: idempotent recording)
  log: string[];               // compact actions: r6 m0 t3 t l1 (replayable with the engine)
  ended_at?: number;
  db?: { status: "pending" | "done" | "skipped"; attempts: number; error?: string; progress?: Record<string, PlayerProgress> };
  counts?: Record<number, SeatCounts>;   // per seat, for quests and achievements (Phase 6)
  emote_times?: Record<number, number[]>; // server rate-limit window (epoch ms), persisted across hibernation
  room?: string;               // private room code (the room becomes a lobby again at game over)
}

interface Attachment { authed: boolean; userId?: string; seat?: number }
interface SeatCounts { rolls: number; sixes: number; captures: number; finished: number }

/** {re: id} when the raw message carries a readable request id (errors can then be matched). */
function requestId(raw: string | ArrayBuffer): { re?: string } {
  if (typeof raw !== "string" || raw.length > 8192) return {};
  try {
    const id = (JSON.parse(raw) as { id?: unknown }).id;
    return typeof id === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(id) ? { re: id } : {};
  } catch {
    return {};
  }
}

const SEEN_PER_SEAT = 32;
const RATE_BURST = 30;          // messages
const RATE_PER_SEC = 10;
const MAX_PINGS = 3;

export class MatchRoom extends DurableObject<Env> {
  private engine = new GameEngine();
  /** Changes whenever this object starts (cold start, eviction, new deploy): lets tests prove a restart. */
  private readonly boot = crypto.randomUUID().slice(0, 8);
  private record: MatchRecord | null = null;
  private buckets = new Map<WebSocket, { tokens: number; at: number; pings: number }>();

  // ----------------------------------------------------------------- HTTP
  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/init" && request.method === "POST") return this.init(await request.json());
    if (request.headers.get("Upgrade") === "websocket") {
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair) as [WebSocket, WebSocket];
      this.ctx.acceptWebSocket(server);
      server.serializeAttachment({ authed: false } satisfies Attachment);
      return new Response(null, { status: 101, webSocket: client });
    }
    if (url.pathname === "/state") {
      const m = await this.load();
      return Response.json(m ? { version: m.state.version, seq: m.seq, phase: m.state.turn.phase } : null);
    }
    return new Response("not found", { status: 404 });
  }

  /** Creates the match once (idempotent: a second call returns the same match). */
  private async init(body: unknown): Promise<Response> {
    const existing = await this.load();
    if (existing) return Response.json({ created: false, id: existing.id });
    const b = body as { id?: string; mode?: MatchMode; seats?: SeatInfo[]; first_seat?: number; ruleset?: Record<string, unknown>; room?: string };
    const seats = b.seats ?? [];
    let state: GameState;
    try {
      state = createGame({
        seats: seats.map((s) => ({ color: s.color, kind: s.is_bot ? "bot" : "human" })),
        firstSeat: b.first_seat ?? Math.floor(Math.random() * Math.max(1, seats.length)),
        ruleset: b.ruleset ?? {},
      });
    } catch (e) {
      return Response.json({ error: "BAD_SEATS", detail: (e as Error).message }, { status: 400 });
    }
    const mode: MatchMode = b.mode === "quick" || b.mode === "private" ? b.mode : "test";
    this.record = {
      id: b.id ?? this.ctx.id.toString(), state, seats, seq: 0, deadline: 0, seen: {}, created_at: Date.now(),
      mode, db_id: crypto.randomUUID(), log: [],
      ...(mode === "private" && typeof b.room === "string" ? { room: b.room } : {}),
    };
    await this.scheduleTurn(this.record);
    await this.save();
    if (mode !== "test") await this.tellHub(this.record, this.record.id);   // players are now "in a match"
    return Response.json({ created: true, id: this.record.id });
  }

  // ------------------------------------------------------------- sockets
  override async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (!this.allow(ws)) {
      this.send(ws, { t: "error", ...requestId(raw), p: { code: "RATE_LIMITED", retryAfterMs: 200 } });
      return;
    }
    let msg: ClientMessage;
    try {
      msg = parseClientMessage(raw);
    } catch (e) {
      const code = e instanceof ProtocolError ? e.code : "INVALID_MESSAGE";
      this.send(ws, { t: "error", ...requestId(raw), p: { code } });
      return;
    }
    try {
      await this.handle(ws, msg);
    } catch {
      // never leak internals to the client
      this.send(ws, { t: "error", re: msg.id, p: { code: "TRY_AGAIN" } });
    }
  }

  override async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    this.buckets.delete(ws);
    try { ws.close(code === 1005 ? 1000 : code, "bye"); } catch { /* already closed */ }
  }

  private async handle(ws: WebSocket, msg: ClientMessage): Promise<void> {
    const att = (ws.deserializeAttachment() ?? { authed: false }) as Attachment;
    if (msg.t === "ping") {
      const b = this.buckets.get(ws);
      if (b && ++b.pings > MAX_PINGS) return;   // clock sync only at connection start
      this.send(ws, { t: "pong", re: msg.id, p: { clientTime: msg.p.clientTime, serverTime: Date.now() } });
      return;
    }
    if (msg.t === "hello") return this.hello(ws, msg);
    if (msg.t === "queue.join" || msg.t === "queue.leave") {
      this.send(ws, { t: "error", re: msg.id, p: { code: "INVALID_MESSAGE" } });
      return;
    }
    if (!att.authed || att.seat === undefined) {
      this.send(ws, { t: "error", re: msg.id, p: { code: "AUTH_REQUIRED" } });
      return;
    }
    const m = await this.load();
    if (!m) {
      this.send(ws, { t: "error", re: msg.id, p: { code: "MATCH_NOT_FOUND" } });
      return;
    }
    if (msg.t === "resync") {
      this.send(ws, this.snapshot(m, att.seat));
      return;
    }
    const seat = att.seat;
    // Idempotency: a request id already processed for this seat returns the first result.
    const seen = (m.seen[String(seat)] ??= {});
    const previous = seen[msg.id];
    if (previous) {
      this.send(ws, { t: previous.ok ? "ok" : "error", re: msg.id, p: { duplicate: true, seq: previous.seq, ...(previous.error ? { code: previous.error } : {}) } });
      return;
    }
    if (msg.t === "action.emote") {
      const allowed = m.seats[seat]?.emotes ?? ["hello", "gg", "go", "wow"];
      if (!allowed.includes(msg.p.emoteId)) {
        seen[msg.id] = { ok: false, error: "EMOTE_NOT_ALLOWED", seq: m.seq };
        const ids = Object.keys(seen);
        if (ids.length > SEEN_PER_SEAT) delete seen[ids[0]!];
        await this.save();
        this.send(ws, { t: "error", re: msg.id, p: { code: "EMOTE_NOT_ALLOWED" } });
        return;
      }
      const now = Date.now();
      const times = ((m.emote_times ??= {})[seat] ??= []).filter((t) => now - t < 10_000);
      if (times.length >= 3) {
        seen[msg.id] = { ok: false, error: "RATE_LIMITED", seq: m.seq };
        const ids = Object.keys(seen);
        if (ids.length > SEEN_PER_SEAT) delete seen[ids[0]!];
        await this.save();
        this.send(ws, { t: "error", re: msg.id, p: { code: "RATE_LIMITED", retryAfterMs: 10_000 - (now - times[0]!) } });
        return;
      }
      times.push(now);
      (m.emote_times ??= {})[seat] = times;
      seen[msg.id] = { ok: true, seq: m.seq };
      const ids = Object.keys(seen);
      if (ids.length > SEEN_PER_SEAT) delete seen[ids[0]!];
      await this.save();
      this.send(ws, { t: "ok", re: msg.id, p: { seq: m.seq } });
      this.broadcastEmote(seat, msg.p.emoteId);
      return;
    }
    let action: Action;
    if (msg.t === "action.roll") action = { type: "roll", seat, turn_id: msg.p.turnId };
    else if (msg.t === "action.move") action = { type: "move", seat, turn_id: msg.p.turnId, pawn: msg.p.pawn };
    else action = { type: "leave", seat };
    const result = this.applyAction(m, action);
    seen[msg.id] = result.ok ? { ok: true, seq: m.seq } : { ok: false, error: result.error, seq: m.seq };
    const ids = Object.keys(seen);
    if (ids.length > SEEN_PER_SEAT) delete seen[ids[0]!];
    if (result.ok) await this.scheduleTurn(m);
    await this.save();   // write first, then tell the players
    if (!result.ok) {
      this.send(ws, { t: "error", re: msg.id, p: { code: result.error } });
      return;
    }
    this.send(ws, { t: "ok", re: msg.id, p: { seq: m.seq } });
    this.broadcast(m, result.events);
    await this.finishRecord(m);
  }

  private async hello(ws: WebSocket, msg: Extract<ClientMessage, { t: "hello" }>): Promise<void> {
    const identity = await verifySupabaseJwt(msg.p.token, this.env.SUPABASE_URL);
    if (!identity) {
      this.send(ws, { t: "error", re: msg.id, p: { code: "AUTH_INVALID" } });
      ws.close(4001, "auth");
      return;
    }
    const m = await this.load();
    const seat = m?.seats.find((s) => !s.is_bot && s.user_id === identity.userId);
    if (!m || !seat) {
      this.send(ws, { t: "error", re: msg.id, p: { code: "NOT_IN_MATCH" } });
      ws.close(4003, "not in match");
      return;
    }
    // One connection per seat: a newer one replaces the older (NETWORK_PROTOCOL §3).
    for (const other of this.ctx.getWebSockets()) {
      const a = other.deserializeAttachment() as Attachment | null;
      if (other !== ws && a?.authed && a.seat === seat.seat) {
        other.serializeAttachment({ authed: false } satisfies Attachment);   // in-flight messages of the old socket no longer act
        this.send(other, { t: "error", p: { code: "SESSION_REPLACED" } });
        other.close(4009, "replaced");
      }
    }
    ws.serializeAttachment({ authed: true, userId: identity.userId, seat: seat.seat } satisfies Attachment);
    this.send(ws, { t: "welcome", re: msg.id, p: { userId: identity.userId, seat: seat.seat, serverTime: Date.now() } });
    this.send(ws, this.snapshot(m, seat.seat));
  }

  // ----------------------------------------------------------- the game
  private applyAction(m: MatchRecord, action: Action): { ok: true; events: GameEvent[] } | { ok: false; error: string } {
    const s = m.state;
    const needsDice = action.type === "roll" || (action.type === "timeout" && s.turn.phase === "roll");
    // Dice are drawn by the server only, within the rule's bound (1..5 after two sixes).
    const dice = needsDice && s.turn.phase !== "game_over" && action.seat === s.turn.seat && "turn_id" in action && action.turn_id === s.turn.turn_id
      ? cryptoDice.next(maxDiceValue(s)) : undefined;
    const r = this.engine.apply(s, action, dice);
    if (!r.ok) return { ok: false, error: r.error };
    m.state = r.state;
    m.seq++;
    // per-seat counters from the engine's own events; auto rolls (timeouts, autopilot) are not counted
    const counts = (m.counts ??= {});
    const c = (seat: number): SeatCounts => (counts[seat] ??= { rolls: 0, sixes: 0, captures: 0, finished: 0 });
    for (const e of r.events) {
      if (e.type === "dice_rolled" && !e.auto) { c(e.seat).rolls++; if (e.value === 6) c(e.seat).sixes++; }
      else if (e.type === "pawn_captured") c(e.by_seat).captures++;
      else if (e.type === "pawn_finished") c(e.seat).finished++;
    }
    (m.log ??= []).push(action.type === "roll" ? `r${dice}` : action.type === "move" ? `m${action.pawn}`
      : action.type === "timeout" ? (dice ? `t${dice}` : "t") : `l${action.seat}`);
    return { ok: true, events: r.events };
  }

  /** One alarm per match: the turn deadline, or a short delay for bots / autopilot. */
  private async scheduleTurn(m: MatchRecord): Promise<void> {
    const s = m.state;
    if (s.turn.phase === "game_over") {
      m.deadline = 0;
      await this.ctx.storage.deleteAlarm();
      return;
    }
    const p = s.players[s.turn.seat]!;
    const seconds = s.turn.phase === "roll" ? s.ruleset.turn_roll_seconds : s.ruleset.turn_move_seconds;
    m.deadline = Date.now() + seconds * 1000;
    const automatic = p.kind === "bot" || p.autopilot;
    const at = automatic ? Date.now() + Math.max(0, Number(this.env.BOT_DELAY_MS) || 0) : m.deadline;
    await this.ctx.storage.setAlarm(at);
  }

  override async alarm(): Promise<void> {
    const m = await this.load();
    if (m?.state.turn.phase === "game_over" && m.db?.status === "pending") {
      await this.flushRecord(m);   // retry of the result record
      return;
    }
    if (!m || m.state.turn.phase === "game_over") return;
    const s = m.state;
    const p = s.players[s.turn.seat]!;
    const automatic = p.kind === "bot" || p.autopilot;
    if (!automatic && Date.now() < m.deadline - 50) {
      await this.ctx.storage.setAlarm(m.deadline);   // woke early: wait for the deadline
      return;
    }
    // Bots, autopilot and timed-out humans: the engine's timeout plays the turn.
    const r = this.applyAction(m, { type: "timeout", seat: s.turn.seat, turn_id: s.turn.turn_id });
    if (r.ok) await this.scheduleTurn(m);
    await this.save();
    if (r.ok) {
      this.broadcast(m, r.events);
      await this.finishRecord(m);
    }
  }

  /** Presence / directory: matchId = the human players are in this match, null = it is over. */
  private async tellHub(m: MatchRecord, matchId: string | null): Promise<void> {
    const users = m.seats.filter((x) => !x.is_bot && x.user_id).map((x) => x.user_id!);
    try {
      await this.env.SOCIAL_HUB.get(this.env.SOCIAL_HUB.idFromName("hub")).fetch("https://hub/status", {
        method: "POST", body: JSON.stringify({ users, matchId }),
      });
    } catch { /* presence only; the match is not affected */ }
  }

  // ------------------------------------------------------ match record
  /** At game over: mark the result as pending in storage, then record it. */
  private async finishRecord(m: MatchRecord): Promise<void> {
    if (m.state.turn.phase !== "game_over" || m.db) return;
    m.ended_at = Date.now();
    m.db = { status: dbConfigured(this.env) ? "pending" : "skipped", attempts: 0 };
    await this.save();
    if (m.mode !== "test") await this.tellHub(m, null);
    if (m.room) {
      try {
        await this.env.PRIVATE_ROOM.get(this.env.PRIVATE_ROOM.idFromName(`room:${m.room}`)).fetch("https://room/match-ended", {
          method: "POST", body: JSON.stringify({ matchId: m.id }),
        });
      } catch { /* the room times out on its own */ }
    }
    if (m.db.status === "pending") await this.flushRecord(m);
  }

  private async flushRecord(m: MatchRecord): Promise<void> {
    if (!m.db || m.db.status !== "pending") return;
    const s = m.state;
    try {
      const result = await recordMatch(this.env, {
        matchId: m.db_id,
        mode: m.mode ?? "test",
        ruleset: s.ruleset,
        seats: m.seats.map((seat) => ({
          seat: seat.seat, color: seat.color, user_id: seat.is_bot ? null : seat.user_id, is_bot: seat.is_bot,
          rank: s.ranks.indexOf(seat.seat) + 1, left: s.players[seat.seat]?.status === "left", name: seat.name,
          ...(m.counts?.[seat.seat] ?? {}),
        })),
        startedAt: m.created_at,
        endedAt: m.ended_at ?? Date.now(),
        endReason: s.left_order.length > 0 ? "left" : "finished",
        actions: (m.log ?? []).join(" "),
        finalStateHash: stateHash(s),
        actionCount: m.seq,
        serverVersion: this.env.CF_VERSION_METADATA?.id ?? "local",
      });
      // applied now, or already stored by an earlier attempt: either way it is in the database once
      m.db = { status: "done", attempts: m.db.attempts + 1, progress: result.applied ? result.progress : (m.db.progress ?? {}) };
      await this.save();
      for (const ws of this.ctx.getWebSockets()) {
        const a = ws.deserializeAttachment() as Attachment | null;
        if (a?.authed) this.send(ws, { t: "match.recorded", p: { matchId: m.db_id, progress: (a.userId && m.db.progress?.[a.userId]) || null } });
      }
    } catch (e) {
      const attempts = m.db.attempts + 1;
      const error = String((e as Error).message ?? e).replace(/postgres(ql)?:\/\/\S+/g, "<db>").slice(0, 200);
      m.db = { status: attempts >= 40 ? "skipped" : "pending", attempts, error };
      console.error(`match record failed (attempt ${attempts}): ${error}`);
      await this.save();
      if (m.db.status === "pending") {
        // 2 s, 4 s, ... capped at 30 min; ~40 attempts cover about a day
        await this.ctx.storage.setAlarm(Date.now() + Math.min(1800000, 2000 * 2 ** Math.min(attempts, 10)));
      }
    }
  }

  // ------------------------------------------------------------- helpers
  private snapshot(m: MatchRecord, seat: number) {
    return { t: "match.snapshot", seq: m.seq, p: { matchId: m.id, yourSeat: seat, seats: m.seats, state: m.state, deadline: m.deadline, serverTime: Date.now(), boot: this.boot, record: m.db?.status ?? null, recordId: m.db?.status === "done" ? m.db_id : null,
      progress: (seat >= 0 && m.db?.progress?.[m.seats[seat]?.user_id ?? ""]) || null } };
  }

  private broadcast(m: MatchRecord, events: GameEvent[]): void {
    const msg = { t: "match.events", seq: m.seq, p: { events, version: m.state.version, turn: m.state.turn, legal: m.state.legal, state: m.state, deadline: m.deadline } };
    for (const ws of this.ctx.getWebSockets()) {
      const a = ws.deserializeAttachment() as Attachment | null;
      if (a?.authed) this.send(ws, msg);
    }
  }

  private broadcastEmote(seat: number, emoteId: string): void {
    for (const ws of this.ctx.getWebSockets()) {
      const a = ws.deserializeAttachment() as Attachment | null;
      if (a?.authed) this.send(ws, { t: "emote", p: { seat, emoteId } });
    }
  }

  private send(ws: WebSocket, msg: Record<string, unknown>): void {
    try { ws.send(JSON.stringify({ v: 1, st: Date.now(), ...msg })); } catch { /* closed */ }
  }

  /** Token bucket per connection (in memory; a reconnect does not reset abuse for long). */
  private allow(ws: WebSocket): boolean {
    const now = Date.now();
    let b = this.buckets.get(ws);
    if (!b) this.buckets.set(ws, (b = { tokens: RATE_BURST, at: now, pings: 0 }));
    b.tokens = Math.min(RATE_BURST, b.tokens + ((now - b.at) / 1000) * RATE_PER_SEC);
    b.at = now;
    if (b.tokens < 1) return false;
    b.tokens -= 1;
    return true;
  }

  private async load(): Promise<MatchRecord | null> {
    if (!this.record) this.record = (await this.ctx.storage.get<MatchRecord>("match")) ?? null;
    return this.record;
  }

  private async save(): Promise<void> {
    if (this.record) await this.ctx.storage.put("match", this.record);
  }
}
