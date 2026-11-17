// Rules (GAME_RULES.md) — every scenario of the Phase 2 brief plus edge cases.
// Seats in a 4-player game: 0 red, 1 green, 2 yellow, 3 blue.
// Track index of a step: (start + step) % 52 with starts red 0, green 13,
// yellow 26, blue 39; safe cells 0, 8, 13, 21, 26, 34, 39, 47.

import { describe, expect, it } from "vitest";
import { createGame, isSingleOption, makeRuleset, maxDiceValue } from "../src/index.js";
import { E, game, move, roll, types } from "./helpers.js";

describe("entering the board", () => {
  it("1. a pawn leaves the yard with a 6, onto the start cell, and the player rolls again", () => {
    const s = game();
    const r = roll(s, 6);
    expect(r.state.turn.phase).toBe("move");
    expect(r.state.legal.map((m) => [m.pawn, m.from, m.to])).toEqual([[0, -1, 0], [1, -1, 0], [2, -1, 0], [3, -1, 0]]);
    expect(isSingleOption(r.state.legal)).toBe(true);
    const m = move(r.state, 2);
    expect(m.state.pawns.red).toEqual([-1, -1, 0, -1]);
    expect(types(m.events)).toEqual(["pawn_moved", "bonus_roll"]);
    expect(m.state.turn.seat).toBe(0);
    expect(m.state.turn.phase).toBe("roll");
  });

  it("2. no pawn leaves the yard without a 6", () => {
    for (const v of [1, 2, 3, 4, 5]) {
      const r = roll(game(), v);
      expect(types(r.events)).toEqual(["dice_rolled", "no_moves", "turn_changed"]);
      expect(r.state.turn.seat).toBe(1);
      expect(r.state.pawns.red).toEqual([-1, -1, -1, -1]);
    }
  });

  it("14. a player without legal moves passes the turn (a 6 without moves still gives a bonus roll)", () => {
    const s = game({}, { red: [56, 56, 56, 53] });
    const r = roll(s, 5);
    expect(types(r.events)).toEqual(["dice_rolled", "no_moves", "turn_changed"]);
    const six = roll(s, 6);
    expect(types(six.events)).toEqual(["dice_rolled", "no_moves", "bonus_roll"]);
    expect(six.state.turn.seat).toBe(0);
  });
});

