// Generates the shared rules test vectors (shared/rules_test_vectors/) from
// the TypeScript engine. The GDScript engine must reproduce every event and
// every state hash exactly. Re-run after an intentional rule change:
//   npm run vectors        (then review the diff and commit)
//
// scenarios.json — hand-written situations; for every action: ok / error,
//   the full event list, the canonical state text and its hash.
// traces.json — seeded random games (random dice, random legal choices,
//   occasional timeouts); compact actions + the state hash after each one.

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  Action, canonicalState, Color, createGame, GameEngine, GameState, maxDiceValue, NewGameOptions, PawnSteps, seededRandom, stateHash,
} from "../src/index.js";

const OUT = resolve(dirname(fileURLToPath(import.meta.url)), "../../../shared/rules_test_vectors");
const E = new GameEngine();

export interface VectorAction {
  type: "roll" | "move" | "timeout" | "leave";
  dice?: number;
  pawn?: number;
  /** Defaults: the seat to play and the current turn id. */
  seat?: number;
  turn_id?: number;
}

export interface Scenario {
  name: string;
  setup: { players?: 2 | 4; seats?: { color: Color; kind?: "human" | "bot" }[]; ruleset?: Record<string, unknown>; first_seat?: number; pawns?: Partial<Record<Color, number[]>> };
  actions: VectorAction[];
}

export function setupGame(setup: Scenario["setup"]): GameState {
  const options: NewGameOptions = {};
  if (setup.players) options.players = setup.players;
  if (setup.seats) options.seats = setup.seats;
  if (setup.ruleset) options.ruleset = setup.ruleset;
  if (setup.first_seat !== undefined) options.firstSeat = setup.first_seat;
  const s = createGame(options);
  for (const [c, steps] of Object.entries(setup.pawns ?? {})) s.pawns[c as Color] = [...steps] as PawnSteps;
  return s;
}

export function toAction(s: GameState, a: VectorAction): Action {
  const seat = a.seat ?? s.turn.seat;
  const turn_id = a.turn_id ?? s.turn.turn_id;
  if (a.type === "leave") return { type: "leave", seat };
  if (a.type === "move") return { type: "move", seat, turn_id, pawn: a.pawn ?? 0 };
  return { type: a.type, seat, turn_id };
}

const R = (dice: number): VectorAction => ({ type: "roll", dice });
const M = (pawn: number): VectorAction => ({ type: "move", pawn });

