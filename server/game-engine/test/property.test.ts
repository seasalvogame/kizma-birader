// Invariants over thousands of random games (TESTING_AND_PERFORMANCE §2.2).

import fc from "fast-check";
import { describe, expect, it } from "vitest";
import { canonicalState, createGame, GameState, maxDiceValue, seededRandom } from "../src/index.js";
import { E } from "./helpers.js";

/** Plays one game with random dice and random legal choices; checks invariants after every action. */
function playRandom(seed: number, players: 2 | 4, check: (prev: GameState, next: GameState) => void): GameState {
  const rnd = seededRandom(seed);
  let s = createGame({ players, firstSeat: Math.floor(rnd() * players) });
  for (let step = 0; step < 5000; step++) {
    if (s.turn.phase === "game_over") return s;
    const seat = s.turn.seat;
    let r;
    const roll = rnd();
    if (roll < 0.01) r = E.apply(s, { type: "timeout", seat, turn_id: s.turn.turn_id }, 1 + Math.floor(rnd() * maxDiceValue(s)));
    else if (s.turn.phase === "roll") r = E.apply(s, { type: "roll", seat, turn_id: s.turn.turn_id }, 1 + Math.floor(rnd() * maxDiceValue(s)));
    else r = E.apply(s, { type: "move", seat, turn_id: s.turn.turn_id, pawn: s.legal[Math.floor(rnd() * s.legal.length)]!.pawn });
    if (!r.ok) throw new Error(`seed ${seed}: unexpected ${r.error}`);
    check(s, r.state);
    s = r.state;
  }
  throw new Error(`seed ${seed}: game did not end`);
}

function check(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

/** Plain checks (no expect per step: thousands of steps per game). */
function invariants(prev: GameState, s: GameState): void {
  check(s.version === prev.version + 1, "version +1");
  for (const p of s.players) {
    const steps = s.pawns[p.color]!;
    check(steps.length === 4, "4 pawns");
    const before = prev.pawns[p.color]!;
    steps.forEach((st, i) => {
      check(st >= -1 && st <= 56, `step range ${st}`);
      // a pawn only moves forward, unless captured or its player left (back to -1)
      check(st === -1 || st >= before[i]!, `pawn went back ${before[i]} -> ${st}`);
    });
  }
  // two colours never share a non-safe track cell
  const seen = new Map<number, string>();
  for (const p of s.players) {
    if (p.status !== "active") continue;
    for (const st of s.pawns[p.color]!) {
      const t = E.board.trackIndex(p.color, st);
      if (t < 0 || E.board.isSafeTrack(t)) continue;
      const other = seen.get(t);
      check(other === undefined || other === p.color, `${other} and ${p.color} share track ${t}`);
      seen.set(t, p.color);
    }
  }
  if (s.turn.phase === "move") {
    check(s.legal.length > 0, "move phase without legal moves");
    check(s.players[s.turn.seat]!.status === "active", "inactive seat to move");
  }
  if (s.turn.phase === "roll") check(s.legal.length === 0, "legal moves in roll phase");
  check(s.turn.sixes < s.ruleset.max_consecutive_sixes, "too many sixes kept");
}

describe("random games", () => {
  it("2-player games keep every invariant and end with a winner", () => {
    fc.assert(fc.property(fc.integer({ min: 1, max: 2 ** 31 - 1 }), (seed) => {
      const end = playRandom(seed, 2, invariants);
      expect(end.ranks).toHaveLength(2);
      const winner = end.players[end.ranks[0]!]!;
      expect(end.pawns[winner.color]).toEqual([56, 56, 56, 56]);
    }), { numRuns: 300 });
  }, 120_000);

  it("4-player games keep every invariant and rank all four", () => {
    fc.assert(fc.property(fc.integer({ min: 1, max: 2 ** 31 - 1 }), (seed) => {
      const end = playRandom(seed, 4, invariants);
      expect([...end.ranks].sort()).toEqual([0, 1, 2, 3]);
      for (const seat of end.ranks.slice(0, 3)) expect(end.pawns[end.players[seat]!.color]).toEqual([56, 56, 56, 56]);
    }), { numRuns: 200 });
  }, 120_000);

  it("the same seed replays the same game (determinism)", () => {
    for (const seed of [1, 42, 99999]) {
      const a = canonicalState(playRandom(seed, 4, () => {}));
      const b = canonicalState(playRandom(seed, 4, () => {}));
      expect(a).toBe(b);
    }
  }, 60_000);

  it("bot-only games always finish (no stuck states)", () => {
    for (let seed = 1; seed <= 200; seed++) {
      const rnd = seededRandom(seed);
      let s = createGame({ players: seed % 2 ? 2 : 4 });
      let guard = 0;
      while (s.turn.phase !== "game_over") {
        const r = E.apply(s, { type: "timeout", seat: s.turn.seat, turn_id: s.turn.turn_id }, 1 + Math.floor(rnd() * maxDiceValue(s)));
        if (!r.ok) throw new Error(r.error);
        s = r.state;
        if (++guard > 5000) throw new Error(`seed ${seed} stuck`);
      }
    }
  }, 120_000);
});
