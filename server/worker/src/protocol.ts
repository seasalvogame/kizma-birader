// Client -> server messages (NETWORK_PROTOCOL §2, §4; subset of Phase 3.3).
// Strict: unknown types and unknown fields are rejected, so a client can never
// send a dice value or a seat number (the seat comes from the authenticated
// connection).

export class ProtocolError extends Error {
  constructor(readonly code: string) { super(code); }
}

export type ClientMessage =
  | { t: "hello"; id: string; p: { token: string } }
  | { t: "ping"; id: string; p: { clientTime: number } }
  | { t: "resync"; id: string; p: Record<string, never> }
  | { t: "action.roll"; id: string; p: { turnId: number } }
  | { t: "action.move"; id: string; p: { turnId: number; pawn: number } }
  | { t: "action.emote"; id: string; p: { emoteId: string } }
  | { t: "action.leave"; id: string; p: Record<string, never> }
  | { t: "queue.join"; id: string; p: { mode: string; name: string } }
  | { t: "queue.leave"; id: string; p: Record<string, never> }
  // social hub (presence, invites)
  | { t: "presence.sync"; id: string; p: Record<string, never> }
  | { t: "friends.changed"; id: string; p: { other: string } }
  | { t: "poke"; id: string; p: { to: string; kind: string } }
  | { t: "invite.send"; id: string; p: { to: string; code: string } }
  | { t: "invite.accept"; id: string; p: { inviteId: string } }
  | { t: "invite.decline"; id: string; p: { inviteId: string } }
  | { t: "invite.list"; id: string; p: Record<string, never> }
  // private room lobby
  | { t: "room.color"; id: string; p: { color: string } }
  | { t: "room.ready"; id: string; p: { ready: boolean } }
  | { t: "room.start"; id: string; p: Record<string, never> }
  | { t: "room.leave"; id: string; p: Record<string, never> };

const FIELDS: Record<string, string[]> = {
  "hello": ["token"],
  "ping": ["clientTime"],
  "resync": [],
  "action.roll": ["turnId"],
  "action.move": ["turnId", "pawn"],
  "action.emote": ["emoteId"],
  "action.leave": [],
  "queue.join": ["mode", "name"],
  "queue.leave": [],
  "presence.sync": [],
  "friends.changed": ["other"],
  "poke": ["to", "kind"],
  "invite.send": ["to", "code"],
  "invite.accept": ["inviteId"],
  "invite.decline": ["inviteId"],
  "invite.list": [],
  "room.color": ["color"],
  "room.ready": ["ready"],
  "room.start": [],
  "room.leave": [],
};

/** {re: id} when a raw (possibly invalid) message carries a readable request id. */
export function requestIdOf(raw: string | ArrayBuffer): { re?: string } {
  if (typeof raw !== "string" || raw.length > MAX_BYTES) return {};
  try {
    const id = (JSON.parse(raw) as { id?: unknown }).id;
    return typeof id === "string" && REQ_ID.test(id) ? { re: id } : {};
  } catch { return {}; }
}

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
/** Private room codes: 6 characters without look-alikes (0/O, 1/I/L): 31^6 ≈ 8.9e8 codes. */
export const ROOM_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const ROOM_CODE = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/;
export const POKE_KINDS = ["friend_request", "friend_accepted", "friends_changed"];

const MAX_BYTES = 8192;
const REQ_ID = /^[A-Za-z0-9_-]{1,64}$/;

export function parseClientMessage(raw: string | ArrayBuffer): ClientMessage {
  if (typeof raw !== "string" || raw.length > MAX_BYTES) throw new ProtocolError("INVALID_MESSAGE");
  let m: unknown;
  try { m = JSON.parse(raw); } catch { throw new ProtocolError("INVALID_MESSAGE"); }
  if (typeof m !== "object" || m === null) throw new ProtocolError("INVALID_MESSAGE");
  const o = m as Record<string, unknown>;
  for (const k of Object.keys(o)) if (!["v", "t", "id", "p"].includes(k)) throw new ProtocolError("INVALID_MESSAGE");
  if (o.v !== 1) throw new ProtocolError("VERSION_UNSUPPORTED");
  const t = o.t;
  if (typeof t !== "string" || !(t in FIELDS)) throw new ProtocolError("INVALID_MESSAGE");
  if (typeof o.id !== "string" || !REQ_ID.test(o.id)) throw new ProtocolError("INVALID_MESSAGE");
  const p = (o.p ?? {}) as Record<string, unknown>;
  if (typeof p !== "object" || Array.isArray(p)) throw new ProtocolError("INVALID_MESSAGE");
  const allowed = FIELDS[t]!;
  for (const k of Object.keys(p)) if (!allowed.includes(k)) throw new ProtocolError("INVALID_MESSAGE");
  for (const k of allowed) if (!(k in p)) throw new ProtocolError("INVALID_MESSAGE");
  if (t === "action.roll" || t === "action.move") {
    if (!Number.isInteger(p.turnId)) throw new ProtocolError("INVALID_MESSAGE");
  }
  if (t === "action.move" && !(Number.isInteger(p.pawn) && (p.pawn as number) >= 0 && (p.pawn as number) <= 3)) {
    throw new ProtocolError("INVALID_MESSAGE");
  }
  if (t === "action.emote" && (typeof p.emoteId !== "string" || !/^[a-z_]{2,16}$/.test(p.emoteId))) throw new ProtocolError("INVALID_MESSAGE");
  if (t === "hello" && typeof p.token !== "string") throw new ProtocolError("INVALID_MESSAGE");
  if (t === "ping" && typeof p.clientTime !== "number") throw new ProtocolError("INVALID_MESSAGE");
  if (t === "queue.join" && (typeof p.mode !== "string" || typeof p.name !== "string" || (p.name as string).length > 64)) {
    throw new ProtocolError("INVALID_MESSAGE");
  }
  const str = (k: string, re: RegExp) => { if (typeof p[k] !== "string" || !re.test(p[k] as string)) throw new ProtocolError("INVALID_MESSAGE"); };
  if (t === "friends.changed") str("other", UUID);
  if (t === "poke") { str("to", UUID); if (!POKE_KINDS.includes(p.kind as string)) throw new ProtocolError("INVALID_MESSAGE"); }
  if (t === "invite.send") { str("to", UUID); str("code", ROOM_CODE); }
  if (t === "invite.accept" || t === "invite.decline") str("inviteId", /^[A-Za-z0-9-]{8,64}$/);
  if (t === "room.color" && !["red", "green", "yellow", "blue"].includes(p.color as string)) throw new ProtocolError("INVALID_MESSAGE");
  if (t === "room.ready" && typeof p.ready !== "boolean") throw new ProtocolError("INVALID_MESSAGE");
  return { t, id: o.id, p } as ClientMessage;
}
