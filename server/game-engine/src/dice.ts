// DiceManager — where dice values come from. The engine never rolls by
// itself: the caller passes the value in, so production uses the server's
// cryptographic RNG (GAME_RULES §3) and tests inject fixed or seeded values.
//
// Every source takes the upper bound of the next roll (6, or 5 after two
// sixes in a row; see maxDiceValue in engine.ts).
//
// Platform: only the Web Crypto API (globalThis.crypto.getRandomValues) is
// used, which exists in Cloudflare Workers and in Node >= 19, so this module
// has no Node-specific imports.

export interface DiceSource {
  /** A value in 1..max (max is 5 or 6). */
  next(max?: number): number;
}

function checkMax(max: number): void {
  if (!Number.isInteger(max) || max < 1 || max > 6) throw new Error(`bad dice max ${max}`);
}

const UINT32_RANGE = 0x1_0000_0000;

/**
 * Cryptographically secure integer in [min, max] (inclusive). Rejection
 * sampling over 32-bit values removes modulo bias: draws at or above the
 * largest multiple of the range size are discarded and drawn again.
 */
export function secureRandomInt(min: number, max: number): number {
  if (!Number.isInteger(min) || !Number.isInteger(max) || max < min) throw new Error("bad range");
  const size = max - min + 1;
  if (size > UINT32_RANGE) throw new Error("range too large");
  const limit = UINT32_RANGE - (UINT32_RANGE % size);
  const buf = new Uint32Array(1);
  for (;;) {
    crypto.getRandomValues(buf);
    const x = buf[0]!;
    if (x < limit) return min + (x % size);
  }
}

/** Production (server): Web Crypto CSPRNG, uniform over 1..max, no modulo bias. */
export const cryptoDice: DiceSource = {
  next(max = 6) {
    checkMax(max);
    return secureRandomInt(1, max);
  },
};

/** Tests: a fixed sequence; throws when it runs out or a value exceeds the bound (a test bug). */
export function scriptedDice(values: number[]): DiceSource & { remaining(): number } {
  let i = 0;
  return {
    next(max = 6) {
      checkMax(max);
      if (i >= values.length) throw new Error("scripted dice ran out");
      const v = values[i++]!;
      if (!Number.isInteger(v) || v < 1 || v > max) throw new Error(`bad scripted dice ${v} (max ${max})`);
      return v;
    },
    remaining: () => values.length - i,
  };
}

/** Simulations and random tests: mulberry32, reproducible from a seed. */
export function seededRandom(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function seededDice(seed: number): DiceSource {
  const rnd = seededRandom(seed);
  return {
    next(max = 6) {
      checkMax(max);
      return 1 + Math.floor(rnd() * max);
    },
  };
}