describe("moving", () => {
  it("3. a pawn moves exactly the dice value, cell by cell", () => {
    const s = game({}, { red: [5, -1, -1, -1] });
    const r = move(roll(s, 4).state, 0);
    expect(r.state.pawns.red![0]).toBe(9);
    const moved = r.events.find((e) => e.type === "pawn_moved");
    expect(moved).toMatchObject({ from: 5, to: 9, path: [6, 7, 8, 9] });
  });

  it("4. after a move without bonus the turn goes clockwise to the next player", () => {
    const s = game({}, { red: [5, -1, -1, -1] });
    const r = move(roll(s, 4).state, 0);
    expect(r.events.at(-1)).toMatchObject({ type: "turn_changed", seat: 1 });
    expect(r.state.turn).toMatchObject({ seat: 1, phase: "roll", sixes: 0, dice: 0 });
  });

  it("5. a 6 gives a bonus roll with a new turn id", () => {
    const s = game({}, { red: [5, -1, -1, -1] });
    const rolled = roll(s, 6);
    const r = move(rolled.state, 0);
    expect(r.events.at(-1)).toMatchObject({ type: "bonus_roll", seat: 0, reason: "six" });
    expect(r.state.turn.turn_id).toBe(rolled.state.turn.turn_id + 1);
    expect(r.state.turn.sixes).toBe(1);
  });

  it("6. after two 6s in a row the third roll can only be 1..5 (GAME_RULES §6.2)", () => {
    let s = game({}, { red: [5, -1, -1, -1] });
    s = move(roll(s, 6).state, 0).state;
    s = move(roll(s, 6).state, 0).state;
    expect(s.pawns.red![0]).toBe(17);
    expect(s.turn.sixes).toBe(2);
    expect(maxDiceValue(s)).toBe(5);
    // a 6 is rejected for a roll and for a roll-phase timeout; nothing changes
    const six = E.apply(s, { type: "roll", seat: 0, turn_id: s.turn.turn_id }, 6);
    expect(six).toMatchObject({ ok: false, error: "INVALID_DICE" });
    expect(six.state).toBe(s);
    expect(E.apply(s, { type: "timeout", seat: 0, turn_id: s.turn.turn_id }, 6)).toMatchObject({ ok: false, error: "INVALID_DICE" });
    // 1..5 play normally: no six bonus, the turn passes, the counter resets
    for (const v of [1, 2, 3, 4, 5]) {
      const r = move(roll(s, v).state, 0);
      expect(r.state.pawns.red![0]).toBe(17 + v);
      expect(r.state.turn).toMatchObject({ seat: 1, sixes: 0, phase: "roll" });
      expect(types(r.events)).not.toContain("turn_forfeited");
    }
  });

  it("6b. the limit applies only right after two sixes", () => {
    const s = game({}, { red: [5, -1, -1, -1] });
    expect(maxDiceValue(s)).toBe(6);
    const once = move(roll(s, 6).state, 0).state;
    expect(maxDiceValue(once)).toBe(6);
    expect(maxDiceValue(move(roll(once, 6).state, 0).state)).toBe(5);
  });

  it("6c. a capture with the limited roll gives a bonus roll that may be a 6 again", () => {
    let s = game({}, { red: [5, -1, -1, -1], green: [7, -1, -1, -1] });
    s = move(roll(s, 6).state, 0).state;
    s = move(roll(s, 6).state, 0).state;
    const r = move(roll(s, 3).state, 0); // red 17 -> 20 = green step 7
    expect(r.state.pawns.green![0]).toBe(-1);
    expect(r.events.at(-1)).toMatchObject({ type: "bonus_roll", reason: "capture" });
    expect(r.state.turn.sixes).toBe(0);
    expect(maxDiceValue(r.state)).toBe(6);
    expect(roll(r.state, 6).state.turn.phase).toBe("move");
  });

  it("6d. alternative ruleset forfeit_turn: a third 6 ends the turn without a move", () => {
    let s = game({ ruleset: { third_six_action: "forfeit_turn" } }, { red: [5, -1, -1, -1] });
    s = move(roll(s, 6).state, 0).state;
    s = move(roll(s, 6).state, 0).state;
    expect(maxDiceValue(s)).toBe(6);
    const r = roll(s, 6);
    expect(types(r.events)).toEqual(["dice_rolled", "turn_forfeited", "turn_changed"]);
    expect(r.state.pawns.red![0]).toBe(17);
    expect(r.state.turn).toMatchObject({ seat: 1, sixes: 0 });
  });

  it("classic_v1 uses exclude_six; unknown third_six_action values are rejected", () => {
    expect(makeRuleset().third_six_action).toBe("exclude_six");
    expect(() => makeRuleset({ third_six_action: "reroll" as never })).toThrow(/not implemented/);
  });

  it("a non-6 between sixes resets the six counter", () => {
    let s = game({}, { red: [5, -1, -1, -1], green: [-1, -1, -1, -1] });
    s = move(roll(s, 6).state, 0).state; // sixes 1
    expect(s.turn.sixes).toBe(1);
    // capture bonus with a 3 resets the counter
    s.pawns.green = [12, -1, -1, -1]; // green step 12 = track 25
    s.pawns.red = [22, -1, -1, -1]; // red 22 + 3 = 25
    const r = move(roll(s, 3).state, 0);
    expect(r.events.at(-1)).toMatchObject({ type: "bonus_roll", reason: "capture" });
    expect(r.state.turn.sixes).toBe(0);
  });

  it("9. several pawns may share a cell (own stack, and a start cell with an opponent)", () => {
    const s = game({}, { red: [7, 10, -1, -1] });
    const r = move(roll(s, 3).state, 0);
    expect(r.state.pawns.red).toEqual([10, 10, -1, -1]);
    // green pawn standing on red's start (track 0 = green step 39)
    const t = game({}, { green: [39, -1, -1, -1] });
    const e = move(roll(t, 6).state, 0);
    expect(e.state.pawns.red![0]).toBe(0);
    expect(e.state.pawns.green![0]).toBe(39);
    expect(e.events.some((ev) => ev.type === "pawn_captured")).toBe(false);
  });

  it("passing over opponent pawns captures nothing", () => {
    // green step 1 = track 14; red 10 -> 15 passes over it
    const s = game({}, { red: [10, -1, -1, -1], green: [1, -1, -1, -1] });
    const r = move(roll(s, 5).state, 0);
    expect(r.state.pawns.green![0]).toBe(1);
  });
});

