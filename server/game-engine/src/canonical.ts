// Canonical state text + FNV-1a 32-bit hash. Used to compare the TypeScript
// and GDScript engines step by step (shared test vectors). The format is part
// of the parity contract: change it in both engines at once.

import { GameState } from "./state.js";

export function canonicalState(s: GameState): string {
  const t = s.turn;
  const players = s.players
    .map((p) => `${p.seat}:${p.color}:${p.kind}:${p.status}:${p.rank}:${p.timeouts}:${p.autopilot ? 1 : 0}:${s.pawns[p.color]!.join(",")}`)
    .join("|");
  const legal = s.legal.map((m) => `${m.pawn}>${m.to}x${m.captures.length}${m.finishes ? "f" : ""}`).join(",");
  return `v${s.version};t${t.seat},${t.phase},${t.dice},${t.sixes},${t.turn_id};${players};r${s.ranks.join(",")};l${s.left_order.join(",")};m${legal}`;
}

export function fnv1a32(text: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    if (c > 0x7f) throw new Error("canonical text must be ASCII");
    h = Math.imul(h ^ c, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

export function stateHash(s: GameState): number {
  return fnv1a32(canonicalState(s));
}
