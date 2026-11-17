// SocialHub — one Durable Object (idFromName("hub")) for the social layer (Phase 5):
//  - presence: a player is online while the app holds a hub WebSocket; status
//    "online" | "room" | "match". Only FRIENDS learn it (friend ids from the
//    database, role game_server). Push, no polling; hibernation keeps idle sockets cheap.
//  - live hints ("poke"): content-free "something changed, reload" messages for
//    friend requests / friendships (the data itself is read from Supabase with RLS).
//  - match invites to private rooms: friends only, never across a block, expire after
//    INVITE_TTL_MS, accepted at most once.
//  - room directory: allocates unguessable room codes, knows which room / match each
//    player is in ("already in a match"), and rate-limits room code attempts per player.
// Durable state (directory, invites, attempt counters) is in this object's storage;
// presence lives in the WebSocket attachments (survives hibernation).
// One hub is enough for development and early tests; sharding by user id is the
// scaling path (docs/architecture/CLOUDFLARE_ARCHITECTURE.md §3.5).

import { DurableObject } from "cloudflare:workers";
import { verifySupabaseJwt } from "./auth.js";
import { dbConfigured, friendIds, playerCards, socialCheck } from "./db.js";
import type { Env } from "./match_room.js";
import { ClientMessage, parseClientMessage, ProtocolError, requestIdOf, ROOM_ALPHABET } from "./protocol.js";

export const INVITE_TTL_MS = 120_000;
const ATTEMPT_WINDOW_MS = 10 * 60_000;
const MAX_FAILED_ATTEMPTS = 8;          // wrong room codes per player per 10 minutes
const MATCH_STATUS_TTL_MS = 3 * 3600_000;
const MAX_OUTGOING_INVITES = 10;

type Status = "online" | "room" | "match";
interface HubAttachment { authed: boolean; userId?: string; friends?: string[] }
interface UserState { room?: string; match?: string; matchUntil?: number }
interface Invite {
  id: string; from: string; fromName: string; fromTag: number; fromAvatar: string;
  to: string; code: string; players: number; created: number; expires: number;
  status: "pending" | "accepted" | "declined" | "expired" | "cancelled";
}
interface Attempts { failed: number; since: number }

function randomCode(): string {
  const buf = new Uint8Array(6);
  let out = "";
  while (out.length < 6) {
    crypto.getRandomValues(buf);
    for (const b of buf) {
      if (b < 248 && out.length < 6) out += ROOM_ALPHABET[b % ROOM_ALPHABET.length];   // 248 = 8 * 31: no modulo bias
    }
  }
  return out;
}

export class SocialHub extends DurableObject<Env> {
  private buckets = new Map<WebSocket, { tokens: number; at: number }>();

