// PrivateRoom — one Durable Object per room code (idFromName("room:" + code)), Phase 5.
// The lobby only: members, colours, ready flags, host. When the host starts, the
// room creates a normal MatchRoom (mode "private") and tells every member its id:
// the match itself runs on the SAME server-authoritative MatchRoom, engine, protocol
// and client match screen as the quick match, and is recorded in Supabase the same way.
// When that match ends, the MatchRoom calls back (/match-ended) and the room is a
// lobby again (play again with the same people).
//
// Rules (K-08, K-57 — see docs/DECISIONS_AND_OPEN_QUESTIONS.md):
//  - 2 players: opposite colours only (red–yellow, green–blue). A player who picks a
//    colour moves the other player to the opposite one; both have to confirm "ready" again.
//  - 4 players: each player picks a free colour; a taken colour is refused (COLOR_TAKEN).
//  - Start: host only, room full, every other member ready.
//  - Host leaves -> the member who joined first after the host becomes host (K-71).
//  - Members disconnected for DISCONNECT_GRACE_MS in the lobby are removed; an empty
//    room or a lobby idle for LOBBY_IDLE_MS closes.
// Identity comes only from the verified JWT; every code attempt is rate-limited by the SocialHub.

import { DurableObject } from "cloudflare:workers";
import { verifySupabaseJwt } from "./auth.js";
import { dbConfigured, playerCards } from "./db.js";
import type { Env, SeatInfo } from "./match_room.js";
import { ClientMessage, parseClientMessage, ProtocolError, requestIdOf } from "./protocol.js";

const COLORS = ["red", "green", "yellow", "blue"] as const;
type Color = (typeof COLORS)[number];
const OPPOSITE: Record<Color, Color> = { red: "yellow", yellow: "red", green: "blue", blue: "green" };
const DISCONNECT_GRACE_MS = 120_000;
const LOBBY_IDLE_MS = 30 * 60_000;

interface Member {
  userId: string; name: string; tag: number; avatar: string;
  color: Color; ready: boolean; joinedAt: number; connected: boolean; lastSeen: number;
}
interface Room {
  code: string; players: 2 | 4; host: string; phase: "lobby" | "playing" | "closed";
  members: Member[]; matchId?: string; seats?: SeatInfo[]; createdAt: number; activityAt: number; games: number;
}
interface RoomAttachment { authed: boolean; userId?: string }

export class PrivateRoom extends DurableObject<Env> {
  private room: Room | null = null;
  private buckets = new Map<WebSocket, { tokens: number; at: number }>();

  private hub() { return this.env.SOCIAL_HUB.get(this.env.SOCIAL_HUB.idFromName("hub")); }
  private async hubPost(path: string, body: unknown): Promise<Record<string, unknown>> {
    const r = await this.hub().fetch(`https://hub${path}`, { method: "POST", body: JSON.stringify(body) });
    return (await r.json()) as Record<string, unknown>;
  }

  private async load(): Promise<Room | null> {
    if (!this.room) this.room = (await this.ctx.storage.get<Room>("room")) ?? null;
    return this.room;
  }
  private async save(): Promise<void> { if (this.room) await this.ctx.storage.put("room", this.room); }

