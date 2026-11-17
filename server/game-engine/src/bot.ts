// Bot / autopilot move choice (GAME_RULES §10.4). Deterministic: the same
// state always gives the same move, so the GDScript port can match it.
// Priority: finish > capture > enter > escape danger to a safe cell >
// advance the rearmost pawn on the board > first legal move.

import { BoardGeometry, Color } from "./board.js";
import { GameState, LegalMove } from "./state.js";

/** True when an opponent pawn can land on this pawn's cell with one roll (1..6). */
export function inDanger(s: GameState, board: BoardGeometry, seat: number, step: number): boolean {
  const color = s.players[seat]!.color;
  const target = board.trackIndex(color, step);
  if (target < 0 || board.isSafeTrack(target)) return false;
  for (const p of s.players) {
    if (p.seat === seat || p.status !== "active") continue;
    for (const st of s.pawns[p.color]!) {
      const from = board.trackIndex(p.color, st);
      if (from < 0) continue;
      const distance = (((target - from) % board.trackLength) + board.trackLength) % board.trackLength;
      // The opponent must reach it before turning into its own corridor.
      if (distance >= 1 && distance <= 6 && st + distance <= board.lastTrackStep) return true;
    }
  }
  return false;
}

function isSafeStep(board: BoardGeometry, color: Color, step: number): boolean {
  if (step > board.lastTrackStep) return true; // corridor and goal
  return board.isSafeTrack(board.trackIndex(color, step));
}

export function chooseBotMove(s: GameState, board: BoardGeometry): LegalMove {
  const moves = s.legal;
  if (moves.length === 0) throw new Error("bot asked to move without legal moves");
  const seat = s.turn.seat;
  const color = s.players[seat]!.color;
  const finish = moves.find((m) => m.finishes);
  if (finish) return finish;
  const capture = moves.find((m) => m.captures.length > 0);
  if (capture) return capture;
  const enter = moves.find((m) => m.from < 0);
  if (enter) return enter;
  const escape = moves.find((m) => m.from >= 0 && inDanger(s, board, seat, m.from) && isSafeStep(board, color, m.to));
  if (escape) return escape;
  let rear: LegalMove | undefined;
  for (const m of moves) {
    if (m.from >= 0 && (rear === undefined || m.from < rear.from)) rear = m;
  }
  return rear ?? moves[0]!;
}