  // ---------------------------------------------------------------- HTTP (internal)
  override async fetch(request: Request): Promise<Response> {
    if (request.headers.get("Upgrade") === "websocket") {
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair) as [WebSocket, WebSocket];
      this.ctx.acceptWebSocket(server);
      server.serializeAttachment({ authed: false } satisfies HubAttachment);
      return new Response(null, { status: 101, webSocket: client });
    }
    const url = new URL(request.url);
    const body = request.method === "POST" ? (await request.json()) as Record<string, unknown> : {};
    switch (url.pathname) {
      case "/room/create": return this.createRoom(String(body.userId), Number(body.players));
      case "/room/attempt": return Response.json(await this.attempt(String(body.userId), !!body.exists));
      case "/room/join": return Response.json(await this.joinRoom(String(body.userId), String(body.code)));
      case "/room/left": await this.leftRoom(String(body.userId), String(body.code)); return Response.json({ ok: true });
      case "/room/closed": await this.roomClosed(String(body.code)); return Response.json({ ok: true });
      case "/status": await this.setMatch(body.users as string[], body.matchId ? String(body.matchId) : null); return Response.json({ ok: true });
      case "/mine": return Response.json(await this.userState(String(url.searchParams.get("user"))));
    }
    return new Response("not found", { status: 404 });
  }

  // ------------------------------------------------------------------- directory
  private async userState(userId: string): Promise<UserState> {
    const u = (await this.ctx.storage.get<UserState>(`user:${userId}`)) ?? {};
    if (u.match && (u.matchUntil ?? 0) < Date.now()) { delete u.match; delete u.matchUntil; }
    return u;
  }

  private async putUser(userId: string, u: UserState): Promise<void> {
    if (!u.room && !u.match) await this.ctx.storage.delete(`user:${userId}`);
    else await this.ctx.storage.put(`user:${userId}`, u);
    await this.broadcastStatus(userId);
  }

  private async createRoom(userId: string, players: number): Promise<Response> {
    if (players !== 2 && players !== 4) return Response.json({ error: "BAD_PLAYERS" }, { status: 400 });
    const u = await this.userState(userId);
    if (u.room) return Response.json({ error: "ALREADY_IN_ROOM", code: u.room }, { status: 409 });
    if (u.match) return Response.json({ error: "IN_MATCH" }, { status: 409 });
    let code = "";
    for (let i = 0; i < 20 && !code; i++) {
      const c = randomCode();
      if (!(await this.ctx.storage.get(`code:${c}`))) code = c;
    }
    if (!code) return Response.json({ error: "TRY_AGAIN" }, { status: 503 });
    const res = await this.env.PRIVATE_ROOM.get(this.env.PRIVATE_ROOM.idFromName(`room:${code}`)).fetch("https://room/init", {
      method: "POST", body: JSON.stringify({ code, players, host: userId }),
    });
    if (!res.ok) return Response.json({ error: "TRY_AGAIN" }, { status: 503 });
    await this.ctx.storage.put(`code:${code}`, { players, created: Date.now() });
    await this.putUser(userId, { ...u, room: code });
    return Response.json({ code, players });
  }

  /** Every attempt to enter a room by code goes through here (rate limit per player). */
  private async attempt(userId: string, exists: boolean): Promise<{ ok: boolean; error?: string }> {
    const key = `fail:${userId}`;
    let a = (await this.ctx.storage.get<Attempts>(key)) ?? { failed: 0, since: Date.now() };
    if (Date.now() - a.since > ATTEMPT_WINDOW_MS) a = { failed: 0, since: Date.now() };
    if (a.failed >= MAX_FAILED_ATTEMPTS) return { ok: false, error: "RATE_LIMITED" };
    if (!exists) {
      a.failed++;
      await this.ctx.storage.put(key, a);
      return { ok: false, error: "ROOM_NOT_FOUND" };
    }
    return { ok: true };
  }

  private async joinRoom(userId: string, code: string): Promise<{ ok: boolean; error?: string; code?: string }> {
    const u = await this.userState(userId);
    if (u.room && u.room !== code) return { ok: false, error: "ALREADY_IN_ROOM", code: u.room };
    if (u.match) return { ok: false, error: "IN_MATCH" };
    if (u.room !== code) await this.putUser(userId, { ...u, room: code });
    return { ok: true };
  }

  private async leftRoom(userId: string, code: string): Promise<void> {
    const u = await this.userState(userId);
    if (u.room === code) { delete u.room; await this.putUser(userId, u); }
  }

  private async roomClosed(code: string): Promise<void> {
    await this.ctx.storage.delete(`code:${code}`);
    const invites = await this.ctx.storage.list<Invite>({ prefix: "inv:" });
    for (const inv of invites.values()) {
      if (inv.code === code && inv.status === "pending") await this.finishInvite(inv, "cancelled");
    }
  }

  /** matchId = the player is in that match; null = the match is over. */
  private async setMatch(users: string[], matchId: string | null): Promise<void> {
    for (const userId of (users ?? []).slice(0, 4)) {
      const u = await this.userState(userId);
      if (matchId) { u.match = matchId; u.matchUntil = Date.now() + MATCH_STATUS_TTL_MS; }
      else if (u.match) { delete u.match; delete u.matchUntil; }
      await this.putUser(userId, u);
    }
  }

  // --------------------------------------------------------------------- sockets
  override async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (!this.allow(ws)) { this.send(ws, { t: "error", p: { code: "RATE_LIMITED" } }); return; }
    let msg: ClientMessage;
    try { msg = parseClientMessage(raw); } catch (e) {
      this.send(ws, { t: "error", ...requestIdOf(raw), p: { code: e instanceof ProtocolError ? e.code : "INVALID_MESSAGE" } });
      return;
    }
    const att = (ws.deserializeAttachment() ?? { authed: false }) as HubAttachment;
    if (msg.t === "ping") { this.send(ws, { t: "pong", re: msg.id, p: { serverTime: Date.now() } }); return; }
    if (msg.t === "hello") {
      const id = await verifySupabaseJwt(msg.p.token, this.env.SUPABASE_URL);
      if (!id) { this.send(ws, { t: "error", re: msg.id, p: { code: "AUTH_INVALID" } }); ws.close(4001, "auth"); return; }
      const wasOnline = this.online(id.userId);
      const friends = await this.loadFriends(id.userId);
      ws.serializeAttachment({ authed: true, userId: id.userId, friends } satisfies HubAttachment);
      this.send(ws, { t: "welcome", re: msg.id, p: { userId: id.userId, serverTime: Date.now(), db: dbConfigured(this.env) } });
      this.send(ws, { t: "presence.list", p: { friends: await this.friendStatuses(friends) } });
      this.send(ws, { t: "invite.list", p: { invites: await this.invitesFor(id.userId) } });
      if (!wasOnline) await this.broadcastStatus(id.userId);
      return;
    }
    if (!att.authed || !att.userId) { this.send(ws, { t: "error", re: msg.id, p: { code: "AUTH_REQUIRED" } }); return; }
    const me = att.userId;
    switch (msg.t) {
      case "presence.sync": {
        const friends = await this.loadFriends(me);
        ws.serializeAttachment({ ...att, friends } satisfies HubAttachment);
        this.send(ws, { t: "presence.list", re: msg.id, p: { friends: await this.friendStatuses(friends) } });
        return;
      }
      case "friends.changed": {
        // my friend list changed (accept / remove / block): reload mine and the other player's lists
        for (const user of [me, msg.p.other]) await this.reloadFriendsOf(user);
        this.notify(msg.p.other, { t: "social.changed", p: { kind: "friends_changed" } });
        this.send(ws, { t: "ok", re: msg.id, p: {} });
        return;
      }
      case "poke":
        // content-free hint; the receiver reloads its data from Supabase (RLS)
        this.notify(msg.p.to, { t: "social.changed", p: { kind: msg.p.kind } });
        this.send(ws, { t: "ok", re: msg.id, p: {} });
        return;
      case "invite.list":
        this.send(ws, { t: "invite.list", re: msg.id, p: { invites: await this.invitesFor(me) } });
        return;
      case "invite.send": return this.sendInvite(ws, msg.id, me, msg.p.to, msg.p.code);
      case "invite.accept": return this.answerInvite(ws, msg.id, me, msg.p.inviteId, true);
      case "invite.decline": return this.answerInvite(ws, msg.id, me, msg.p.inviteId, false);
      default:
        this.send(ws, { t: "error", re: msg.id, p: { code: "INVALID_MESSAGE" } });
    }
  }

  override async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    const att = ws.deserializeAttachment() as HubAttachment | null;
    try { ws.close(code === 1005 ? 1000 : code, "bye"); } catch { /* closed */ }
    this.buckets.delete(ws);
    if (att?.userId && !this.online(att.userId, ws)) await this.broadcastStatus(att.userId);
  }

  // -------------------------------------------------------------------- presence
  private sockets(userId: string, except?: WebSocket): WebSocket[] {
    return this.ctx.getWebSockets().filter((w) => w !== except && w.readyState === WebSocket.READY_STATE_OPEN &&
      (w.deserializeAttachment() as HubAttachment | null)?.userId === userId);
  }

  private online(userId: string, except?: WebSocket): boolean { return this.sockets(userId, except).length > 0; }

  private async statusOf(userId: string): Promise<Status | "offline"> {
    if (!this.online(userId)) return "offline";
    const u = await this.userState(userId);
    return u.match ? "match" : u.room ? "room" : "online";
  }

  private async friendStatuses(friends: string[]): Promise<{ userId: string; status: string }[]> {
    const out = [];
    for (const f of friends) {
      const s = await this.statusOf(f);
      if (s !== "offline") out.push({ userId: f, status: s });
    }
    return out;
  }

  /** Tells the online friends of userId its current status. */
  private async broadcastStatus(userId: string): Promise<void> {
    const status = await this.statusOf(userId);
    for (const w of this.ctx.getWebSockets()) {
      const a = w.deserializeAttachment() as HubAttachment | null;
      if (a?.authed && a.friends?.includes(userId)) this.send(w, { t: "presence", p: { userId, status } });
    }
  }

  private async loadFriends(userId: string): Promise<string[]> {
    if (!dbConfigured(this.env)) return [];
    try { return (await friendIds(this.env, userId)).slice(0, 200); } catch { return []; }
  }

  private async reloadFriendsOf(userId: string): Promise<void> {
    const socks = this.sockets(userId);
    if (!socks.length) return;
    const friends = await this.loadFriends(userId);
    const list = await this.friendStatuses(friends);
    for (const w of socks) {
      w.serializeAttachment({ ...(w.deserializeAttachment() as HubAttachment), friends } satisfies HubAttachment);
      this.send(w, { t: "presence.list", p: { friends: list } });
    }
  }

  // --------------------------------------------------------------------- invites
  private async invitesFor(userId: string): Promise<Invite[]> {
    const now = Date.now();
    const list = await this.ctx.storage.list<Invite>({ prefix: "inv:" });
    return [...list.values()].filter((i) => i.to === userId && i.status === "pending" && i.expires > now);
  }

  private async sendInvite(ws: WebSocket, re: string, me: string, to: string, code: string): Promise<void> {
    const fail = (c: string) => this.send(ws, { t: "error", re, p: { code: c } });
    if (to === me) return fail("SELF");
    const u = await this.userState(me);
    if (u.room !== code) return fail("NOT_IN_ROOM");
    if (!dbConfigured(this.env)) return fail("DB_UNAVAILABLE");
    let rel: { friends: boolean; blocked: boolean };
    try { rel = await socialCheck(this.env, me, to); } catch { return fail("TRY_AGAIN"); }
    if (rel.blocked) return fail("NOT_ALLOWED");
    if (!rel.friends) return fail("NOT_FRIENDS");
    const info = await (await this.env.PRIVATE_ROOM.get(this.env.PRIVATE_ROOM.idFromName(`room:${code}`)).fetch("https://room/info")).json() as
      { exists: boolean; phase?: string; count?: number; players?: number; members?: string[] };
    if (!info.exists || info.phase !== "lobby") return fail("ROOM_CLOSED");
    if ((info.count ?? 0) >= (info.players ?? 0)) return fail("ROOM_FULL");
    if (info.members?.includes(to)) return fail("ALREADY_IN_ROOM");
    const now = Date.now();
    const all = [...(await this.ctx.storage.list<Invite>({ prefix: "inv:" })).values()];
    const same = all.find((i) => i.from === me && i.to === to && i.code === code && i.status === "pending" && i.expires > now);
    if (same) { this.send(ws, { t: "invite.sent", re, p: { invite: same, duplicate: true } }); return; }
    if (all.filter((i) => i.from === me && i.status === "pending" && i.expires > now).length >= MAX_OUTGOING_INVITES) return fail("INVITE_LIMIT");
    let card = { name: "Oyuncu", tag: 0, avatar: "default" };
    try { card = (await playerCards(this.env, [me])).get(me) ?? card; } catch { /* default card */ }
    const invite: Invite = {
      id: crypto.randomUUID(), from: me, fromName: card.name, fromTag: card.tag, fromAvatar: card.avatar,
      to, code, players: info.players ?? 2, created: now, expires: now + INVITE_TTL_MS, status: "pending",
    };
    await this.ctx.storage.put(`inv:${invite.id}`, invite);
    await this.scheduleExpiry();
    this.notify(to, { t: "invite.new", p: { invite } });
    this.send(ws, { t: "invite.sent", re, p: { invite, duplicate: false } });
  }

  private async answerInvite(ws: WebSocket, re: string, me: string, inviteId: string, accept: boolean): Promise<void> {
    const inv = await this.ctx.storage.get<Invite>(`inv:${inviteId}`);
    if (!inv || inv.to !== me) { this.send(ws, { t: "error", re, p: { code: "INVITE_NOT_FOUND" } }); return; }
    if (inv.status === "accepted" && accept) {          // repeated accept: same answer, nothing done twice
      this.send(ws, { t: "invite.accepted", re, p: { inviteId, code: inv.code, players: inv.players, repeated: true } });
      return;
    }
    if (inv.status !== "pending") { this.send(ws, { t: "error", re, p: { code: inv.status === "expired" ? "INVITE_EXPIRED" : "INVITE_CLOSED" } }); return; }
    if (inv.expires <= Date.now()) {
      await this.finishInvite(inv, "expired");
      this.send(ws, { t: "error", re, p: { code: "INVITE_EXPIRED" } });
      return;
    }
    if (!accept) {
      await this.finishInvite(inv, "declined");
      this.send(ws, { t: "invite.declined", re, p: { inviteId } });
      return;
    }
    const u = await this.userState(me);
    if (u.match) { this.send(ws, { t: "error", re, p: { code: "IN_MATCH" } }); return; }
    if (u.room && u.room !== inv.code) { this.send(ws, { t: "error", re, p: { code: "ALREADY_IN_ROOM", room: u.room } }); return; }
    await this.finishInvite(inv, "accepted");
    this.send(ws, { t: "invite.accepted", re, p: { inviteId, code: inv.code, players: inv.players, repeated: false } });
  }

  private async finishInvite(inv: Invite, status: Invite["status"]): Promise<void> {
    inv.status = status;
    await this.ctx.storage.put(`inv:${inv.id}`, inv);
    const update = { t: "invite.update", p: { inviteId: inv.id, status, to: inv.to, from: inv.from } };
    this.notify(inv.from, update);
    this.notify(inv.to, update);
  }

  private async scheduleExpiry(): Promise<void> {
    const list = await this.ctx.storage.list<Invite>({ prefix: "inv:" });
    const next = Math.min(...[...list.values()].filter((i) => i.status === "pending").map((i) => i.expires));
    if (Number.isFinite(next)) {
      const cur = await this.ctx.storage.getAlarm();
      if (cur === null || cur > next) await this.ctx.storage.setAlarm(next + 50);
    }
  }

  /** Expires invites (both players are told) and drops old finished ones. */
  override async alarm(): Promise<void> {
    const now = Date.now();
    const list = await this.ctx.storage.list<Invite>({ prefix: "inv:" });
    for (const inv of list.values()) {
      if (inv.status === "pending" && inv.expires <= now) await this.finishInvite(inv, "expired");
      else if (inv.status !== "pending" && inv.expires + 3600_000 < now) await this.ctx.storage.delete(`inv:${inv.id}`);
    }
    await this.scheduleExpiry();
  }

  // ---------------------------------------------------------------------- helpers
  private notify(userId: string, msg: Record<string, unknown>): void {
    for (const w of this.sockets(userId)) this.send(w, msg);
  }

  private allow(ws: WebSocket): boolean {
    const now = Date.now();
    const b = this.buckets.get(ws) ?? { tokens: 20, at: now };
    b.tokens = Math.min(20, b.tokens + ((now - b.at) / 1000) * 4);
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
