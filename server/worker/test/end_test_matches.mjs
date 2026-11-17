// Ends matches / rooms the reusable TEST accounts are still in after an aborted test run
// (e.g. a crashed client): every test account in a match leaves it (the server then ends
// it), every test account in a room leaves the room. Only test accounts are touched.
//
//   node test/end_test_matches.mjs <supabase-project-ref> --remote https://... [count=5]

import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { testAccounts } from "./test_accounts.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "../../..");
const ref = process.argv[2];
const remoteArg = process.argv.indexOf("--remote");
const BASE = process.argv[remoteArg + 1].replace(/\/$/, "");
const n = Number(process.argv[remoteArg + 2] ?? 4);
const WIN = process.platform === "win32";
const keysOut = execFileSync(WIN ? "npx.cmd" : "npx", ["supabase", "projects", "api-keys", "--project-ref", ref, "-o", "json"], { cwd: repo, encoding: "utf8", shell: WIN });
const publishable = JSON.parse(keysOut.slice(keysOut.indexOf("["))).find((k) => k.type === "publishable")?.api_key;
const accounts = await testAccounts(`https://${ref}.supabase.co`, publishable, n);

function once(path, token, t, done) {
  return new Promise((resolve) => {
    const ws = new WebSocket(`${BASE.replace(/^http/, "ws")}${path}`);
    const finish = () => { try { ws.close(); } catch { /* closed */ } resolve(); };
    setTimeout(finish, 8000);
    ws.addEventListener("open", () => ws.send(JSON.stringify({ v: 1, t: "hello", id: "h1", p: { token } })));
    ws.addEventListener("message", (e) => {
      const m = JSON.parse(e.data);
      if (m.t === done) { ws.send(JSON.stringify({ v: 1, t, id: "x1", p: {} })); setTimeout(finish, 1500); }
    });
  });
}

for (const a of accounts) {
  const mine = await (await fetch(`${BASE}/v1/rooms/mine`, { headers: { authorization: `Bearer ${a.token}` } })).json();
  if (mine.match) { await once(`/v1/match/${mine.match}`, a.token, "action.leave", "match.snapshot"); console.log(`${a.label}: left its match`); }
  if (mine.room) { await once(`/v1/room/${mine.room}`, a.token, "room.leave", "room.state"); console.log(`${a.label}: left its room`); }
}
for (const a of accounts) {
  const mine = await (await fetch(`${BASE}/v1/rooms/mine`, { headers: { authorization: `Bearer ${a.token}` } })).json();
  console.log(`${a.label}: ${mine.match ? "still in a match" : mine.room ? "still in a room" : "free"}`);
}
