// Database access of the game server: the restricted Postgres role
// `game_server` (K-59) through Cloudflare Hyperdrive (binding HYPERDRIVE; the
// credentials live in the Hyperdrive config, never in git). Hyperdrive is
// needed because Workers TCP sockets only trust public CAs and Supabase signs
// its database certificates with its own CA. postgres.js over nodejs_compat.
// The role can only EXECUTE a few SECURITY DEFINER functions in schema `game`;
// it cannot read or write tables. DATABASE_URL (secret) remains as a fallback
// for a database with a publicly trusted certificate.
// A connection is opened per call: the server talks to the database only at
// match start (names) and match end (record), never per move.

import postgres from "postgres";

export interface DbEnv {
  HYPERDRIVE?: { connectionString: string };
  DATABASE_URL?: string;
  DB_DISABLED?: string;      // "true": run without a database (local tests)
}

function dbUrl(env: DbEnv): string | null {
  if (env.DB_DISABLED === "true") return null;
  const url = env.HYPERDRIVE?.connectionString ?? env.DATABASE_URL;
  return typeof url === "string" && url.startsWith("postgres") ? url : null;
}

export function dbConfigured(env: DbEnv): boolean {
  return dbUrl(env) !== null;
}

/** Runs fn with a short-lived connection; throws on database errors. */
export async function withDb<T>(env: DbEnv, fn: (sql: postgres.Sql) => Promise<T>): Promise<T> {
  if (!dbConfigured(env)) throw new Error("DB_NOT_CONFIGURED");
  const sql = postgres(dbUrl(env)!, { prepare: false, max: 1, connect_timeout: 10, idle_timeout: 2, fetch_types: false });
  try {
    return await fn(sql);
  } finally {
    await sql.end({ timeout: 2 }).catch(() => undefined);
  }
}

export interface RecordSeat {
  seat: number;
  color: string;
  user_id: string | null;
  is_bot: boolean;
  rank: number;
  left: boolean;
  name: string;
  rolls?: number;
  sixes?: number;
  captures?: number;
  finished?: number;
}

export interface MatchRecordInput {
  matchId: string;
  mode: "quick" | "private" | "test";
  ruleset: unknown;
  seats: RecordSeat[];
  startedAt: number;
  endedAt: number;
  endReason: string;
  actions: string;
  finalStateHash: number;
  actionCount: number;
  serverVersion: string;
}

/** Records a finished free match (idempotent in the database). Returns true if this call stored it. */
/** XP / level result of one player for a recorded match (Phase 6). */
export interface PlayerProgress { xp: number; level_before: number; level_after: number; gold: number }

export async function recordMatch(env: DbEnv, r: MatchRecordInput): Promise<{ applied: boolean; progress: Record<string, PlayerProgress> }> {
  return withDb(env, async (sql) => {
    const rows = await sql`
      select game.record_match(
        ${r.matchId}::uuid, ${r.mode}, ${sql.json(r.ruleset as postgres.JSONValue)}, ${sql.json(r.seats as unknown as postgres.JSONValue)},
        ${new Date(r.startedAt).toISOString()}::timestamptz, ${new Date(r.endedAt).toISOString()}::timestamptz, ${r.endReason},
        ${r.actions}, ${r.finalStateHash}::bigint, ${r.actionCount}::int, ${r.serverVersion}) as result`;
    const raw = rows[0]?.result;
    const result = (typeof raw === "string" ? JSON.parse(raw) : raw) as { applied?: boolean; progress?: Record<string, PlayerProgress> } | undefined;
    return { applied: result?.applied === true, progress: result?.progress ?? {} };
  });
}

/** Profile names of players (for the matchmaker); missing ids are simply absent. */
export interface PlayerCard { name: string; tag: number; avatar: string }

/** Profile cards (name, tag, avatar) of up to 4 players. */
export async function playerCards(env: DbEnv, ids: string[]): Promise<Map<string, PlayerCard>> {
  return withDb(env, async (sql) => {
    // array as a Postgres literal: without fetched types postgres.js cannot serialise uuid[] itself
    const uuids = ids.filter((id) => /^[0-9a-f-]{36}$/i.test(id));
    const rows = await sql`select user_id, display_name, tag, avatar_id from game.player_names(${"{" + uuids.join(",") + "}"}::uuid[])`;
    return new Map(rows.map((r) => [String(r.user_id), { name: String(r.display_name), tag: Number(r.tag), avatar: String(r.avatar_id) }]));
  });
}

export async function playerNames(env: DbEnv, ids: string[]): Promise<Map<string, string>> {
  const cards = await playerCards(env, ids);
  return new Map([...cards].map(([id, c]) => [id, c.name]));
}

/** Friends / blocked between two players (invites). */
export async function socialCheck(env: DbEnv, from: string, to: string): Promise<{ friends: boolean; blocked: boolean }> {
  return withDb(env, async (sql) => {
    const rows = await sql`select game.social_check(${from}::uuid, ${to}::uuid) as r`;
    const r = (typeof rows[0]!.r === "string" ? JSON.parse(rows[0]!.r) : rows[0]!.r) as { friends: boolean; blocked: boolean };
    return { friends: !!r.friends, blocked: !!r.blocked };
  });
}

/** Ids of a player's friends (presence goes to friends only). */
export async function friendIds(env: DbEnv, user: string): Promise<string[]> {
  return withDb(env, async (sql) => {
    const rows = await sql`select array_to_string(game.friend_ids(${user}::uuid), ',') as ids`;
    const ids = String(rows[0]!.ids ?? "");
    return ids ? ids.split(",") : [];
  });
}

/** End of the weekly leaderboard (Phase 6.5): closes finished weeks once and pays their rewards. */
export async function leaderboardMaintenance(env: DbEnv): Promise<{ closed_weeks: number; rewards: number }> {
  return withDb(env, async (sql) => {
    const rows = await sql`select game.leaderboard_maintenance() as r`;
    const raw = rows[0]?.r;
    return (typeof raw === "string" ? JSON.parse(raw) : raw) as { closed_weeks: number; rewards: number };
  });
}

