// GameEngine — pure state transition: (state, action, dice?) -> new state +
// events, or an error with the state untouched. It never reads a clock or a
// random source; timers and dice belong to the caller (server / client).

import { BoardGeometry, defaultBoard } from "./board.js";
import { chooseBotMove } from "./bot.js";
import { GameEvent } from "./events.js";
import { legalMoves, pathOf } from "./moves.js";
import { cloneState, GameState, LegalMove } from "./state.js";
import { checkPlayerFinished, finishGame, isGameOver, passTurn, startBonusRoll } from "./turn.js";

export type Action =
  | { type: "roll"; seat: number; turn_id: number }
  | { type: "move"; seat: number; turn_id: number; pawn: number }
  /** The turn timer ran out (server clock): auto roll and/or auto move. */
  | { type: "timeout"; seat: number; turn_id: number }
  /** Confirmed leave (GAME_RULES §11.5). */
  | { type: "leave"; seat: number };

export type ErrorCode =
  | "GAME_OVER" | "UNKNOWN_SEAT" | "NOT_ACTIVE" | "NOT_YOUR_TURN" | "STALE_TURN"
  | "WRONG_PHASE" | "INVALID_DICE" | "DICE_REQUIRED" | "ILLEGAL_MOVE";

export type ApplyResult =
  | { ok: true; state: GameState; events: GameEvent[] }
  | { ok: false; error: ErrorCode; state: GameState };

/**
 * Highest dice value allowed for the next roll (GAME_RULES §6.2). With
 * third_six_action "exclude_six", once a player has rolled
 * max_consecutive_sixes - 1 sixes in a row the next roll is drawn from 1..5,
 * so a run of three 6s is impossible. The server's dice source must use this
 * bound; the engine also rejects a larger value (INVALID_DICE).
 */
export function maxDiceValue(state: GameState): number {
  const r = state.ruleset;
  return r.third_six_action === "exclude_six" && state.turn.sixes >= r.max_consecutive_sixes - 1 ? 5 : 6;
}

export class GameEngine {
  constructor(readonly board: BoardGeometry = defaultBoard) {}

  /** Applies an action. `dice` is required for a roll, and for a timeout in the roll phase. */
  apply(state: GameState, action: Action, dice?: number): ApplyResult {
    const fail = (error: ErrorCode): ApplyResult => ({ ok: false, error, state });
    if (state.turn.phase === "game_over") return fail("GAME_OVER");
    const player = state.players[action.seat];
    if (!player) return fail("UNKNOWN_SEAT");
    if (player.status !== "active") return fail("NOT_ACTIVE");

    if (action.type === "leave") {
      const s = cloneState(state);
      const events: GameEvent[] = [];
      this.leave(s, action.seat, events);
      s.version++;
      return { ok: true, state: s, events };
    }

    if (action.seat !== state.turn.seat) return fail("NOT_YOUR_TURN");
    if (action.turn_id !== state.turn.turn_id) return fail("STALE_TURN");
    const needsDice = action.type === "roll" || (action.type === "timeout" && state.turn.phase === "roll");
    if (needsDice) {
      if (dice === undefined) return fail("DICE_REQUIRED");
      if (!Number.isInteger(dice) || dice < 1 || dice > maxDiceValue(state)) return fail("INVALID_DICE");
    }

    const s = cloneState(state);
    const events: GameEvent[] = [];
    if (action.type === "roll") {
      if (s.turn.phase !== "roll") return fail("WRONG_PHASE");
      this.playerActed(s, action.seat, events);
      this.roll(s, dice!, false, events);
    } else if (action.type === "move") {
      if (s.turn.phase !== "move") return fail("WRONG_PHASE");
      const move = s.legal.find((m) => m.pawn === action.pawn);
      if (!move) return fail("ILLEGAL_MOVE");
      this.playerActed(s, action.seat, events);
      this.move(s, move, false, events);
    } else {
      this.timedOut(s, action.seat, events);
      if (s.turn.phase === "roll") this.roll(s, dice!, true, events);
      if (s.turn.phase === "move" && s.turn.seat === action.seat) this.move(s, chooseBotMove(s, this.board), true, events);
    }
    s.version++;
    return { ok: true, state: s, events };
  }

