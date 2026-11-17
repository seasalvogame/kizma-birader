// Dice security (GAME_RULES §3, §6.2; SECURITY_ARCHITECTURE §5): the server
// dice source is a CSPRNG without modulo bias, honours the 1..5 bound after
// two sixes, and the engine has no Node-only dependency (Cloudflare Workers).

import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  createGame, cryptoDice, DiceSource, maxDiceValue, MatchSession, PawnSteps, scriptedDice, secureRandomInt, seededDice,
} from "../src/index.js";
import { E } from "./helpers.js";

/** Chi-square statistic of observed counts against a uniform distribution. */
function chiSquare(counts: number[]): number {
  const n = counts.reduce((a, b) => a + b, 0);
  const expected = n / counts.length;
  return counts.reduce((sum, c) => sum + (c - expected) ** 2 / expected, 0);
}

function sample(max: number, n: number): number[] {
  const counts = new Array<number>(max).fill(0);
  for (let i = 0; i < n; i++) {
    const v = cryptoDice.next(max);
    if (!Number.isInteger(v) || v < 1 || v > max) throw new Error(`out of range ${v}`);
    counts[v - 1]!++;
  }
  return counts;
}

describe("secure dice source", () => {
  afterEach(() => vi.restoreAllMocks());

  it("1..6 is uniform (chi-square, 120,000 rolls)", () => {
    const counts = sample(6, 120_000);
    // df = 5; 40 is far beyond the 1e-6 tail, so this only fails on a real bias.
    expect(chiSquare(counts)).toBeLessThan(40);
  });

  it("after two sixes the source never yields a 6 and 1..5 is uniform (100,000 rolls)", () => {
    const counts = sample(5, 100_000);
    expect(counts).toHaveLength(5);
    expect(counts.every((c) => c > 0)).toBe(true);
    expect(chiSquare(counts)).toBeLessThan(38); // df = 4
  });

  it("uses rejection sampling: a 32-bit value in the biased tail is drawn again", () => {
    const values = [0xffffffff, 7]; // 0xffffffff >= 2^32 - (2^32 % 6) -> rejected; 7 -> 1 + 7 % 6 = 2
    const fake = (buf: Uint32Array) => {
      buf[0] = values.shift()!;
      return buf;
    };
    const spy = vi.spyOn(globalThis.crypto, "getRandomValues").mockImplementation(fake as typeof globalThis.crypto.getRandomValues);
    expect(cryptoDice.next(6)).toBe(2);
    expect(spy).toHaveBeenCalledTimes(2);
  });

  it("rejects bad bounds", () => {
    for (const bad of [0, 7, 2.5, Number.NaN]) expect(() => cryptoDice.next(bad)).toThrow(/bad dice max/);
    expect(() => secureRandomInt(3, 2)).toThrow();
    expect(secureRandomInt(4, 4)).toBe(4);
  });

  it("scripted and seeded sources honour the bound too", () => {
    expect(() => scriptedDice([6]).next(5)).toThrow(/max 5/);
    expect(scriptedDice([5]).next(5)).toBe(5);
    const d = seededDice(42);
    for (let i = 0; i < 2000; i++) expect(d.next(5)).toBeLessThanOrEqual(5);
  });
});

describe("MatchSession draws dice with the rule's bound", () => {
  it("asks the dice source for 1..5 right after two sixes", () => {
    const asked: number[] = [];
    const queue = [6, 6, 5];
    const spyDice: DiceSource = { next: (max = 6) => { asked.push(max); return queue.shift()!; } };
    const s = createGame({ players: 2 });
    s.pawns.red = [5, -1, -1, -1] as PawnSteps;
    const m = new MatchSession(s, E, spyDice);
    const turn = () => m.state.turn.turn_id;
    expect(m.submit("a", { type: "roll", seat: 0, turn_id: turn() }).ok).toBe(true);
    expect(m.submit("b", { type: "move", seat: 0, turn_id: turn(), pawn: 0 }).ok).toBe(true);
    expect(m.submit("c", { type: "roll", seat: 0, turn_id: turn() }).ok).toBe(true);
    expect(m.submit("d", { type: "move", seat: 0, turn_id: turn(), pawn: 0 }).ok).toBe(true);
    expect(maxDiceValue(m.state)).toBe(5);
    expect(m.submit("e", { type: "roll", seat: 0, turn_id: turn() }).ok).toBe(true);
    expect(asked).toEqual([6, 6, 5]);
  });

  it("with the real secure source a run of three 6s never happens (2,000 server-style games' worth of turns)", () => {
    let thirdRolls = 0;
    for (let g = 0; g < 2000; g++) {
      const s = createGame({ players: 2 });
      s.pawns.red = [5, -1, -1, -1] as PawnSteps;
      s.turn.sixes = 2; // the moment of the limited roll
      const m = new MatchSession(s, E, cryptoDice);
      const r = m.submit("x", { type: "roll", seat: 0, turn_id: s.turn.turn_id });
      expect(r.ok).toBe(true);
      const rolled = r.events.find((e) => e.type === "dice_rolled") as { value: number };
      expect(rolled.value).toBeLessThanOrEqual(5);
      thirdRolls++;
    }
    expect(thirdRolls).toBe(2000);
  });
});

describe("Cloudflare Workers compatibility", () => {
  it("engine sources import no Node-only module (node:*, fs, crypto, path, ...)", () => {
    const dir = resolve(__dirname, "../src");
    for (const file of readdirSync(dir).filter((f) => f.endsWith(".ts"))) {
      const src = readFileSync(resolve(dir, file), "utf8");
      const imports = [...src.matchAll(/from\s+["']([^"']+)["']/g)].map((m) => m[1]!);
      for (const spec of imports) {
        expect(spec.startsWith("."), `${file} imports ${spec}`).toBe(true);
      }
    }
  });
});
