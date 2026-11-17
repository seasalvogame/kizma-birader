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
  | { t: "action.leave"; id: string; p: Record<string, never> };

const FIELDS: Record<string, string[]> = {
  "hello": ["token"],
  "ping": ["clientTime"],
  "resync": [],
  "action.roll": ["turnId"],
  "action.move": ["turnId", "pawn"],
  "action.leave": [],
};

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
  if (t === "hello" && typeof p.token !== "string") throw new ProtocolError("INVALID_MESSAGE");
  if (t === "ping" && typeof p.clientTime !== "number") throw new ProtocolError("INVALID_MESSAGE");
  return { t, id: o.id, p } as ClientMessage;
}
