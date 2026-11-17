// MatchSession: idempotency (16. repeated request), dice drawn only for
// accepted actions, out-of-turn requests.

import { describe, expect, it } from "vitest";
import { createGame, MatchSession, scriptedDice } from "../src/index.js";
import { E } from "./helpers.js";

describe("MatchSession", () => {
  it("16. a repeated request id is not applied twice and does not roll new dice", () => {
    const dice = scriptedDice([6, 3]);
    const m = new MatchSession(createGame({ players: 2 }), E, dice);
    const first = m.submit("req-1", { type: "roll", seat: 0, turn_id: 1 });
    expect(first.ok).toBe(true);
    const again = m.submit("req-1", { type: "roll", seat: 0, turn_id: 1 });
    expect(again.duplicate).toBe(true);
    expect(again.events).toEqual(first.events);
    expect(dice.remaining()).toBe(1);
    const mv = m.submit("req-2", { type: "move", seat: 0, turn_id: 1, pawn: 0 });
    expect(mv.ok).toBe(true);
    const mvAgain = m.submit("req-2", { type: "move", seat: 0, turn_id: 1, pawn: 0 });
    expect(mvAgain.duplicate).toBe(true);
    expect(m.state.pawns.red).toEqual([0, -1, -1, -1]);
    expect(m.state.version).toBe(2);
  });

  it("the same move with a new request id is rejected as stale, not applied again", () => {
    const m = new MatchSession(createGame({ players: 2 }), E, scriptedDice([6]));
    m.submit("a", { type: "roll", seat: 0, turn_id: 1 });
    m.submit("b", { type: "move", seat: 0, turn_id: 1, pawn: 0 });
    const replay = m.submit("c", { type: "move", seat: 0, turn_id: 1, pawn: 0 });
    expect(replay).toMatchObject({ ok: false, error: "STALE_TURN" });
    expect(m.state.pawns.red).toEqual([0, -1, -1, -1]);
  });

  it("requests out of turn or in the wrong phase do not consume dice", () => {
    const dice = scriptedDice([4]);
    const m = new MatchSession(createGame({ players: 2 }), E, dice);
    expect(m.submit("x", { type: "roll", seat: 1, turn_id: 1 })).toMatchObject({ ok: false, error: "NOT_YOUR_TURN" });
    expect(m.submit("y", { type: "roll", seat: 0, turn_id: 99 })).toMatchObject({ ok: false, error: "STALE_TURN" });
    expect(dice.remaining()).toBe(1);
  });

  it("request ids are per seat", () => {
    const m = new MatchSession(createGame({ players: 2 }), E, scriptedDice([2, 2]));
    expect(m.submit("same", { type: "roll", seat: 0, turn_id: 1 }).ok).toBe(true);
    expect(m.submit("same", { type: "roll", seat: 1, turn_id: 2 }).ok).toBe(true);
  });
});
