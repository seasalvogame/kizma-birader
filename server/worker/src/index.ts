// Worker entry: routes requests to the right MatchRoom Durable Object.
//   GET  /v1/health                 liveness
//   GET  /v1/queue       (Upgrade)  2-player quick match queue (Matchmaker Durable Object)
//   GET  /v1/match/:id   (Upgrade)  WebSocket to that match (auth = first message "hello")
//   POST /v1/dev/matches            DEV ONLY (ALLOW_DEV_ROUTES): create a match; needs a
//                                   valid Supabase JWT of one of the seated humans.
// The dev route stays for tests and tools; players use the queue.

import { verifySupabaseJwt } from "./auth.js";
import { dbConfigured, playerNames } from "./db.js";
import { Env, MatchRoom, SeatInfo } from "./match_room.js";
import { Matchmaker } from "./matchmaker.js";

export { MatchRoom, Matchmaker };

const COLORS = ["red", "green", "yellow", "blue"] as const;
const OPPOSITE: Record<string, string> = { red: "yellow", yellow: "red", green: "blue", blue: "green" };
const MATCH_ID = /^[0-9a-f]{64}$/;

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { "cache-control": "no-store" } });
}

function confirmedPage(): Response {
  const html = `<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kızma Birader</title><style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
background:radial-gradient(circle at 50% 38%,#3a2a6b,#1d1438 70%,#140e2b);font-family:system-ui,sans-serif;color:#f6efff}
.c{background:#fff3e2;color:#2a1f3d;border-radius:28px;padding:32px 28px;max-width:360px;margin:24px;text-align:center;
box-shadow:0 10px 0 #e8d3b4}h1{margin:0 0 12px;font-size:24px}p{margin:0;line-height:1.5}</style></head><body><div class="c">
<h1>E-posta doğrulandı ✓</h1><p>Hesabın artık kalıcı. Kızma Birader uygulamasına dönüp <b>Hesap</b> ekranında “Kontrol et”e dokunabilirsin.</p>
<p style="margin-top:14px;color:#7a6d91;font-size:14px">Email confirmed. Go back to the app and tap “Check”.</p></div></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store",
    "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'", "x-frame-options": "DENY", "referrer-policy": "no-referrer" } });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/v1/health") {
      // ?db=1 (dev only): one round trip as game_server, to check the database path end to end.
      if (url.searchParams.get("db") === "1" && env.ALLOW_DEV_ROUTES === "true" && dbConfigured(env)) {
        const t0 = Date.now();
        try {
          await playerNames(env, []);
          return json({ ok: true, db: true, db_ok: true, ms: Date.now() - t0 });
        } catch (e) {
          return json({ ok: true, db: true, db_ok: false, error: String((e as Error).message ?? e).replace(/postgres(ql)?:\/\/\S+/g, "<db>").slice(0, 160) });
        }
      }
      return json({ ok: true, service: "kizmabirader-game", db: dbConfigured(env) });
    }

    // Landing page after the e-mail confirmation link (Supabase redirect target).
    // Static; it does not read the tokens in the URL fragment.
    if (url.pathname === "/auth/confirmed") return confirmedPage();

    if (url.pathname === "/v1/queue") {
      if (request.headers.get("Upgrade") !== "websocket") return json({ error: "UPGRADE_REQUIRED" }, 426);
      return env.MATCHMAKER.get(env.MATCHMAKER.idFromName("q:2p:classic_v1")).fetch(request);
    }

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
        body: JSON.stringify({ id: doId.toString(), mode: "test", seats, first_seat: body.first_seat, ruleset: body.ruleset }),
      });
      if (!res.ok) return json(await res.json(), res.status);
      return json({ matchId: doId.toString() });
    }
    return json({ error: "NOT_FOUND" }, 404);
  },
} satisfies ExportedHandler<Env>;
