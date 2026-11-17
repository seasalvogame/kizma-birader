// One-time setup of the game server's restricted database account (K-59).
//
//   node scripts/setup_game_server_db.mjs
//
// The Worker reaches Postgres through Cloudflare Hyperdrive (free plan): Workers
// TCP sockets only trust public CAs, while Supabase signs its database
// certificates with its own CA, so a direct connection from a Worker fails.
//
// What it does (nothing secret is printed, stored in git or written to disk):
//  1. generates a random password in memory;
//  2. sets it on the Postgres role `game_server` as a SCRAM-SHA-256 verifier
//     (the plain password never reaches Supabase, its SQL history or its logs);
//  3. creates (or, on a re-run, updates) the Hyperdrive config "kizmabirader-db"
//     for that role, caching disabled, and adds its binding HYPERDRIVE to
//     wrangler.jsonc (the config id is not a secret);
//  4. removes the old Worker secret DATABASE_URL and server/worker/.dev.vars, if present;
//  5. tests the role from this computer through the session pooler (right after a
//     password change the pooler may still reject it for a while: its auth cache;
//     the Worker does not use that path — check with GET /v1/health?db=1).
// Requires `npx supabase login` + `npx wrangler login`. Run again to rotate the password.
// Note: the password is passed to wrangler as a command-line argument (visible to
// local process listings for a moment); it is never printed.

import { createHash, createHmac, pbkdf2Sync, randomBytes } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const workerDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repo = resolve(workerDir, "../..");
const WIN = process.platform === "win32";
const npx = WIN ? "npx.cmd" : "npx";
const NAME = "kizmabirader-db";

const ref = readFileSync(join(repo, "supabase/.temp/project-ref"), "utf8").trim();
const pooler = readFileSync(join(repo, "supabase/.temp/pooler-url"), "utf8").trim();
const poolerHost = new URL(pooler).hostname;     // e.g. aws-0-eu-central-1.pooler.supabase.com
if (!/^[a-z]{20}$/.test(ref) || !poolerHost.endsWith(".pooler.supabase.com")) throw new Error("unexpected project / pooler");

const password = randomBytes(24).toString("base64url");
const hide = (s) => String(s ?? "").split(password).join("***");
const wrangler = (args) => spawnSync(npx, ["wrangler", ...args], { cwd: workerDir, shell: WIN, encoding: "utf8" });

// 1-2. SCRAM-SHA-256 verifier (RFC 7677 / PostgreSQL format)
const salt = randomBytes(16);
const iterations = 4096;
const salted = pbkdf2Sync(password, salt, iterations, 32, "sha256");
const clientKey = createHmac("sha256", salted).update("Client Key").digest();
const storedKey = createHash("sha256").update(clientKey).digest();
const serverKey = createHmac("sha256", salted).update("Server Key").digest();
const verifier = `SCRAM-SHA-256$${iterations}:${salt.toString("base64")}$${storedKey.toString("base64")}:${serverKey.toString("base64")}`;
const dir = mkdtempSync(join(tmpdir(), "kb-gs-"));
try {
  const sqlFile = join(dir, "role.sql");
  writeFileSync(sqlFile, `alter role game_server with login password '${verifier}';\n`, { mode: 0o600 });
  execFileSync(npx, ["supabase", "db", "query", "--remote", "--yes", "-f", sqlFile], { cwd: repo, shell: WIN, stdio: "ignore" });
  console.log("1/4 game_server password set (SCRAM verifier only)");
} finally {
  rmSync(dir, { recursive: true, force: true });
}

// 3. Hyperdrive config: update an existing one, else create (direct connection first, then the session pooler)
const list = wrangler(["hyperdrive", "list"]);
const existing = (list.stdout.split(/\r?\n/).find((l) => l.includes(NAME)) ?? "").match(/[0-9a-f]{32}/)?.[0];
let id = existing;
if (existing) {
  const up = wrangler(["hyperdrive", "update", existing, "--origin-password", password]);
  if (up.status !== 0) { console.log(hide(up.stdout + up.stderr)); throw new Error("hyperdrive update failed"); }
  console.log(`2/4 Hyperdrive ${NAME} updated with the new password`);
} else {
  const candidates = [
    { label: "direct connection", host: `db.${ref}.supabase.co`, port: "5432", user: "game_server" },
    { label: "session pooler", host: poolerHost, port: "5432", user: `game_server.${ref}` },
  ];
  for (const c of candidates) {
    const r = wrangler(["hyperdrive", "create", NAME, "--origin-host", c.host, "--origin-port", c.port, "--database", "postgres",
      "--origin-user", c.user, "--origin-password", password, "--caching-disabled", "--origin-connection-limit", "5",
      "--binding", "HYPERDRIVE", "--update-config"]);
    const out = hide(r.stdout + r.stderr);
    id = out.match(/"id":\s*"([0-9a-f]{32})"/)?.[1] ?? out.match(/\b([0-9a-f]{32})\b/)?.[1];
    if (r.status === 0 && id) { console.log(`2/4 Hyperdrive ${NAME} created (${c.label}), binding HYPERDRIVE added to wrangler.jsonc`); break; }
    console.log(`    ${c.label} not usable:\n` + out.split(/\r?\n/).filter((l) => /error|fail|could not|tls|ssl|cert/i.test(l)).slice(0, 6).join("\n"));
    id = undefined;
  }
  if (!id) throw new Error("Hyperdrive could not connect to the database (see the messages above)");
}
console.log(`    Hyperdrive id: ${id}`);

// 4. the old direct-connection secret is no longer used
const secrets = wrangler(["secret", "list"]);
if (secrets.stdout.includes("DATABASE_URL")) {
  const del = spawnSync(npx, ["wrangler", "secret", "delete", "DATABASE_URL"], { cwd: workerDir, shell: WIN, input: "y\n", encoding: "utf8" });
  console.log(del.status === 0 ? "3/4 old Worker secret DATABASE_URL removed" : "3/4 could not remove DATABASE_URL (remove it in the dashboard)");
} else console.log("3/4 no old DATABASE_URL secret");
if (existsSync(join(workerDir, ".dev.vars"))) rmSync(join(workerDir, ".dev.vars"));

// 5. role test (from this computer through the session pooler, IPv4)
const postgres = (await import("postgres")).default;
const sql = postgres({ host: poolerHost, port: 5432, database: "postgres", username: `game_server.${ref}`, password, ssl: "require", prepare: false, max: 1, connect_timeout: 15 });
try {
  await sql`select * from game.player_names(array[]::uuid[])`;
  let denied = false;
  try { await sql`select count(*) from public.profiles`; } catch { denied = true; }
  console.log(`4/4 connection ok as game_server; direct table read denied: ${denied ? "yes" : "NO (check grants!)"}`);
} catch (e) {
  console.log("4/4 connection test failed: " + hide(e.message));
} finally {
  await sql.end({ timeout: 5 });
}
