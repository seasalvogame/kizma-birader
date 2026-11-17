// GameState / PlayerState / PawnState — plain JSON-serialisable data (no
// classes, no Maps) so the same shape travels to the GDScript port, Redis
// snapshots and test vectors. Connection status is NOT part of the rules
// state: the session layer owns it (GAME_RULES §11); the engine only knows
// whether a seat is active, finished or has left, and whether it is on
// autopilot after repeated timeouts.

import { BoardGeometry, Color, COLORS, defaultBoard, YARD } from "./board.js";
import { makeRuleset, Ruleset } from "./ruleset.js";

export type PlayerKind = "human" | "bot";
export type PlayerStatus = "active" | "finished" | "left";
export type Phase = "roll" | "move" | "game_over";

export interface PlayerState {
  seat: number;
  color: Color;
  kind: PlayerKind;
  status: PlayerStatus;
  /** Final place (1..4), 0 while undecided. */
  rank: number;
  /** Consecutive timeouts (reset by any own action). */
  timeouts: number;
  autopilot: boolean;
}

/** PawnState: the step of each of the colour's four pawns (-1 .. 56). */
export type PawnSteps = [number, number, number, number];

export interface Capture {
  color: Color;
  pawn: number;
  from: number;
}

export interface LegalMove {
  pawn: number;
  from: number;
  to: number;
  captures: Capture[];
  finishes: boolean;
}

export interface TurnState {
  seat: number;
  phase: Phase;
  /** Dice value of the current move phase, 0 otherwise. */
  dice: number;
  /** Consecutive sixes in this turn. */
  sixes: number;
  /** Increases with every new roll phase (new turn or bonus roll). */
  turn_id: number;
}

export interface GameState {
  ruleset: Ruleset;
  players: PlayerState[];
  pawns: Partial<Record<Color, PawnSteps>>;
  turn: TurnState;
  /** Legal moves of the current move phase (empty otherwise). */
  legal: LegalMove[];
  /** Seats in finishing order; completed at game over. */
  ranks: number[];
  /** Seats that left, in leaving order. */
  left_order: number[];
  /** Increases with every applied action. */
  version: number;
}

export interface SeatSpec {
  color: Color;
  kind?: PlayerKind;
}

export interface NewGameOptions {
  /** Seats in turn order. Default: 4 players clockwise, or the 2-player pair. */
  seats?: SeatSpec[];
  players?: 2 | 4;
  ruleset?: Partial<Ruleset>;
  /** Seat that rolls first (the server picks it at random; GAME_RULES §2). */
  firstSeat?: number;
  board?: BoardGeometry;
}

/** Creates a new game. Seats must follow the clockwise colour order. */
export function createGame(options: NewGameOptions = {}): GameState {
  const board = options.board ?? defaultBoard;
  const seats = options.seats ?? defaultSeats(options.players ?? 4, board);
  if (seats.length !== 2 && seats.length !== 4) throw new Error("a game has 2 or 4 players");
  const colors = seats.map((s) => s.color);
  if (new Set(colors).size !== colors.length) throw new Error("duplicate colour");
  const order = colors.map((c) => COLORS.indexOf(c));
  for (let i = 1; i < order.length; i++) {
    if (order[i]! <= order[i - 1]!) throw new Error("seats must be in clockwise colour order");
  }
  if (seats.length === 2 && Math.abs(order[1]! - order[0]!) !== 2) throw new Error("2-player colours must face each other");
  const first = options.firstSeat ?? 0;
  if (first < 0 || first >= seats.length) throw new Error("bad first seat");
  const pawns: Partial<Record<Color, PawnSteps>> = {};
  for (const c of colors) pawns[c] = [YARD, YARD, YARD, YARD];
  return {
    ruleset: makeRuleset(options.ruleset),
    players: seats.map((s, seat) => ({
      seat, color: s.color, kind: s.kind ?? "human", status: "active", rank: 0, timeouts: 0, autopilot: false,
    })),
    pawns,
    turn: { seat: first, phase: "roll", dice: 0, sixes: 0, turn_id: 1 },
    legal: [],
    ranks: [],
    left_order: [],
    version: 0,
  };
}

export function defaultSeats(players: 2 | 4, board: BoardGeometry = defaultBoard): SeatSpec[] {
  if (players === 2) return board.map.two_player_colors.default.map((c) => ({ color: c as Color }));
  return COLORS.map((color) => ({ color }));
}

export function cloneState(s: GameState): GameState {
  return structuredClone(s);
}

export function pawnsOf(s: GameState, color: Color): PawnSteps {
  const p = s.pawns[color];
  if (!p) throw new Error(`colour ${color} is not in this game`);
  return p;
}