  private playerActed(s: GameState, seat: number, events: GameEvent[]): void {
    const p = s.players[seat]!;
    p.timeouts = 0;
    if (p.autopilot) {
      p.autopilot = false;
      events.push({ type: "autopilot_changed", seat, on: false });
    }
  }

  private timedOut(s: GameState, seat: number, events: GameEvent[]): void {
    const p = s.players[seat]!;
    p.timeouts++;
    if (!p.autopilot && p.kind === "human" && p.timeouts >= s.ruleset.afk_timeouts_to_autopilot) {
      p.autopilot = true;
      events.push({ type: "autopilot_changed", seat, on: true });
    }
  }

  private roll(s: GameState, value: number, auto: boolean, events: GameEvent[]): void {
    const seat = s.turn.seat;
    events.push({ type: "dice_rolled", seat, value, auto });
    s.turn.sixes = value === 6 ? s.turn.sixes + 1 : 0;
    if (value === 6 && s.ruleset.third_six_action === "forfeit_turn" && s.turn.sixes >= s.ruleset.max_consecutive_sixes) {
      events.push({ type: "turn_forfeited", seat, reason: "three_sixes" });
      passTurn(s, events);
      return;
    }
    const moves = legalMoves(s, this.board, seat, value);
    if (moves.length === 0) {
      events.push({ type: "no_moves", seat });
      if (value === 6 && s.ruleset.bonus_roll_on_six) startBonusRoll(s, "six", events);
      else passTurn(s, events);
      return;
    }
    s.turn.phase = "move";
    s.turn.dice = value;
    s.legal = moves;
  }

  private move(s: GameState, m: LegalMove, auto: boolean, events: GameEvent[]): void {
    const seat = s.turn.seat;
    const color = s.players[seat]!.color;
    const dice = s.turn.dice;
    s.pawns[color]![m.pawn] = m.to;
    events.push({ type: "pawn_moved", seat, color, pawn: m.pawn, from: m.from, to: m.to, path: pathOf(m.from, m.to), auto });
    for (const c of m.captures) {
      s.pawns[c.color]![c.pawn] = -1;
      const bySeat = s.players.find((p) => p.color === c.color)!.seat;
      events.push({ type: "pawn_captured", seat: bySeat, by_seat: seat, color: c.color, pawn: c.pawn, from: c.from });
    }
    if (m.finishes) events.push({ type: "pawn_finished", seat, color, pawn: m.pawn });
    s.legal = [];
    s.turn.dice = 0;
    const playerDone = checkPlayerFinished(s, this.board, seat, events);
    if (isGameOver(s)) {
      finishGame(s, events);
      return;
    }
    if (playerDone) {
      passTurn(s, events);
      return;
    }
    const r = s.ruleset;
    const reason = dice === 6 && r.bonus_roll_on_six ? "six"
      : m.captures.length > 0 && r.bonus_roll_on_capture ? "capture"
      : m.finishes && r.bonus_roll_on_finish ? "finish" : null;
    if (reason) startBonusRoll(s, reason, events);
    else passTurn(s, events);
  }

  private leave(s: GameState, seat: number, events: GameEvent[]): void {
    const p = s.players[seat]!;
    p.status = "left";
    s.pawns[p.color] = [-1, -1, -1, -1];
    s.left_order.push(seat);
    events.push({ type: "player_left", seat });
    if (isGameOver(s)) {
      finishGame(s, events);
      return;
    }
    if (s.turn.seat === seat) {
      passTurn(s, events);
    } else if (s.turn.phase === "move") {
      // The leaver's pawns are gone: captures in the current options change.
      s.legal = legalMoves(s, this.board, s.turn.seat, s.turn.dice);
    }
  }
}
