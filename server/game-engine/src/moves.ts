// MoveValidator + CaptureResolver (GAME_RULES §4, §5, §7, §8).

import { BoardGeometry, Color, YARD } from "./board.js";
import { Capture, GameState, LegalMove, pawnsOf } from "./state.js";

/**
 * Opponent pawns that a pawn of `color` (seat `seat`) captures when its move
 * ends on `toStep`. Safe cells (starts + stars) and the corridor capture
 * nothing; on a normal track cell every opponent pawn there is captured
 * (capture_stack = "all"). Order: seat order, then pawn index.
 */
export function captureTargets(s: GameState, board: BoardGeometry, seat: number, color: Color, toStep: number): Capture[] {
  const target = board.trackIndex(color, toStep);
  if (target < 0 || board.isSafeTrack(target)) return [];
  const out: Capture[] = [];
  for (const p of s.players) {
    if (p.seat === seat || p.status !== "active") continue;
    const steps = pawnsOf(s, p.color);
    for (let i = 0; i < 4; i++) {
      const step = steps[i]!;
      if (board.trackIndex(p.color, step) === target) out.push({ color: p.color, pawn: i, from: step });
    }
  }
  return out;
}

/** Legal moves of `seat` for dice `value`, ordered by pawn index. */
export function legalMoves(s: GameState, board: BoardGeometry, seat: number, value: number): LegalMove[] {
  const player = s.players[seat];
  if (!player) throw new Error(`no seat ${seat}`);
  const color = player.color;
  const steps = pawnsOf(s, color);
  const out: LegalMove[] = [];
  for (let i = 0; i < 4; i++) {
    const from = steps[i]!;
    if (from === board.goalStep) continue;
    let to: number;
    if (from === YARD) {
      if (!s.ruleset.enter_on.includes(value)) continue;
      to = 0;
    } else {
      to = from + value;
      if (to > board.goalStep) continue; // exact roll to finish
    }
    out.push({ pawn: i, from, to, captures: captureTargets(s, board, seat, color, to), finishes: to === board.goalStep });
  }
  return out;
}

/** True when every legal move is the same move (same from and to): K-20 auto-move. */
export function isSingleOption(moves: readonly LegalMove[]): boolean {
  if (moves.length === 0) return false;
  const first = moves[0]!;
  return moves.every((m) => m.from === first.from && m.to === first.to);
}

/** Steps a pawn passes through, for animation: [0] when entering, else from+1..to. */
export function pathOf(from: number, to: number): number[] {
  if (from === YARD) return [0];
  const out: number[] = [];
  for (let st = from + 1; st <= to; st++) out.push(st);
  return out;
}
