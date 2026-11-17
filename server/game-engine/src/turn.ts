// TurnManager + WinCondition (GAME_RULES §2, §6, §9, §11).

import { BoardGeometry } from "./board.js";
import { GameEvent } from "./events.js";
import { GameState } from "./state.js";

/** Next active seat clockwise after `seat`. */
export function nextActiveSeat(s: GameState, seat: number): number {
  const n = s.players.length;
  for (let k = 1; k <= n; k++) {
    const candidate = (seat + k) % n;
    if (s.players[candidate]!.status === "active") return candidate;
  }
  return seat;
}

/** Gives the turn to the next active seat (new roll phase). */
export function passTurn(s: GameState, events: GameEvent[]): void {
  const next = nextActiveSeat(s, s.turn.seat);
  s.turn = { seat: next, phase: "roll", dice: 0, sixes: 0, turn_id: s.turn.turn_id + 1 };
  s.legal = [];
  events.push({ type: "turn_changed", seat: next, turn_id: s.turn.turn_id });
}

/** Same seat rolls again (consecutive sixes are kept). */
export function startBonusRoll(s: GameState, reason: "six" | "capture" | "finish", events: GameEvent[]): void {
  s.turn = { ...s.turn, phase: "roll", dice: 0, turn_id: s.turn.turn_id + 1 };
  s.legal = [];
  events.push({ type: "bonus_roll", seat: s.turn.seat, reason });
}

/** Marks the seat finished when all four pawns are home. */
export function checkPlayerFinished(s: GameState, board: BoardGeometry, seat: number, events: GameEvent[]): boolean {
  const p = s.players[seat]!;
  if (p.status !== "active") return false;
  if (!s.pawns[p.color]!.every((st) => st === board.goalStep)) return false;
  p.status = "finished";
  s.ranks.push(seat);
  p.rank = s.ranks.length;
  events.push({ type: "player_finished", seat, rank: p.rank });
  return true;
}

/**
 * Game over when at most one player is still active (2 players: the first to
 * finish wins; 4 players until_three_finish: the first three are ranked), or
 * after the first finisher in first_finisher mode.
 */
export function isGameOver(s: GameState): boolean {
  const active = s.players.filter((p) => p.status === "active").length;
  if (active <= 1) return true;
  return s.ruleset.four_player_end === "first_finisher" && s.ranks.length >= 1;
}

/** Ranks the rest (progress, then seat), then leavers (last leaver first), and ends the game. */
export function finishGame(s: GameState, events: GameEvent[]): void {
  const progress = (seat: number) => s.pawns[s.players[seat]!.color]!.reduce((sum, st) => sum + st + 1, 0);
  const remaining = s.players.filter((p) => p.status === "active").map((p) => p.seat);
  remaining.sort((a, b) => progress(b) - progress(a) || a - b);
  for (const seat of remaining) s.ranks.push(seat);
  for (let i = s.left_order.length - 1; i >= 0; i--) s.ranks.push(s.left_order[i]!);
  s.ranks.forEach((seat, index) => {
    s.players[seat]!.rank = index + 1;
  });
  s.turn = { ...s.turn, phase: "game_over", dice: 0 };
  s.legal = [];
  events.push({ type: "game_over", ranks: [...s.ranks] });
}
