// Four SEPARATE Godot client processes play a 4-player private room on the real server
// (Cloudflare + Supabase): room, joins, colours, ready, host start, a complete match,
// the Supabase record and what each player sees in its history (client/tests/online/test_room4.gd).
// The players are the reusable test accounts (test/test_accounts.mjs): no new guests.
//
//   node test/godot_room4_test.mjs <supabase-project-ref> --remote https://...

import { execFileSync, spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { testAccounts, updateRefreshToken } from "./test_accounts.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "../../..");
const ref = process.argv[2];
const remoteArg = process.argv.indexOf("--remote");
if (!/^[a-z]{20}$/.test(ref ?? "") || remoteArg < 0) throw new Error("usage: node test/godot_room4_test.mjs <project-ref> --remote <url>");
const BASE = process.argv[remoteArg + 1].replace(/\/$/, "");
const SUPABASE = `https://${ref}.supabase.co`;
const WIN = process.platform === "win32";
const npx = WIN ? "npx.cmd" : "npx";
let passed = 0;
const check = (cond, label) => { if (!cond) throw new Error(`FAIL ${label}`); passed++; console.log(`  ok  ${label}`); };

const cli = (args) => execFileSync(npx, ["supabase", ...args], { cwd: repo, encoding: "utf8", shell: WIN });
const keysOut = cli(["projects", "api-keys", "--project-ref", ref, "-o", "json"]);
const publishable = JSON.parse(keysOut.slice(keysOut.indexOf("["))).find((k) => k.type === "publishable")?.api_key;
function sql(query, write = false) {
  const d = mkdtempSync(join(tmpdir(), "kb-sql-"));
  const file = join(d, "q.sql");
  writeFileSync(file, `${query};`);
  try {
    const out = cli(["db", "query", "--remote", write ? "--yes" : "--read-only", "-f", file, "-o", "json"]);
    return JSON.parse(out.slice(out.indexOf("{"))).rows ?? [];
  } finally { rmSync(d, { recursive: true, force: true }); }
}
const cfgString = (s) => `"${String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;

const dir = mkdtempSync(join(tmpdir(), "kb-room4-"));
const accounts = await testAccounts(SUPABASE, publishable, 4);
let recordedId = "";
try {
  // each client gets its own session file with its test account (refresh token)
  const sessions = accounts.map((a, i) => {
    const file = join(dir, `session_${i}.cfg`);
    writeFileSync(file, `[session]\n\nrefresh_token=${cfgString(a.refresh_token)}\nuser_id=${cfgString(a.id)}\nemail=""\nnew_email=""\nis_anonymous=true\n`, { mode: 0o600 });
    return file;
  });
  console.log(`Four Godot processes against ${BASE}`);
  const t0 = Date.now();
  const runs = sessions.map((file, i) => new Promise((done) => {
    const args = ["--headless", "--path", "client", "res://tests/test_runner.tscn", "--", "--online", "--only=room4",
      `--game-url=${BASE}`, `--room4-index=${i}`, `--room4-dir=${dir.replace(/\\/g, "/")}`, `--room4-session=${file.replace(/\\/g, "/")}`,
      `--settings-path=user://test_room4_${i}/settings.cfg`];
    const p = spawn("godot_console", args, { cwd: repo, shell: WIN });
    let out = "";
    p.stdout.on("data", (d) => { out += d; });
    p.stderr.on("data", (d) => { out += d; });
    const kill = setTimeout(() => p.kill(), 25 * 60000);
    p.on("close", (code) => { clearTimeout(kill); done({ i, code, out }); });
  }));
  const results = await Promise.all(runs);
  console.log(`all four processes finished in ${Math.round((Date.now() - t0) / 1000)} s`);
  const parsed = [];
  for (const r of results) {
    for (const line of r.out.split(/\r?\n/)) if (/^(PASS|FAIL|      )/.test(line)) console.log(`  [client ${r.i}] ${line}`);
    const m = r.out.match(/ROOM4_RESULT (\{.*\})/);
    if (m) parsed[r.i] = JSON.parse(m[1]);
    // the Godot client rotated its refresh token: keep the pool usable
    const rt = readFileSync(sessions[r.i], "utf8").match(/refresh_token="([^"]+)"/)?.[1];
    if (rt) updateRefreshToken(accounts[r.i].id, rt);
  }
  check(results.every((r) => r.code === 0) && results.every((r) => /1 test\(s\), 0 failed/.test(r.out)), "all four Godot clients passed their checks");
  check(parsed.length === 4 && parsed.every(Boolean), "all four clients reported the end of the match");
  recordedId = parsed[0].recorded;
  check(new Set(parsed.map((p) => p.match)).size === 1, "all four played the same match");
  check(parsed.every((p) => p.recorded === recordedId), "all four were told the same database record");
  check(parsed.every((p) => JSON.stringify(p.ranks) === JSON.stringify(parsed[0].ranks) && p.version === parsed[0].version),
    `all four see the same final ranking ${JSON.stringify(parsed[0].ranks)} (server state version ${parsed[0].version})`);
  check(new Set(parsed.map((p) => p.my_rank)).size === 4, "places 1..4 are distinct");
  const rows = sql(`select m.mode, m.players, m.status, mp.user_id, mp.rank, mp.color from public.matches m join public.match_players mp on mp.match_id = m.id where m.id = '${recordedId}'`);
  check(rows.length === 4 && rows.every((r) => r.mode === "private" && r.players === 4 && r.status === "finished"), "Supabase has the finished 4-player private match");
  check(parsed.every((p) => rows.find((r) => r.user_id === p.user)?.rank === p.my_rank), "each player's place in Supabase matches what that client saw");
  console.log(`  (actions played per client: ${parsed.map((p) => p.actions).join(", ")})`);
  console.log(`GODOT_ROOM4_PASSED ${passed}`);
} finally {
  if (recordedId) { try { sql(`delete from public.matches where id = '${recordedId}'`, true); console.log("cleanup: match record deleted (test accounts kept)"); } catch { /* ignore */ } }
  rmSync(dir, { recursive: true, force: true });
}
