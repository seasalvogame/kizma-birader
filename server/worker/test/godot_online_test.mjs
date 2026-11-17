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
let recorded = "";
try {
  if (!REMOTE) {
    dev = spawn(npx, ["wrangler", "dev", "--port", String(PORT), "--ip", "127.0.0.1", "--var", "DB_DISABLED:true"], { cwd: workerDir, shell: WIN, stdio: "ignore" });
  }
  await waitHealth();
  const health = await (await fetch(`${BASE}/v1/health`)).json();
  console.log(`server: ${REMOTE ? "Cloudflare " + BASE : "local wrangler dev"}${health.db ? " + Supabase records" : " (no database)"}`);
  const args = ["--headless", "--path", "client", "res://tests/test_runner.tscn", "--", "--online", `--game-url=${BASE}`];
  if (health.db) args.push("--expect-db");
  const godot = spawnSync("godot_console", args,
    { cwd: repo, encoding: "utf8", shell: WIN, timeout: 900000 });
  const out = (godot.stdout ?? "") + (godot.stderr ?? "");
  const m = out.match(/ONLINE_USERS ([0-9a-f-]+),([0-9a-f-]+)/);
  if (m) users = [m[1], m[2]];
  const rec = out.match(/ONLINE_RECORDED ([0-9a-f-]{36})/);
  if (rec) recorded = rec[1];
  for (const line of out.split(/\r?\n/)) {
    if (/^(PASS|FAIL|      |ONLINE_MATCH|\d+ test)/.test(line)) console.log(line);
  }
  if (godot.status !== 0) process.exitCode = 1;
} finally {
  if (dev) {
    if (WIN) { try { execFileSync("taskkill", ["/PID", String(dev.pid), "/T", "/F"], { stdio: "ignore" }); } catch { /* gone */ } }
    else dev.kill("SIGTERM");
  }
  if (users.length) {
    const dir = mkdtempSync(join(tmpdir(), "kb-godot-"));
    const file = join(dir, "cleanup.sql");
    writeFileSync(file, (recorded ? `delete from public.matches where id = '${recorded}';\n` : "") +
      `delete from auth.users where id in (${users.map((u) => `'${u}'`).join(",")});\n`);
    try { execFileSync(npx, ["supabase", "db", "query", "--remote", "--yes", "-f", file], { cwd: repo, shell: WIN, stdio: "ignore" }); }
    finally { rmSync(dir, { recursive: true, force: true }); }
    console.log(`cleanup: deleted ${users.length} guest accounts${recorded ? " and the test match record" : ""}`);
  }
}