export const SCENARIOS: Scenario[] = [
  { name: "enter_with_six_then_bonus", setup: {}, actions: [R(6), M(2), R(3), M(2)] },
  { name: "no_entry_without_six", setup: {}, actions: [R(1), R(2), R(3), R(4), R(5)] },
  { name: "move_exact_count_and_turn_change", setup: { pawns: { red: [5, -1, -1, -1] } }, actions: [R(4), M(0)] },
  { name: "six_gives_bonus_roll", setup: { pawns: { red: [5, -1, -1, -1] } }, actions: [R(6), M(0), R(2), M(0)] },
  // GAME_RULES §6.2 (classic_v1, exclude_six): after two 6s the next roll is 1..5; a 6 (roll or
  // roll-phase timeout) is INVALID_DICE and changes nothing; the 5 is a normal roll without a bonus.
  { name: "third_roll_cannot_be_six", setup: { pawns: { red: [5, -1, -1, -1] } },
    actions: [R(6), M(0), R(6), M(0), { type: "timeout", dice: 6 }, R(6), R(5), M(0)] },
  // The limited roll captures (17 -> 20 = green step 7): capture bonus; the counter was reset, so 6 is allowed again.
  { name: "third_roll_capture_bonus_resets_counter", setup: { pawns: { red: [5, -1, -1, -1], green: [7, -1, -1, -1] } },
    actions: [R(6), M(0), R(6), M(0), R(3), M(0), R(6), M(1), R(6), M(1), R(6), R(1), M(0)] },
  // The limited roll times out: auto roll with 1..5 and auto move.
  { name: "third_roll_timeout", setup: { pawns: { red: [5, -1, -1, -1] } },
    actions: [R(6), M(0), R(6), M(0), { type: "timeout", dice: 2 }] },
  // Alternative ruleset kept as an option: a third 6 ends the turn.
  { name: "third_six_forfeits_alt_ruleset", setup: { ruleset: { third_six_action: "forfeit_turn" }, pawns: { red: [5, -1, -1, -1] } },
    actions: [R(6), M(0), R(6), M(0), R(6), R(4)] },
  { name: "six_without_moves_keeps_bonus", setup: { pawns: { red: [56, 56, 56, 53] } }, actions: [R(6), R(5)] },
  { name: "star_is_safe", setup: { pawns: { red: [17, -1, -1, -1], green: [8, -1, -1, -1] } }, actions: [R(4), M(0)] },
  { name: "start_cell_is_safe", setup: { pawns: { red: [22, -1, -1, -1], green: [13, -1, -1, -1] } }, actions: [R(4), M(0)] },
  { name: "entry_onto_occupied_start", setup: { pawns: { green: [39, -1, -1, -1] } }, actions: [R(6), M(0)] },
  { name: "capture_sends_home_and_bonus", setup: { pawns: { red: [16, -1, -1, -1], green: [7, -1, -1, -1] } }, actions: [R(4), M(0), R(1), M(0)] },
  { name: "capture_whole_stack", setup: { pawns: { red: [16, -1, -1, -1], green: [7, 7, -1, -1], yellow: [46, -1, -1, -1] } }, actions: [R(4), M(0)] },
  { name: "passing_over_does_not_capture", setup: { pawns: { red: [10, -1, -1, -1], green: [1, -1, -1, -1] } }, actions: [R(5), M(0)] },
  { name: "own_stack_allowed", setup: { pawns: { red: [7, 10, -1, -1] } }, actions: [R(3), M(0)] },
  { name: "corridor_entry", setup: { pawns: { red: [48, -1, -1, -1] } }, actions: [R(5), M(0)] },
  { name: "exact_roll_to_finish", setup: { pawns: { red: [53, -1, -1, -1] } }, actions: [R(4), R(2), R(2), R(2), R(3), M(0)] },
  { name: "two_player_win", setup: { players: 2, pawns: { red: [56, 56, 56, 53] } }, actions: [R(3), M(3), R(2)] },
  { name: "four_player_until_three_finish", setup: { pawns: { red: [56, 56, 56, 55], green: [56, 56, 56, 55], yellow: [56, 56, 56, 55], blue: [10, -1, -1, -1] } }, actions: [R(1), M(3), R(1), M(3), R(1), M(3)] },
  { name: "finished_players_are_skipped", setup: { pawns: { red: [56, 56, 56, 55], green: [5, -1, -1, -1] } }, actions: [R(1), M(3), R(2), M(0), R(2), R(2), R(1), M(0)] },
  { name: "first_finisher_mode", setup: { ruleset: { four_player_end: "first_finisher" }, pawns: { red: [56, 56, 56, 55], green: [10, 3, -1, -1], yellow: [40, -1, -1, -1], blue: [10, 3, -1, -1] } }, actions: [R(1), M(3)] },
  {
    name: "invalid_actions_are_rejected",
    setup: { pawns: { red: [5, -1, -1, -1] } },
    actions: [{ type: "move", pawn: 0 }, R(3), M(1), { type: "roll", dice: 4 }, { type: "roll", dice: 2, seat: 2 }, M(0), { type: "roll", dice: 6, turn_id: 1 }, { type: "move", pawn: 0, seat: 3 }],
  },
  { name: "invalid_dice_value", setup: {}, actions: [{ type: "roll", dice: 7 }, { type: "roll", dice: 0 }, R(2)] },
  { name: "timeout_rolls_and_moves", setup: { pawns: { red: [5, -1, -1, -1] } }, actions: [{ type: "timeout", dice: 3 }] },
  { name: "timeout_in_move_phase_plays_bot_move", setup: { pawns: { red: [5, 20, -1, -1] } }, actions: [R(2), { type: "timeout" }] },
  { name: "three_timeouts_autopilot_then_back", setup: { players: 2 }, actions: [{ type: "timeout", dice: 2 }, R(2), { type: "timeout", dice: 2 }, R(2), { type: "timeout", dice: 2 }, R(2), R(2)] },
  { name: "leave_four_player", setup: { pawns: { red: [5, -1, -1, -1], green: [7, -1, -1, -1] } }, actions: [{ type: "leave", seat: 1 }, R(1), M(0), R(3)] },
  { name: "leave_on_own_turn_two_player", setup: { players: 2 }, actions: [{ type: "leave", seat: 0 }] },
  { name: "leave_removes_capture_option", setup: { pawns: { red: [16, -1, -1, -1], green: [7, -1, -1, -1] } }, actions: [R(4), { type: "leave", seat: 1 }, M(0)] },
  { name: "three_leave_ends_game", setup: {}, actions: [{ type: "leave", seat: 1 }, { type: "leave", seat: 2 }, { type: "leave", seat: 3 }] },
  { name: "bot_priorities_finish", setup: { pawns: { red: [53, 17, -1, -1], green: [7, -1, -1, -1] } }, actions: [R(3), { type: "timeout" }] },
  { name: "bot_priorities_capture", setup: { pawns: { red: [5, 16, -1, -1], green: [7, -1, -1, -1] } }, actions: [R(4), { type: "timeout" }] },
  { name: "bot_priorities_escape", setup: { pawns: { red: [2, 19, -1, -1], green: [3, -1, -1, -1] } }, actions: [R(2), { type: "timeout" }] },
  { name: "bot_priorities_rearmost", setup: { pawns: { red: [30, 4, 12, -1] } }, actions: [R(3), { type: "timeout" }] },
  { name: "bot_ignores_threat_turning_home", setup: { pawns: { red: [38, 30, -1, -1], blue: [49, -1, -1, -1] } }, actions: [R(2), { type: "timeout" }] },
  { name: "enter_on_one_or_six", setup: { ruleset: { enter_on: [1, 6] } }, actions: [R(1), M(0)] },
  { name: "no_capture_bonus_when_disabled", setup: { ruleset: { bonus_roll_on_capture: false }, pawns: { red: [16, -1, -1, -1], green: [7, -1, -1, -1] } }, actions: [R(4), M(0)] },
  { name: "two_player_green_blue", setup: { seats: [{ color: "green" }, { color: "blue" }], first_seat: 1 }, actions: [R(6), M(0), R(5), M(0), R(6), M(1)] },
  { name: "bot_kind_never_autopilot", setup: { seats: [{ color: "red", kind: "bot" }, { color: "yellow" }] }, actions: [{ type: "timeout", dice: 1 }, R(1), { type: "timeout", dice: 1 }, R(1), { type: "timeout", dice: 1 }] },
];

