// Runs the Godot client's online end-to-end test (client/tests/online) against
// the game server, then deletes the two guest accounts it created.
//
//   node test/godot_online_test.mjs                      (local: starts wrangler dev)
//   node test/godot_online_test.mjs --remote https://... (deployed Worker on Cloudflare)

import { execFileSync, spawn, spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { readFileSync as readText } from "node:fs";
import { resetSql, testAccounts, updateRefreshToken } from "./test_accounts.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const workerDir = resolve(here, "..");
const repo = resolve(workerDir, "../..");
const WIN = process.platform === "win32";
const npx = WIN ? "npx.cmd" : "npx";
const remoteArg = process.argv.indexOf("--remote");
const REMOTE = remoteArg > 0 ? process.argv[remoteArg + 1].replace(/\/$/, "") : "";
const PORT = 8787;
const BASE = REMOTE || `http://127.0.0.1:${PORT}`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let dev = null;
async function waitHealth() {
  for (let i = 0; i < 180; i++) {
    try { if ((await fetch(`${BASE}/v1/health`)).ok) return; } catch { /* starting */ }
    await sleep(500);
  }
  throw new Error("game server not reachable at " + BASE);
}

let users = [];
let pool = [];
let sessionDir = "";
const REF = (() => { try { return readText(join(repo, "supabase/.temp/project-ref"), "utf8").trim(); } catch { return ""; } })();
function sqlWrite(query) {
  const d = mkdtempSync(join(tmpdir(), "kb-sql-"));
  const f = join(d, "q.sql");
  writeFileSync(f, query + ";\n");
  try { execFileSync(npx, ["supabase", "db", "query", "--remote", "--yes", "-f", f], { cwd: repo, shell: WIN, stdio: "ignore" }); }
  finally { rmSync(d, { recursive: true, force: true }); }
}
const recorded = [];
try {
  if (!REMOTE) {
    dev = spawn(npx, ["wrangler", "dev", "--port", String(PORT), "--ip", "127.0.0.1", "--var", "DB_DISABLED:true"], { cwd: workerDir, shell: WIN, stdio: "ignore" });
  }
  await waitHealth();
  const health = await (await fetch(`${BASE}/v1/health`)).json();
  console.log(`server: ${REMOTE ? "Cloudflare " + BASE : "local wrangler dev"}${health.db ? " + Supabase records" : " (no database)"}`);
  // the players are the reusable test accounts (KBTest1-4): no new guest accounts
  const keysOut = execFileSync(npx, ["supabase", "projects", "api-keys", "--project-ref", REF, "-o", "json"], { cwd: repo, encoding: "utf8", shell: WIN });
  const publishable = JSON.parse(keysOut.slice(keysOut.indexOf("["))).find((k) => k.type === "publishable")?.api_key;
  pool = await testAccounts(`https://${REF}.supabase.co`, publishable, 4);
  sqlWrite(resetSql(pool.map((a) => a.id)));
  sessionDir = mkdtempSync(join(tmpdir(), "kb-godot-sessions-"));
  const names = ["online_a", "online_b", "room_a", "room_b"];
  pool.forEach((a, i) => writeFileSync(join(sessionDir, `${names[i]}.cfg`),
    `[session]\n\nrefresh_token="${a.refresh_token}"\nuser_id="${a.id}"\nemail=""\nnew_email=""\nis_anonymous=true\n`, { mode: 0o600 }));
  const args = ["--headless", "--path", "client", "res://tests/test_runner.tscn", "--", "--online", `--game-url=${BASE}`,
    `--test-session-dir=${sessionDir.replace(/\\/g, "/")}`];
  if (health.db) args.push("--expect-db");
  const godot = spawnSync("godot_console", args,
    { cwd: repo, encoding: "utf8", shell: WIN, timeout: 900000 });
  const out = (godot.stdout ?? "") + (godot.stderr ?? "");
  for (const m of out.matchAll(/ONLINE_USERS ([0-9a-f-]+),([0-9a-f-]+)/g)) users.push(m[1], m[2]);
  for (const r of out.matchAll(/ONLINE_RECORDED ([0-9a-f-]{36})/g)) recorded.push(r[1]);
  for (const line of out.split(/\r?\n/)) {
    if (/^(PASS|FAIL|      |ONLINE_MATCH|\d+ test)/.test(line)) console.log(line);
  }
  if (godot.status !== 0) process.exitCode = 1;
} finally {
  if (dev) {
    if (WIN) { try { execFileSync("taskkill", ["/PID", String(dev.pid), "/T", "/F"], { stdio: "ignore" }); } catch { /* gone */ } }
    else dev.kill("SIGTERM");
  }
  if (sessionDir) {
    const names = ["online_a", "online_b", "room_a", "room_b"];
    pool.forEach((acc, i) => {
      try {
        const rt = readText(join(sessionDir, `${names[i]}.cfg`), "utf8").match(/refresh_token="([^"]+)"/)?.[1];
        if (rt) updateRefreshToken(acc.id, rt);
      } catch { /* keep the old token */ }
    });
    rmSync(sessionDir, { recursive: true, force: true });
    sqlWrite(resetSql(pool.map((acc) => acc.id)));
    console.log(`cleanup: test accounts reset (${users.length} sessions used, ${recorded.length} match records removed with them)`);
  }
}
