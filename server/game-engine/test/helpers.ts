import { expect } from "vitest";
import { Color, createGame, GameEngine, GameState, NewGameOptions, PawnSteps } from "../src/index.js";
import { GameEvent } from "../src/events.js";

export const E = new GameEngine();

/** New game with some pawns placed. */
export function game(options: NewGameOptions = {}, pawns: Partial<Record<Color, number[]>> = {}): GameState {
  const s = createGame(options);
  for (const [c, steps] of Object.entries(pawns)) s.pawns[c as Color] = [...steps] as PawnSteps;
  return s;
}

export function roll(s: GameState, value: number): { state: GameState; events: GameEvent[] } {
  const r = E.apply(s, { type: "roll", seat: s.turn.seat, turn_id: s.turn.turn_id }, value);
  if (!r.ok) throw new Error(`roll ${value} failed: ${r.error}`);
  return r;
}

export function move(s: GameState, pawn: number): { state: GameState; events: GameEvent[] } {
  const r = E.apply(s, { type: "move", seat: s.turn.seat, turn_id: s.turn.turn_id, pawn });
  if (!r.ok) throw new Error(`move ${pawn} failed: ${r.error}`);
  return r;
}

export const types = (events: GameEvent[]) => events.map((e) => e.type);

export function expectNoChange(before: GameState, after: GameState): void {
  expect(after).toBe(before);
}
