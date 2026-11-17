// BoardGeometry — reads the single source docs/design/board/board_map.json
// (MAP_SPECIFICATION.md). Nothing about the board is re-encoded here: the
// track, starts, stars, corridors, yards and goal all come from the JSON.

import boardJson from "../../../docs/design/board/board_map.json" with { type: "json" };

export const COLORS = ["red", "green", "yellow", "blue"] as const;
export type Color = (typeof COLORS)[number];
export type Cell = readonly [number, number];

/** Step of a pawn on its own path: -1 yard, 0..50 common track, 51..55 corridor, 56 goal. */
export const YARD = -1;

export interface BoardMap {
  grid: number;
  track_length: number;
  home_column_length: number;
  steps_to_goal: number;
  track: number[][];
  colors_clockwise: string[];
  start_track_index: Record<string, number>;
  safe_track_indices: number[];
  star_track_indices: number[];
  home_columns: Record<string, number[][]>;
  goal_cells: number[][];
  yards: Record<string, { rect: number[]; slots: number[][] }>;
  paths: Record<string, (number[] | "GOAL")[]>;
  two_player_colors: { default: string[]; alternative: string[] };
}

export class BoardGeometry {
  readonly map: BoardMap;
  readonly trackLength: number;
  readonly goalStep: number;
  /** Last step on the common track (50); the next step enters the corridor. */
  readonly lastTrackStep: number;
  private readonly safe: Set<number>;

  constructor(map: BoardMap = boardJson as unknown as BoardMap) {
    this.map = map;
    this.trackLength = map.track_length;
    this.goalStep = map.steps_to_goal;
    this.lastTrackStep = map.steps_to_goal - map.home_column_length - 1;
    this.safe = new Set(map.safe_track_indices);
  }

  startIndex(color: Color): number {
    const v = this.map.start_track_index[color];
    if (v === undefined) throw new Error(`no start for ${color}`);
    return v;
  }

  /** Common-track index of a step, or -1 when the step is not on the common track. */
  trackIndex(color: Color, step: number): number {
    if (step < 0 || step > this.lastTrackStep) return -1;
    return (this.startIndex(color) + step) % this.trackLength;
  }

  isSafeTrack(trackIndex: number): boolean {
    return this.safe.has(trackIndex);
  }

  /** Grid cell of a step on the colour's path (yard and goal have no single cell). */
  cellOf(color: Color, step: number): Cell | null {
    const path = this.map.paths[color];
    if (!path || step < 0 || step > this.goalStep) return null;
    const c = path[step];
    return c === "GOAL" || c === undefined ? null : [c[0]!, c[1]!];
  }

  /** Clockwise quarter turns that bring `color`'s yard to the bottom-left corner (K-09). */
  quarterTurnsToBottomLeft(color: Color): number {
    const index = this.map.colors_clockwise.indexOf(color);
    const bottomLeft = this.map.colors_clockwise.indexOf("blue");
    return (((bottomLeft - index) % 4) + 4) % 4;
  }

  /** Rotates a cell clockwise by `turns` quarter turns around the grid centre. */
  rotate(cell: Cell, turns: number): Cell {
    let [x, y] = cell;
    const n = this.map.grid - 1;
    for (let i = 0; i < ((turns % 4) + 4) % 4; i++) [x, y] = [n - y, x];
    return [x, y];
  }
}

export const defaultBoard = new BoardGeometry();
