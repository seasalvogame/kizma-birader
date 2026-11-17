// Bot priorities (GAME_RULES §10.4) and determinism.

import { describe, expect, it } from "vitest";
import { chooseBotMove, inDanger } from "../src/index.js";
import { E, game, roll } from "./helpers.js";

const pick = (pawns: Parameters<typeof game>[1], dice: number) => {
  const s = roll(game({}, pawns), dice).state;
  return chooseBotMove(s, E.board);
};

describe("bot", () => {
  it("finishes before anything else", () => {
    // pawn 0 can finish (53 + 3); pawn 1 could capture (17 + 3 = track 20, green step 7): finishing wins
    expect(pick({ red: [53, 17, -1, -1], green: [7, -1, -1, -1] }, 3).pawn).toBe(0);
  });

  it("captures before entering or advancing", () => {
    expect(pick({ red: [5, 16, -1, -1], green: [7, -1, -1, -1] }, 4).pawn).toBe(1);
  });

  it("enters a pawn with a 6 when it cannot finish or capture", () => {
    expect(pick({ red: [5, -1, -1, -1] }, 6).pawn).toBe(1);
  });

  it("escapes a threatened pawn to a safe cell", () => {
    // red pawn 1 at step 19 (track 19) threatened by green step 3 (track 16, distance 3);
    // with a 2 it reaches step 21 = star. Pawn 0 at step 2 is the rearmost.
    const s = game({}, { red: [2, 19, -1, -1], green: [3, -1, -1, -1] });
    expect(inDanger(s, E.board, 0, 19)).toBe(true);
    expect(inDanger(s, E.board, 0, 2)).toBe(false);
    expect(pick({ red: [2, 19, -1, -1], green: [3, -1, -1, -1] }, 2).pawn).toBe(1);
  });

  it("otherwise advances the rearmost pawn on the board", () => {
    expect(pick({ red: [30, 4, 12, -1] }, 3).pawn).toBe(1);
  });

  it("an opponent that turns into its corridor first is no threat", () => {
    // blue step 49 = track 36; red at track 38 = red step 38: distance 2 but blue would pass step 50
    const s = game({}, { red: [38, -1, -1, -1], blue: [49, -1, -1, -1] });
    expect(inDanger(s, E.board, 0, 38)).toBe(false);
  });

  it("is deterministic", () => {
    const pawns = { red: [5, 16, 30, -1], green: [20, 7, -1, -1], yellow: [3, -1, -1, -1] };
    const a = pick(pawns, 5);
    for (let i = 0; i < 5; i++) expect(pick(pawns, 5)).toEqual(a);
  });
});
