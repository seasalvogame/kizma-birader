// Worker entry: routes requests to the right MatchRoom Durable Object.
//   GET  /v1/health                 liveness
//   GET  /v1/match/:id   (Upgrade)  WebSocket to that match (auth = first message "hello")
//   POST /v1/dev/matches            DEV ONLY (ALLOW_DEV_ROUTES): create a match; needs a
//                                   valid Supabase JWT of one of the seated humans.
// The matchmaker (Phase 4) will replace the dev route.

import { verifySupabaseJwt } from "./auth.js";
import { Env, MatchRoom, SeatInfo } from "./match_room.js";

export { MatchRoom };

const COLORS = ["red", "green", "yellow", "blue"] as const;
const OPPOSITE: Record<string, string> = { red: "yellow", yellow: "red", green: "blue", blue: "green" };
const MATCH_ID = /^[0-9a-f]{64}$/;

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { "cache-control": "no-store" } });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/v1/health") return json({ ok: true, service: "kizmabirader-game" });

    const m = url.pathname.match(/^\/v1\/match\/([^/]+)$/);
    if (m) {
      if (request.headers.get("Upgrade") !== "websocket") return json({ error: "UPGRADE_REQUIRED" }, 426);
      const id = m[1]!;
      if (!MATCH_ID.test(id)) return json({ error: "MATCH_NOT_FOUND" }, 404);
      let doId: DurableObjectId;
      try { doId = env.MATCH_ROOM.idFromString(id); } catch { return json({ error: "MATCH_NOT_FOUND" }, 404); }
      return env.MATCH_ROOM.get(doId).fetch(request);
    }

    if (url.pathname === "/v1/dev/matches" && request.method === "POST") {
      if (env.ALLOW_DEV_ROUTES !== "true") return json({ error: "NOT_FOUND" }, 404);
      const auth = request.headers.get("authorization") ?? "";
      const identity = await verifySupabaseJwt(auth.replace(/^Bearer /, ""), env.SUPABASE_URL);
      if (!identity) return json({ error: "AUTH_INVALID" }, 401);
      let body: { seats?: SeatInfo[]; first_seat?: number; ruleset?: Record<string, unknown> };
      try { body = await request.json(); } catch { return json({ error: "INVALID_MESSAGE" }, 400); }
      const seats = (body.seats ?? []).map((s, i) => ({
        seat: i, color: s.color, user_id: s.is_bot ? null : (s.user_id ?? null), is_bot: !!s.is_bot,
        name: String(s.name ?? (s.is_bot ? `Bot ${i}` : `Oyuncu ${i + 1}`)).slice(0, 16),
      }));
      if (seats.length !== 2 && seats.length !== 4) return json({ error: "BAD_SEATS" }, 400);
      if (seats.some((s) => !COLORS.includes(s.color))) return json({ error: "BAD_SEATS" }, 400);
      if (seats.length === 2 && OPPOSITE[seats[0]!.color] !== seats[1]!.color) return json({ error: "COLOR_INVALID" }, 400);
      if (!seats.some((s) => s.user_id === identity.userId)) return json({ error: "NOT_IN_MATCH" }, 403);
      const doId = env.MATCH_ROOM.newUniqueId();
      const res = await env.MATCH_ROOM.get(doId).fetch("https://match/init", {
        method: "POST",
        body: JSON.stringify({ id: doId.toString(), seats, first_seat: body.first_seat, ruleset: body.ruleset }),
      });
      if (!res.ok) return json(await res.json(), res.status);
      return json({ matchId: doId.toString() });
    }
    return json({ error: "NOT_FOUND" }, 404);
  },
} satisfies ExportedHandler<Env>;