describe("captures and safe cells", () => {
  it("7. a pawn on a star cannot be captured", () => {
    // green step 8 = track 21 (star); red 17 + 4 = 21
    const s = game({}, { red: [17, -1, -1, -1], green: [8, -1, -1, -1] });
    const rolled = roll(s, 4);
    expect(rolled.state.legal[0]!.captures).toEqual([]);
    const r = move(rolled.state, 0);
    expect(r.state.pawns.green![0]).toBe(8);
    expect(r.state.pawns.red![0]).toBe(21);
  });

  it("start cells are safe too", () => {
    // yellow start = track 26; green step 13 = track 26; red 22 + 4 = 26
    const s = game({}, { red: [22, -1, -1, -1], green: [13, -1, -1, -1] });
    const r = move(roll(s, 4).state, 0);
    expect(r.state.pawns.green![0]).toBe(13);
  });

  it("8. landing on an opponent on a normal cell sends it home and gives a bonus roll", () => {
    // green step 7 = track 20; red 16 + 4 = 20
    const s = game({}, { red: [16, -1, -1, -1], green: [7, -1, -1, -1] });
    const rolled = roll(s, 4);
    expect(rolled.state.legal[0]!.captures).toEqual([{ color: "green", pawn: 0, from: 7 }]);
    const r = move(rolled.state, 0);
    expect(r.state.pawns.green![0]).toBe(-1);
    expect(types(r.events)).toEqual(["pawn_moved", "pawn_captured", "bonus_roll"]);
    expect(r.events[1]).toMatchObject({ seat: 1, by_seat: 0, color: "green", pawn: 0 });
  });

  it("an opponent stack on a normal cell is captured completely (capture_stack all)", () => {
    const s = game({}, { red: [16, -1, -1, -1], green: [7, 7, -1, -1], yellow: [46, -1, -1, -1] });
    // yellow step 46 = track (26+46)%52 = 20 as well
    const r = move(roll(s, 4).state, 0);
    expect(r.state.pawns.green).toEqual([-1, -1, -1, -1]);
    expect(r.state.pawns.yellow![0]).toBe(-1);
    expect(r.events.filter((e) => e.type === "pawn_captured")).toHaveLength(3);
  });
});

describe("corridor and finishing", () => {
  it("10. step 50 leads into the own corridor, never around the board again", () => {
    const s = game({}, { red: [48, -1, -1, -1] });
    const r = move(roll(s, 5).state, 0);
    expect(r.state.pawns.red![0]).toBe(53);
    const moved = r.events.find((e) => e.type === "pawn_moved");
    expect(moved).toMatchObject({ path: [49, 50, 51, 52, 53] });
  });

  it("pawns in the corridor cannot be captured", () => {
    // blue corridor; red cannot land there at all, so check a pawn of red in its corridor stays put
    const s = game({}, { red: [52, -1, -1, -1], blue: [11, -1, -1, -1] });
    // blue step 11 = track 50; red step 52 is corridor (no track index)
    expect(E.board.trackIndex("red", 52)).toBe(-1);
    const r = roll(s, 1);
    expect(r.state.legal[0]).toMatchObject({ from: 52, to: 53, captures: [] });
  });

  it("11. finishing needs the exact number", () => {
    const s = game({}, { red: [53, -1, -1, -1] });
    expect(roll(s, 4).events.map((e) => e.type)).toContain("no_moves");
    const r = move(roll(s, 3).state, 0);
    expect(r.state.pawns.red![0]).toBe(56);
    expect(types(r.events)).toEqual(["pawn_moved", "pawn_finished", "bonus_roll"]);
    expect(r.events.at(-1)).toMatchObject({ reason: "finish" });
  });

  it("12. two players: the first with all four pawns home wins", () => {
    const s = game({ players: 2 }, { red: [56, 56, 56, 53] });
    expect(s.players.map((p) => p.color)).toEqual(["red", "yellow"]);
    const r = move(roll(s, 3).state, 3);
    expect(types(r.events)).toEqual(["pawn_moved", "pawn_finished", "player_finished", "game_over"]);
    expect(r.state.turn.phase).toBe("game_over");
    expect(r.state.ranks).toEqual([0, 1]);
    expect(r.state.players.map((p) => p.rank)).toEqual([1, 2]);
    const after = E.apply(r.state, { type: "roll", seat: 1, turn_id: r.state.turn.turn_id }, 4);
    expect(after.ok).toBe(false);
  });

  it("13. four players: the game goes on until three are ranked", () => {
    let s = game({}, { red: [56, 56, 56, 55], green: [56, 56, 56, 55], yellow: [56, 56, 56, 55], blue: [10, -1, -1, -1] });
    let r = move(roll(s, 1).state, 3); // red done
    expect(types(r.events)).toEqual(["pawn_moved", "pawn_finished", "player_finished", "turn_changed"]);
    expect(r.state.turn.seat).toBe(1);
    r = move(roll(r.state, 1).state, 3); // green done
    expect(r.state.turn.seat).toBe(2);
    r = move(roll(r.state, 1).state, 3); // yellow done -> blue is 4th
    expect(r.events.at(-1)).toMatchObject({ type: "game_over", ranks: [0, 1, 2, 3] });
    expect(r.state.players.map((p) => p.rank)).toEqual([1, 2, 3, 4]);
    s = r.state;
    expect(s.players[3]!.status).toBe("active");
  });

  it("finished players are skipped in the turn order", () => {
    const s = game({}, { red: [56, 56, 56, 55], green: [5, -1, -1, -1] });
    const r = move(roll(s, 1).state, 3);
    expect(r.state.turn.seat).toBe(1);
    const g = move(roll(r.state, 2).state, 0);
    expect(g.state.turn.seat).toBe(2);
    const y = roll(g.state, 2); // yellow no moves
    const b = roll(y.state, 2); // blue no moves -> back to green, red skipped
    expect(b.state.turn.seat).toBe(1);
  });

  it("first_finisher mode ends the game at the first finisher and ranks the rest by progress", () => {
    const s = game({ ruleset: { four_player_end: "first_finisher" } }, { red: [56, 56, 56, 55], green: [10, 3, -1, -1], yellow: [40, -1, -1, -1], blue: [10, 3, -1, -1] });
    const r = move(roll(s, 1).state, 3);
    expect(r.state.ranks).toEqual([0, 2, 1, 3]);
  });
});

