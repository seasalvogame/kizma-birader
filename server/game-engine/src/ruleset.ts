// Ruleset — the configurable rules (GAME_RULES.md §12). Keys are snake_case
// on purpose: the same JSON object is used by the server, the GDScript port,
// match records (matches.ruleset) and the shared test vectors.

export interface Ruleset {
  id: string;
  enter_on: number[];
  entry_attempts_when_all_in_yard: number;
  bonus_roll_on_six: boolean;
  max_consecutive_sixes: number;
  /** exclude_six (classic_v1): after two 6s in a row the next roll is 1..5. forfeit_turn: a third 6 ends the turn. */
  third_six_action: "exclude_six" | "forfeit_turn";
  bonus_roll_on_capture: boolean;
  bonus_roll_on_finish: boolean;
  safe_cells: "starts_and_stars";
  capture_on_start_cell: boolean;
  stacking: "allowed";
  blockade: "none";
  capture_stack: "all";
  exact_roll_to_finish: boolean;
  auto_move_single_option: boolean;
  turn_roll_seconds: number;
  turn_move_seconds: number;
  afk_timeouts_to_autopilot: number;
  two_player_claim_win_seconds: number;
  four_player_disconnect_leave_seconds: number;
  four_player_end: "until_three_finish" | "first_finisher";
}

/**
 * classic_v1. Approved: enter only on 6, bonus roll on 6, after two 6s in a
 * row the next roll can only be 1..5 (decided 2026-11-17, replaces "third 6
 * ends the turn"), starts + stars safe, exact roll to finish, 4p plays until
 * three are ranked, 10 s roll / 12 s move. Still proposals (K-11, K-14, K-15,
 * K-18, K-20, K-22): entry onto the start cell, bonus on capture / finish,
 * free stacking without blockades, auto-move of a single option, AFK count.
 */
export const CLASSIC_V1: Readonly<Ruleset> = Object.freeze({
  id: "classic_v1",
  enter_on: [6],
  entry_attempts_when_all_in_yard: 1,
  bonus_roll_on_six: true,
  max_consecutive_sixes: 3,
  third_six_action: "exclude_six",
  bonus_roll_on_capture: true,
  bonus_roll_on_finish: true,
  safe_cells: "starts_and_stars",
  capture_on_start_cell: false,
  stacking: "allowed",
  blockade: "none",
  capture_stack: "all",
  exact_roll_to_finish: true,
  auto_move_single_option: true,
  turn_roll_seconds: 10,
  turn_move_seconds: 12,
  afk_timeouts_to_autopilot: 3,
  two_player_claim_win_seconds: 90,
  four_player_disconnect_leave_seconds: 300,
  four_player_end: "until_three_finish",
} as Ruleset);

/** Options described in GAME_RULES.md that this engine version implements. */
const SUPPORTED: Record<string, readonly unknown[]> = {
  third_six_action: ["exclude_six", "forfeit_turn"],
  safe_cells: ["starts_and_stars"],
  stacking: ["allowed"],
  blockade: ["none"],
  capture_stack: ["all"],
  four_player_end: ["until_three_finish", "first_finisher"],
  entry_attempts_when_all_in_yard: [1],
  capture_on_start_cell: [false],
  exact_roll_to_finish: [true],
};

/** Merges overrides into classic_v1 and rejects unknown keys or unsupported values. */
export function makeRuleset(overrides: Partial<Ruleset> = {}): Ruleset {
  const r: Ruleset = { ...CLASSIC_V1, ...overrides, enter_on: [...(overrides.enter_on ?? CLASSIC_V1.enter_on)] };
  for (const key of Object.keys(overrides)) {
    if (!(key in CLASSIC_V1)) throw new Error(`unknown ruleset key: ${key}`);
  }
  for (const [key, allowed] of Object.entries(SUPPORTED)) {
    const value = (r as unknown as Record<string, unknown>)[key];
    if (!allowed.includes(value)) throw new Error(`ruleset ${key}=${String(value)} is not implemented yet`);
  }
  if (r.enter_on.length === 0 || r.enter_on.some((v) => !Number.isInteger(v) || v < 1 || v > 6)) {
    throw new Error("enter_on must list dice values 1..6");
  }
  if (!Number.isInteger(r.max_consecutive_sixes) || r.max_consecutive_sixes < 2) {
    throw new Error("max_consecutive_sixes must be >= 2");
  }
  if (r.turn_roll_seconds <= 0 || r.turn_move_seconds <= 0) throw new Error("turn timers must be > 0");
  return r;
}