export function runScenario(sc: Scenario) {
  let s = setupGame(sc.setup);
  const steps = sc.actions.map((a) => {
    const r = E.apply(s, toAction(s, a), a.dice);
    if (r.ok) s = r.state;
    return r.ok
      ? { ok: true, events: r.events, state: canonicalState(s), hash: stateHash(s) }
      : { ok: false, error: r.error, state: canonicalState(s), hash: stateHash(s) };
  });
  return { name: sc.name, setup: sc.setup, initial: canonicalState(setupGame(sc.setup)), actions: sc.actions, expect: steps };
}

/** Compact trace action: r<d> roll, m<p> move, t<d> roll-phase timeout, t move-phase timeout. */
export function playTrace(seed: number, players: 2 | 4) {
  const rnd = seededRandom(seed);
  const first = Math.floor(rnd() * players);
  let s = createGame({ players, firstSeat: first });
  const actions: string[] = [];
  const hashes: number[] = [];
  while (s.turn.phase !== "game_over") {
    const seat = s.turn.seat;
    const turn_id = s.turn.turn_id;
    let code: string;
    let r;
    const u = rnd();
    if (u < 0.03) {
      if (s.turn.phase === "roll") {
        const d = 1 + Math.floor(rnd() * maxDiceValue(s));
        code = `t${d}`;
        r = E.apply(s, { type: "timeout", seat, turn_id }, d);
      } else {
        code = "t";
        r = E.apply(s, { type: "timeout", seat, turn_id });
      }
    } else if (s.turn.phase === "roll") {
      const d = 1 + Math.floor(rnd() * maxDiceValue(s));
      code = `r${d}`;
      r = E.apply(s, { type: "roll", seat, turn_id }, d);
    } else {
      const pawn = s.legal[Math.floor(rnd() * s.legal.length)]!.pawn;
      code = `m${pawn}`;
      r = E.apply(s, { type: "move", seat, turn_id, pawn });
    }
    if (!r.ok) throw new Error(`trace ${seed}: ${r.error}`);
    s = r.state;
    actions.push(code);
    hashes.push(stateHash(s));
    if (actions.length > 10000) throw new Error(`trace ${seed} too long`);
  }
  return { seed, players, first_seat: first, actions: actions.join(" "), hashes, final: canonicalState(s) };
}

export const TRACE_SEEDS: { seed: number; players: 2 | 4 }[] = [];
for (let i = 1; i <= 30; i++) TRACE_SEEDS.push({ seed: 1000 + i, players: 2 });
for (let i = 1; i <= 30; i++) TRACE_SEEDS.push({ seed: 5000 + i, players: 4 });

export function buildVectors() {
  return {
    scenarios: { format: 1, generated_by: "server/game-engine/scripts/gen-vectors.ts", ruleset: "classic_v1", scenarios: SCENARIOS.map(runScenario) },
    traces: { format: 1, generated_by: "server/game-engine/scripts/gen-vectors.ts", traces: TRACE_SEEDS.map((t) => playTrace(t.seed, t.players)) },
  };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const v = buildVectors();
  mkdirSync(OUT, { recursive: true });
  writeFileSync(resolve(OUT, "scenarios.json"), JSON.stringify(v.scenarios, null, 1) + "\n");
  writeFileSync(resolve(OUT, "traces.json"), JSON.stringify(v.traces) + "\n");
  const steps = v.traces.traces.reduce((n, t) => n + t.hashes.length, 0);
  console.log(`wrote ${v.scenarios.scenarios.length} scenarios, ${v.traces.traces.length} traces (${steps} steps) to ${OUT}`);
}