describe("invalid actions", () => {
  it("15. an illegal pawn or a move in the wrong phase is rejected without changing the state", () => {
    const s = game({}, { red: [5, -1, -1, -1] });
    const rolled = roll(s, 3).state;
    const bad = E.apply(rolled, { type: "move", seat: 0, turn_id: rolled.turn.turn_id, pawn: 1 });
    expect(bad).toMatchObject({ ok: false, error: "ILLEGAL_MOVE" });
    expect(bad.state).toBe(rolled);
    const wrong = E.apply(s, { type: "move", seat: 0, turn_id: s.turn.turn_id, pawn: 0 });
    expect(wrong).toMatchObject({ ok: false, error: "WRONG_PHASE" });
    const twice = E.apply(rolled, { type: "roll", seat: 0, turn_id: rolled.turn.turn_id }, 4);
    expect(twice).toMatchObject({ ok: false, error: "WRONG_PHASE" });
    expect(E.apply(s, { type: "move", seat: 0, turn_id: s.turn.turn_id, pawn: 7 })).toMatchObject({ ok: false });
  });

  it("17. a player whose turn it is not cannot roll or move", () => {
    const s = game();
    expect(E.apply(s, { type: "roll", seat: 2, turn_id: s.turn.turn_id }, 6)).toMatchObject({ ok: false, error: "NOT_YOUR_TURN" });
    expect(E.apply(s, { type: "roll", seat: 9, turn_id: s.turn.turn_id }, 6)).toMatchObject({ ok: false, error: "UNKNOWN_SEAT" });
  });

  it("18. a stale turn id is rejected (an old request arriving late)", () => {
    const s = game({}, { red: [5, -1, -1, -1] });
    const r = move(roll(s, 6).state, 0).state; // bonus roll: new turn id
    expect(E.apply(r, { type: "roll", seat: 0, turn_id: s.turn.turn_id }, 4)).toMatchObject({ ok: false, error: "STALE_TURN" });
  });

  it("rejects missing or invalid dice", () => {
    const s = game();
    const a = { type: "roll" as const, seat: 0, turn_id: s.turn.turn_id };
    expect(E.apply(s, a)).toMatchObject({ ok: false, error: "DICE_REQUIRED" });
    for (const v of [0, 7, 2.5, -1]) expect(E.apply(s, a, v)).toMatchObject({ ok: false, error: "INVALID_DICE" });
  });

  it("does not mutate the input state", () => {
    const s = game({}, { red: [5, -1, -1, -1] });
    const copy = structuredClone(s);
    move(roll(s, 6).state, 0);
    expect(s).toEqual(copy);
  });
});

