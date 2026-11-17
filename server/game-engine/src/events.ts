// GameEvent — what happened, in order, for animation, logging and the
// network (NETWORK_PROTOCOL §5.3). Plain objects with snake_case fields.

import { Color } from "./board.js";
import { Capture } from "./state.js";

export type GameEvent =
  | { type: "dice_rolled"; seat: number; value: number; auto: boolean }
  | { type: "no_moves"; seat: number }
  | { type: "pawn_moved"; seat: number; color: Color; pawn: number; from: number; to: number; path: number[]; auto: boolean }
  | { type: "pawn_captured"; seat: number; by_seat: number; color: Color; pawn: number; from: number }
  | { type: "pawn_finished"; seat: number; color: Color; pawn: number }
  | { type: "bonus_roll"; seat: number; reason: "six" | "capture" | "finish" }
  | { type: "turn_forfeited"; seat: number; reason: "three_sixes" }
  | { type: "turn_changed"; seat: number; turn_id: number }
  | { type: "player_finished"; seat: number; rank: number }
  | { type: "player_left"; seat: number }
  | { type: "autopilot_changed"; seat: number; on: boolean }
  | { type: "game_over"; ranks: number[] };

export type { Capture };