  // ---------------------------------------------------------------- HTTP (internal)
  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (request.headers.get("Upgrade") === "websocket") {
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair) as [WebSocket, WebSocket];
      this.ctx.acceptWebSocket(server);
      server.serializeAttachment({ authed: false } satisfies RoomAttachment);
      return new Response(null, { status: 101, webSocket: client });
    }
    if (url.pathname === "/init" && request.method === "POST") {
      const b = (await request.json()) as { code: string; players: 2 | 4; host: string };
      const existing = await this.load();
      if (existing && existing.phase !== "closed") return Response.json({ created: false });
      const card = await this.card(b.host);
      const now = Date.now();
      this.room = {
        code: b.code, players: b.players, host: b.host, phase: "lobby", createdAt: now, activityAt: now, games: 0,
        members: [{ userId: b.host, ...card, color: "red", ready: false, joinedAt: now, connected: false, lastSeen: now }],
      };
      await this.save();
      await this.schedule();
      return Response.json({ created: true });
    }
    if (url.pathname === "/info") {
      const r = await this.load();
      if (!r || r.phase === "closed") return Response.json({ exists: false });
      return Response.json({ exists: true, phase: r.phase, count: r.members.length, players: r.players, members: r.members.map((m) => m.userId) });
    }
    if (url.pathname === "/match-ended" && request.method === "POST") {
      const b = (await request.json()) as { matchId: string };
      const r = await this.load();
      if (r && r.phase === "playing" && r.matchId === b.matchId) {
        r.phase = "lobby";
        delete r.matchId; delete r.seats;
        r.games++;
        r.activityAt = Date.now();
        for (const m of r.members) { m.ready = false; m.lastSeen = Date.now(); }
        await this.save();
        await this.schedule();
        this.broadcast();
      }
      return Response.json({ ok: true });
    }
    return new Response("not found", { status: 404 });
  }

  private async card(userId: string): Promise<{ name: string; tag: number; avatar: string }> {
    if (dbConfigured(this.env)) {
      try { const c = (await playerCards(this.env, [userId])).get(userId); if (c) return c; } catch { /* default */ }
    }
    return { name: "Oyuncu", tag: 0, avatar: "default" };
  }

  // --------------------------------------------------------------------- sockets
  override async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (!this.allow(ws)) { this.send(ws, { t: "error", p: { code: "RATE_LIMITED" } }); return; }
    let msg: ClientMessage;
    try { msg = parseClientMessage(raw); } catch (e) {
      this.send(ws, { t: "error", ...requestIdOf(raw), p: { code: e instanceof ProtocolError ? e.code : "INVALID_MESSAGE" } });
      return;
    }
    if (msg.t === "ping") { this.send(ws, { t: "pong", re: msg.id, p: { serverTime: Date.now() } }); return; }
    const att = (ws.deserializeAttachment() ?? { authed: false }) as RoomAttachment;
    if (msg.t === "hello") return this.hello(ws, msg.id, msg.p.token);
    if (!att.authed || !att.userId) { this.send(ws, { t: "error", re: msg.id, p: { code: "AUTH_REQUIRED" } }); return; }
    const r = await this.load();
    const me = r?.members.find((m) => m.userId === att.userId);
    if (!r || r.phase === "closed" || !me) { this.send(ws, { t: "error", re: msg.id, p: { code: "NOT_IN_ROOM" } }); return; }
    const fail = (code: string) => this.send(ws, { t: "error", re: msg.id, p: { code } });
    r.activityAt = Date.now();
    switch (msg.t) {
      case "room.color": {
        if (r.phase !== "lobby") return fail("ROOM_IN_GAME");
        const color = msg.p.color as Color;
        if (r.players === 2) {
          me.color = color;
          for (const m of r.members) { if (m !== me) m.color = OPPOSITE[color]; m.ready = false; }
        } else {
          if (r.members.some((m) => m !== me && m.color === color)) return fail("COLOR_TAKEN");
          me.color = color;
          me.ready = false;
        }
        break;
      }
      case "room.ready":
        if (r.phase !== "lobby") return fail("ROOM_IN_GAME");
        me.ready = msg.p.ready;
        break;
      case "room.start": {
        if (r.phase !== "lobby") return fail("ROOM_IN_GAME");
        if (r.host !== me.userId) return fail("NOT_HOST");
        if (r.members.length !== r.players) return fail("ROOM_NOT_FULL");
        if (r.members.some((m) => m.userId !== r.host && !m.ready)) return fail("NOT_READY");
        if (new Set(r.members.map((m) => m.color)).size !== r.members.length) return fail("COLOR_TAKEN");
        if (r.players === 2 && OPPOSITE[r.members[0]!.color] !== r.members[1]!.color) return fail("COLOR_INVALID");
        await this.startMatch(r);
        this.send(ws, { t: "ok", re: msg.id, p: {} });
        return;
      }
      case "room.leave":
        // answer first: removing the last member closes the room and all its sockets
        this.send(ws, { t: "room.left", re: msg.id, p: {} });
        ws.serializeAttachment({ authed: false } satisfies RoomAttachment);
        await this.removeMember(r, me.userId, "left");
        try { ws.close(1000, "left"); } catch { /* closed */ }
        return;
      default:
        return fail("INVALID_MESSAGE");
    }
    await this.save();
    this.send(ws, { t: "ok", re: msg.id, p: {} });
    this.broadcast();
  }

  private async hello(ws: WebSocket, re: string, token: string): Promise<void> {
    const id = await verifySupabaseJwt(token, this.env.SUPABASE_URL);
    if (!id) { this.send(ws, { t: "error", re, p: { code: "AUTH_INVALID" } }); ws.close(4001, "auth"); return; }
    const r = await this.load();
    const member = r?.members.find((m) => m.userId === id.userId);
    if (!member) {
      // every attempt to enter by code is counted per player (unknown codes) and limited
      const at = await this.hubPost("/room/attempt", { userId: id.userId, exists: !!r && r.phase !== "closed" });
      if (!at.ok) { this.send(ws, { t: "error", re, p: { code: at.error } }); ws.close(4004, "room"); return; }
      if (r!.phase !== "lobby") { this.send(ws, { t: "error", re, p: { code: "ROOM_IN_GAME" } }); ws.close(4004, "room"); return; }
      if (r!.members.length >= r!.players) { this.send(ws, { t: "error", re, p: { code: "ROOM_FULL" } }); ws.close(4004, "room"); return; }
      const j = await this.hubPost("/room/join", { userId: id.userId, code: r!.code });
      if (!j.ok) { this.send(ws, { t: "error", re, p: { code: j.error, room: j.code ?? null } }); ws.close(4004, "room"); return; }
      const card = await this.card(id.userId);       // last await before the final check
      // From here to the push there is no await: the capacity check and the insert are atomic.
      const fresh = this.room ?? (await this.load())!;   // in-memory state (loaded above)
      if (fresh.members.length >= fresh.players || fresh.phase !== "lobby") {
        await this.hubPost("/room/left", { userId: id.userId, code: fresh.code });
        this.send(ws, { t: "error", re, p: { code: "ROOM_FULL" } }); ws.close(4004, "room"); return;
      }
      if (!fresh.members.some((m) => m.userId === id.userId)) {
        const taken = new Set(fresh.members.map((m) => m.color));
        const color: Color = fresh.players === 2 ? OPPOSITE[fresh.members[0]!.color] : COLORS.find((c) => !taken.has(c))!;
        const now = Date.now();
        fresh.members.push({ userId: id.userId, ...card, color, ready: false, joinedAt: now, connected: true, lastSeen: now });
        fresh.activityAt = now;
      }
    } else {
      // the host's first connection also registers the room in the directory (idempotent)
      if (member.userId === r!.host) await this.hubPost("/room/join", { userId: member.userId, code: r!.code });
    }
    // one live connection per member: an older socket of the same player is closed
    for (const other of this.ctx.getWebSockets()) {
      const o = other.deserializeAttachment() as RoomAttachment | null;
      if (other !== ws && o?.userId === id.userId) {
        other.serializeAttachment({ authed: false } satisfies RoomAttachment);
        this.send(other, { t: "error", p: { code: "SESSION_REPLACED" } });
        try { other.close(4009, "replaced"); } catch { /* closed */ }
      }
    }
    ws.serializeAttachment({ authed: true, userId: id.userId } satisfies RoomAttachment);
    const room = (await this.load())!;
    const m = room.members.find((x) => x.userId === id.userId)!;
    m.connected = true;
    m.lastSeen = Date.now();
    await this.save();
    await this.schedule();
    this.send(ws, { t: "welcome", re, p: { userId: id.userId, serverTime: Date.now() } });
    this.broadcast();
    if (room.phase === "playing") this.sendStarted(ws, room);
  }

  override async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    try { ws.close(code === 1005 ? 1000 : code, "bye"); } catch { /* closed */ }
    this.buckets.delete(ws);
    const att = ws.deserializeAttachment() as RoomAttachment | null;
    const r = await this.load();
    if (!att?.userId || !r) return;
    const still = this.ctx.getWebSockets().some((w) => w !== ws && (w.deserializeAttachment() as RoomAttachment | null)?.userId === att.userId);
    const m = r.members.find((x) => x.userId === att.userId);
    if (m && !still) {
      m.connected = false;
      m.lastSeen = Date.now();
      await this.save();
      await this.schedule();
      this.broadcast();
    }
  }

  // ---------------------------------------------------------------------- lobby
  private async startMatch(r: Room): Promise<void> {
    const ordered = [...r.members].sort((a, b) => COLORS.indexOf(a.color) - COLORS.indexOf(b.color));
    const seats: SeatInfo[] = ordered.map((m, seat) => ({ seat, color: m.color, user_id: m.userId, is_bot: false, name: m.name }));
    const id = this.env.MATCH_ROOM.newUniqueId();
    const res = await this.env.MATCH_ROOM.get(id).fetch("https://match/init", {
      method: "POST", body: JSON.stringify({ id: id.toString(), mode: "private", seats, room: r.code }),
    });
    if (!res.ok) throw new Error("match init failed");
    r.phase = "playing";
    r.matchId = id.toString();
    r.seats = seats;
    r.activityAt = Date.now();
    await this.save();
    await this.schedule();
    this.broadcast();
    for (const w of this.ctx.getWebSockets()) this.sendStarted(w, r);
  }

  private sendStarted(ws: WebSocket, r: Room): void {
    const a = ws.deserializeAttachment() as RoomAttachment | null;
    const seat = r.seats?.find((s) => s.user_id === a?.userId);
    if (!a?.authed || !seat || !r.matchId) return;
    this.send(ws, { t: "room.started", p: { matchId: r.matchId, seat: seat.seat, color: seat.color, seats: r.seats } });
  }

  private async removeMember(r: Room, userId: string, reason: string): Promise<void> {
    r.members = r.members.filter((m) => m.userId !== userId);
    await this.hubPost("/room/left", { userId, code: r.code });
    if (r.members.length === 0) return this.close(r, reason === "left" ? "empty" : reason);
    if (r.host === userId) r.host = [...r.members].sort((a, b) => a.joinedAt - b.joinedAt)[0]!.userId;   // K-71
    if (r.players === 2 && r.members.length === 1 && r.phase === "lobby") r.members[0]!.ready = false;
    await this.save();
    this.broadcast();
  }

  private async close(r: Room, reason: string): Promise<void> {
    r.phase = "closed";
    await this.save();
    for (const m of r.members) await this.hubPost("/room/left", { userId: m.userId, code: r.code });
    await this.hubPost("/room/closed", { code: r.code });
    for (const w of this.ctx.getWebSockets()) {
      this.send(w, { t: "room.closed", p: { reason } });
      try { w.close(1000, "closed"); } catch { /* closed */ }
    }
    await this.ctx.storage.deleteAlarm();
  }

  private async schedule(): Promise<void> {
    const r = this.room;
    if (!r || r.phase === "closed") return;
    const times = [r.phase === "lobby" ? r.activityAt + LOBBY_IDLE_MS : Date.now() + 6 * 3600_000];
    if (r.phase === "lobby") for (const m of r.members) if (!m.connected) times.push(m.lastSeen + DISCONNECT_GRACE_MS);
    await this.ctx.storage.setAlarm(Math.min(...times) + 100);
  }

  /** Removes members gone for too long, closes idle lobbies. */
  override async alarm(): Promise<void> {
    const r = await this.load();
    if (!r || r.phase === "closed") return;
    const now = Date.now();
    if (r.phase === "lobby") {
      if (r.activityAt + LOBBY_IDLE_MS <= now) return this.close(r, "timeout");
      for (const m of [...r.members]) {
        if (!m.connected && m.lastSeen + DISCONNECT_GRACE_MS <= now) {
          await this.removeMember(r, m.userId, "timeout");
          if ((r.phase as Room["phase"]) === "closed") return;   // removeMember may close it
        }
      }
    }
    await this.schedule();
  }

  private view(r: Room): Record<string, unknown> {
    return {
      code: r.code, players: r.players, host: r.host, phase: r.phase, games: r.games,
      members: r.members.map((m) => ({ userId: m.userId, name: m.name, tag: m.tag, avatar: m.avatar, color: m.color,
        ready: m.ready, connected: m.connected, host: m.userId === r.host })),
    };
  }

  private broadcast(): void {
    const r = this.room;
    if (!r) return;
    const state = this.view(r);
    for (const w of this.ctx.getWebSockets()) {
      if ((w.deserializeAttachment() as RoomAttachment | null)?.authed) this.send(w, { t: "room.state", p: state });
    }
  }

  private allow(ws: WebSocket): boolean {
    const now = Date.now();
    const b = this.buckets.get(ws) ?? { tokens: 20, at: now };
    b.tokens = Math.min(20, b.tokens + ((now - b.at) / 1000) * 5);
    b.at = now;
    this.buckets.set(ws, b);
    if (b.tokens < 1) return false;
    b.tokens -= 1;
    return true;
  }

  private send(ws: WebSocket, msg: Record<string, unknown>): void {
    try { ws.send(JSON.stringify({ v: 1, st: Date.now(), ...msg })); } catch { /* closed */ }
  }
}
