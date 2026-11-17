// Economy preparation: config validation and payout maths (integers, never
// more than the pool, configurable rake / shares / entries).

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import fc from "fast-check";
import { describe, expect, it } from "vitest";
import { bailoutAmount, canEnter, computePayout, EconomyConfig, validateEconomyConfig } from "../src/economy.js";

const example = (): EconomyConfig => {
  const raw = JSON.parse(readFileSync(resolve(__dirname, "../../../shared/config/economy_config.example.json"), "utf8"));
  delete raw._comment;
  return raw;
};

describe("economy config", () => {
  it("the example config is valid", () => {
    expect(validateEconomyConfig(example())).toEqual([]);
  });

  it("rejects shares that do not sum to 10000, increasing shares, bad rake and bad entries", () => {
    const c = example();
    c.tiers[0]!.shares_4p = [6000, 3000, 2000, 0];
    c.tiers[1]!.shares_2p = [4000, 6000];
    c.tiers[2]!.entry_gold = 0;
    c.rake_percent = 60;
    const errors = validateEconomyConfig(c);
    expect(errors.some((e) => e.includes("sum to 10000"))).toBe(true);
    expect(errors.some((e) => e.includes("not increase"))).toBe(true);
    expect(errors.some((e) => e.includes("entry_gold"))).toBe(true);
    expect(errors.some((e) => e.includes("rake"))).toBe(true);
  });
});

describe("payouts", () => {
  it("2 players, 100 entry, 10 % rake: winner gets 180, loser 0", () => {
    expect(computePayout(example(), "lobby_100", 2)).toEqual({ pool: 200, rake: 20, paid: [180, 0], remainder: 0 });
  });

  it("4 players, 500 entry: 2000 pool, 200 rake, 1080 / 540 / 180 / 0", () => {
    expect(computePayout(example(), "lobby_500", 4)).toEqual({ pool: 2000, rake: 200, paid: [1080, 540, 180, 0], remainder: 0 });
  });

  it("never pays more than the pool, rounds down, all integers (random configs)", () => {
    fc.assert(fc.property(
      fc.integer({ min: 1, max: 1_000_000 }), fc.integer({ min: 0, max: 50 }),
      fc.array(fc.integer({ min: 0, max: 10000 }), { minLength: 3, maxLength: 3 }),
      (entry, rake, cuts) => {
        const sorted = [...cuts].sort((a, b) => a - b);
        const raw = [10000 - sorted[2]!, sorted[2]! - sorted[1]!, sorted[1]! - sorted[0]!, sorted[0]!];
        const shares = [...raw].sort((a, b) => b - a);
        const c = example();
        c.rake_percent = rake;
        c.tiers[0]!.entry_gold = entry;
        c.tiers[0]!.shares_4p = shares;
        expect(validateEconomyConfig(c)).toEqual([]);
        const p = computePayout(c, "lobby_100", 4);
        const total = p.paid.reduce((a, b) => a + b, 0);
        expect(total + p.rake + p.remainder).toBe(p.pool);
        expect(p.remainder).toBeGreaterThanOrEqual(0);
        expect(p.remainder).toBeLessThan(4);
        for (const g of p.paid) expect(Number.isInteger(g) && g >= 0).toBe(true);
      }), { numRuns: 500 });
  });

  it("entry needs enough gold (no negative balance) and the level; bailout is limited per day", () => {
    const c = example();
    expect(canEnter(c, "lobby_100", 99, 1)).toBe(false);
    expect(canEnter(c, "lobby_100", 100, 1)).toBe(true);
    expect(canEnter(c, "lobby_500", 5000, 4)).toBe(false);
    expect(canEnter(c, "unknown", 5000, 50)).toBe(false);
    expect(bailoutAmount(c, 50, 0)).toBe(200);
    expect(bailoutAmount(c, 50, 2)).toBe(0);
    expect(bailoutAmount(c, 100, 0)).toBe(0);
  });

  it("disabled tiers cannot be paid out", () => {
    const c = example();
    c.tiers[0]!.enabled = false;
    expect(() => computePayout(c, "lobby_100", 2)).toThrow();
  });
});
