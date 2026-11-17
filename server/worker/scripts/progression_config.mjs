// Central progression configuration (XP, levels, quests, login rewards, achievements,
// leaderboard): shared/config/*.json is the source, Supabase app_config the runtime copy.
//
//   node scripts/progression_config.mjs --check   compare every file with the database (exit 1 on difference)
//   node scripts/progression_config.mjs --apply   write the files into app_config (balance changes without a migration)
//
// Files and app_config keys: progression_config.json -> 'progression' (more keys are added by later sub-phases).

import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const WIN = process.platform === "win32";
export const CONFIGS = { progression: "shared/config/progression_config.json", quests: "shared/config/quests_config.json", daily_login: "shared/config/daily_login_config.json", achievements: "shared/config/achievements_config.json" };

function query(sql, write) {
  const dir = mkdtempSync(join(tmpdir(), "kb-cfg-"));
  const file = join(dir, "q.sql");
  writeFileSync(file, sql);
  try {
    const out = execFileSync(WIN ? "npx.cmd" : "npx", ["supabase", "db", "query", "--remote", write ? "--yes" : "--read-only", "-f", file, "-o", "json"],
      { cwd: repo, encoding: "utf8", shell: WIN });
    return JSON.parse(out.slice(out.indexOf("{"))).rows ?? [];
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

// canonical JSON (sorted keys) so the database's jsonb key order does not matter
const canon = (v) => Array.isArray(v) ? `[${v.map(canon).join(",")}]`
  : v && typeof v === "object" ? `{${Object.keys(v).sort().map((k) => `${JSON.stringify(k)}:${canon(v[k])}`).join(",")}}` : JSON.stringify(v);

const mode = process.argv[2];
let diff = 0;
for (const [key, path] of Object.entries(CONFIGS)) {
  const file = JSON.parse(readFileSync(join(repo, path), "utf8"));
  if (mode === "--apply") {
    const lit = JSON.stringify(file).replace(/'/g, "''");
    query(`insert into public.app_config (key, value, is_public) values ('${key}', '${lit}'::jsonb, true)
      on conflict (key) do update set value = excluded.value, version = public.app_config.version + 1, updated_at = now();`, true);
    console.log(`applied ${path} -> app_config '${key}'`);
  } else {
    const [row] = query(`select value from public.app_config where key = '${key}';`, false);
    const db = typeof row?.value === "string" ? JSON.parse(row.value) : row?.value;
    const same = db && canon(db) === canon(file);
    if (!same) diff++;
    console.log(`${same ? "same" : "DIFFERENT"}: ${path} <-> app_config '${key}'`);
  }
}
if (mode !== "--apply" && diff) process.exit(1);
