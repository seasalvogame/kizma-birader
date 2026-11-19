// Matchmaker — one Durable Object per queue (CLOUDFLARE_ARCHITECTURE §3.2).
// Phase 3.3: 2-player quick match only. Two different authenticated players
// in the queue are paired; the server picks an opposite colour pair
// (red–yellow or green–blue) and the seats at random, creates the MatchRoom
// and tells both players. Colour preferences (K-55) are not decided yet, so
// the client cannot ask for a colour here.
//
// The waiting list lives in the WebSocket attachments (Hibernation API), so a
// hibernated / restarted object still knows who is waiting.

import { DurableObject } from "cloudflare:workers";
import { verifySupabaseJwt } from "./auth.js";
import { dbConfigured, playerCards } from "./db.js";
import type { Env, SeatInfo } from "./match_room.js";
import { ClientMessage, parseClientMessage, ProtocolError } from "./protocol.js";

interface Waiting { authed: boolean; userId?: string; name?: string; waiting?: boolean; since?: number; replaced?: boolean }

const PAIRS: [SeatInfo["color"], SeatInfo["color"]][] = [["red", "yellow"], ["green", "blue"]];

function cleanName(raw: unknown): string {
  const n = typeof raw === "string" ? raw.replace(/[\u0000-\u001f\u007f]/g, "").trim() : "";
  return n.length >= 3 && n.length <= 16 ? n : "Oyuncu";
}

function pick<T>(items: readonly T[]): T {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  return items[buf[0]! % items.length]!;
}

export class Matchmaker extends DurableObject<Env> {
  override async fetch(request: Request): Promise<Response> {
    if (request.headers.get("Upgrade") !== "websocket") return new Response("upgrade required", { status: 426 });
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair) as [WebSocket, WebSocket];
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ authed: false } satisfies Waiting);
    return new Response(null, { status: 101, webSocket: client });
  }

  override async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    let msg: ClientMessage;
    try {
      msg = parseClientMessage(raw);
    } catch (e) {
      this.send(ws, { t: "error", p: { code: e instanceof ProtocolError ? e.code : "INVALID_MESSAGE" } });
      return;
    }
    const att = (ws.deserializeAttachment() ?? { authed: false }) as Waiting;
    // A connection replaced by a newer one of the same player is finished: messages it
    // still had in flight must not act (they would cancel the newer connection).
    if (att.replaced) return;
    if (msg.t === "hello") {
      const identity = await verifySupabaseJwt(msg.p.token, this.env.SUPABASE_URL);
      if (!identity) {
        this.send(ws, { t: "error", re: msg.id, p: { code: "AUTH_INVALID" } });
        ws.close(4001, "auth");
        return;
      }
      ws.serializeAttachment({ authed: true, userId: identity.userId } satisfies Waiting);
      this.send(ws, { t: "welcome", re: msg.id, p: { userId: identity.userId, serverTime: Date.now() } });
      return;
    }
    if (!att.authed || !att.userId) {
      this.send(ws, { t: "error", re: msg.id, p: { code: "AUTH_REQUIRED" } });
      return;
    }
    if (msg.t === "queue.leave") {
      ws.serializeAttachment({ ...att, waiting: false } satisfies Waiting);
      this.send(ws, { t: "queue.cancelled", re: msg.id, p: { reason: "user" } });
      return;
    }
    if (msg.t !== "queue.join") {
      this.send(ws, { t: "error", re: msg.id, p: { code: "INVALID_MESSAGE" } });
      return;
    }
    if (msg.p.mode !== "2p") {
      this.send(ws, { t: "error", re: msg.id, p: { code: "MODE_UNAVAILABLE" } });
      return;
    }
    // One place in the queue per user: an older connection of the same user is dropped.
    for (const other of this.ctx.getWebSockets()) {
      const o = other.deserializeAttachment() as Waiting | null;
      if (other !== ws && o?.userId === att.userId && !o.replaced) {
        other.serializeAttachment({ ...o, waiting: false, replaced: true } satisfies Waiting);
        this.send(other, { t: "queue.cancelled", p: { reason: "replaced" } });
        other.close(4009, "replaced");
      }
    }
    ws.serializeAttachment({ ...att, waiting: true, since: Date.now(), name: cleanName(msg.p.name) } satisfies Waiting);
    this.send(ws, { t: "queue.status", re: msg.id, p: { state: "searching" } });
    await this.pairUp();
  }

  override async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    try { ws.close(code === 1005 ? 1000 : code, "bye"); } catch { /* closed */ }
  }

  private async pairUp(): Promise<void> {
    const waiting = this.ctx.getWebSockets()
      .map((ws) => ({ ws, a: ws.deserializeAttachment() as Waiting | null }))
      .filter((x) => x.a?.authed && x.a.waiting && x.ws.readyState === WebSocket.READY_STATE_OPEN)
      .sort((x, y) => (x.a!.since ?? 0) - (y.a!.since ?? 0));
    while (waiting.length >= 2) {
      const p1 = waiting.shift()!;
      const i2 = waiting.findIndex((x) => x.a!.userId !== p1.a!.userId);
      if (i2 < 0) break;
      const p2 = waiting.splice(i2, 1)[0]!;
      // Take both out of the queue BEFORE any await: a concurrent pairUp() (another
      // message arriving meanwhile) must not pair them a second time.
      for (const p of [p1, p2]) p.ws.serializeAttachment({ ...p.a!, waiting: false } satisfies Waiting);
      const colors = pick(PAIRS);
      const players = pick([[p1, p2], [p2, p1]] as const);
      // Names from the players' profiles (database), not from the client; client names only as a fallback.
      let cards = new Map<string, { name: string; cosmetics: Record<string, string>; emotes: string[] }>();
      if (dbConfigured(this.env)) {
        try { cards = await playerCards(this.env, [p1.a!.userId!, p2.a!.userId!]); } catch { /* fallback */ }
      }
      const seats: SeatInfo[] = colors.map((color, seat) => ({
        seat, color, user_id: players[seat]!.a!.userId!, is_bot: false,
        name: cards.get(players[seat]!.a!.userId!)?.name ?? players[seat]!.a!.name ?? "Oyuncu",
        cosmetics: cards.get(players[seat]!.a!.userId!)?.cosmetics ?? {},
        emotes: cards.get(players[seat]!.a!.userId!)?.emotes ?? ["hello", "gg", "go", "wow"],
      }));
      const id = this.env.MATCH_ROOM.newUniqueId();
      const res = await this.env.MATCH_ROOM.get(id).fetch("https://match/init", {
        method: "POST", body: JSON.stringify({ id: id.toString(), mode: "quick", seats }),
      });
      if (!res.ok) {
        for (const p of [p1, p2]) this.send(p.ws, { t: "error", p: { code: "TRY_AGAIN" } });
        continue;
      }
      // A player who disconnected meanwhile still gets the match (the server plays for an
      // absent player and they can reconnect); a closed socket simply misses the message.
      for (const [seat, p] of players.entries()) {
        if (p.ws.readyState !== WebSocket.READY_STATE_OPEN) continue;
        this.send(p.ws, { t: "match.found", p: { matchId: id.toString(), seat, color: seats[seat]!.color, seats } });
      }
    }
  }

  private send(ws: WebSocket, msg: Record<string, unknown>): void {
    try { ws.send(JSON.stringify({ v: 1, st: Date.now(), ...msg })); } catch { /* closed */ }
  }
}