describe("timeouts, autopilot and leaving", () => {
  it("a roll timeout rolls and plays the bot move automatically", () => {
    const s = game({}, { red: [5, -1, -1, -1] });
    const r = E.apply(s, { type: "timeout", seat: 0, turn_id: s.turn.turn_id }, 3);
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(types(r.events)).toEqual(["dice_rolled", "pawn_moved", "turn_changed"]);
    expect(r.events[0]).toMatchObject({ auto: true });
    expect(r.state.pawns.red![0]).toBe(8);
    expect(r.state.players[0]!.timeouts).toBe(1);
  });

  it("a move timeout plays the bot move", () => {
    const rolled = roll(game({}, { red: [5, 20, -1, -1] }), 2).state;
    const r = E.apply(rolled, { type: "timeout", seat: 0, turn_id: rolled.turn.turn_id });
    expect(r.ok && r.events[0]).toMatchObject({ type: "pawn_moved", auto: true, pawn: 0 });
  });

  it("three timeouts in a row switch a human to autopilot; acting switches it off", () => {
    let s = createGame({ players: 2 });
    for (let i = 0; i < 3; i++) {
      const own = E.apply(s, { type: "timeout", seat: 0, turn_id: s.turn.turn_id }, 2);
      if (!own.ok) throw new Error(own.error);
      if (i === 2) expect(own.events[0]).toMatchObject({ type: "autopilot_changed", on: true });
      s = own.state;
      s = roll(s, 2).state; // opponent
    }
    expect(s.players[0]!.autopilot).toBe(true);
    const back = roll(s, 2);
    expect(back.events[0]).toMatchObject({ type: "autopilot_changed", on: false });
    expect(back.state.players[0]!.timeouts).toBe(0);
  });

  it("a player who leaves a 4-player game is removed and ranked last", () => {
    const s = game({}, { red: [5, -1, -1, -1], green: [7, -1, -1, -1] });
    const r = E.apply(s, { type: "leave", seat: 1 });
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.state.players[1]!.status).toBe("left");
    expect(r.state.pawns.green).toEqual([-1, -1, -1, -1]);
    expect(r.state.turn.seat).toBe(0);
    // the leaver is skipped
    const next = move(roll(r.state, 1).state, 0);
    expect(next.state.turn.seat).toBe(2);
  });

  it("leaving on your own turn passes it; in a 2-player game the other player wins", () => {
    const s = game({ players: 2 });
    const r = E.apply(s, { type: "leave", seat: 0 });
    expect(r.ok && r.state.ranks).toEqual([1, 0]);
    expect(r.ok && r.state.turn.phase).toBe("game_over");
  });

  it("leaving while another player chooses a capture removes that option", () => {
    const s = game({}, { red: [16, -1, -1, -1], green: [7, -1, -1, -1] });
    const rolled = roll(s, 4).state;
    expect(rolled.legal[0]!.captures).toHaveLength(1);
    const r = E.apply(rolled, { type: "leave", seat: 1 });
    expect(r.ok && r.state.legal[0]!.captures).toEqual([]);
  });

  it("three players leaving ends a 4-player game", () => {
    let s = game();
    for (const seat of [1, 2]) {
      const r = E.apply(s, { type: "leave", seat });
      if (!r.ok) throw new Error(r.error);
      s = r.state;
    }
    const r = E.apply(s, { type: "leave", seat: 3 });
    expect(r.ok && r.state.ranks).toEqual([0, 3, 2, 1]);
  });
});

describe("ruleset", () => {
  it("rejects unknown keys and options this engine does not implement yet", () => {
    expect(() => makeRuleset({ blockade: "pair_blocks" as never })).toThrow(/not implemented/);
    expect(() => makeRuleset({ nonsense: 1 } as never)).toThrow(/unknown/);
    expect(() => makeRuleset({ enter_on: [] })).toThrow();
  });

  it("enter_on is configurable (e.g. 1 or 6)", () => {
    const s = game({ ruleset: { enter_on: [1, 6] } });
    expect(roll(s, 1).state.legal).toHaveLength(4);
  });

  it("bonus rolls on capture and finish can be switched off", () => {
    const s = game({ ruleset: { bonus_roll_on_capture: false } }, { red: [16, -1, -1, -1], green: [7, -1, -1, -1] });
    const r = move(roll(s, 4).state, 0);
    expect(r.events.at(-1)).toMatchObject({ type: "turn_changed" });
  });

  it("2-player games need facing colours in clockwise order", () => {
    expect(() => createGame({ seats: [{ color: "red" }, { color: "green" }] })).toThrow();
    expect(createGame({ seats: [{ color: "green" }, { color: "blue" }] }).players).toHaveLength(2);
  });
});
