// The committed shared vectors must match what the engine produces now
// (regenerate with `npm run vectors` after an intentional rule change).

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { buildVectors } from "../scripts/gen-vectors.js";

const DIR = resolve(__dirname, "../../../shared/rules_test_vectors");

describe("shared rules test vectors", () => {
  const now = buildVectors();

  it("scenarios.json is up to date", () => {
    const saved = JSON.parse(readFileSync(resolve(DIR, "scenarios.json"), "utf8"));
    expect(saved).toEqual(JSON.parse(JSON.stringify(now.scenarios)));
  });

  it("traces.json is up to date", () => {
    const saved = JSON.parse(readFileSync(resolve(DIR, "traces.json"), "utf8"));
    expect(saved).toEqual(JSON.parse(JSON.stringify(now.traces)));
  });

  it("covers both player counts and every action kind", () => {
    const traces = now.traces.traces;
    expect(traces.filter((t) => t.players === 2).length).toBeGreaterThanOrEqual(30);
    expect(traces.filter((t) => t.players === 4).length).toBeGreaterThanOrEqual(30);
    const all = traces.map((t) => t.actions).join(" ");
    for (const kind of [/\br\d/, /\bm\d/, /\bt\d/, /\bt\b/]) expect(all).toMatch(kind);
  });
});
