// board_map.json validation (MAP_SPECIFICATION.md): the single source of the
// board must describe the classic 15x15 star board exactly.

import { describe, expect, it } from "vitest";
import { BoardGeometry, COLORS, defaultBoard } from "../src/index.js";

const B = defaultBoard;
const M = B.map;
const key = (c: number[]) => `${c[0]},${c[1]}`;
const manhattan = (a: number[], b: number[]) => Math.abs(a[0]! - b[0]!) + Math.abs(a[1]! - b[1]!);
const inGrid = (c: number[]) => c[0]! >= 0 && c[0]! < M.grid && c[1]! >= 0 && c[1]! < M.grid;

describe("board_map.json", () => {
  it("is a 15x15 grid with a 52-cell track, 5-cell corridors and 56 steps to the goal", () => {
    expect(M.grid).toBe(15);
    expect(M.track_length).toBe(52);
    expect(M.track).toHaveLength(52);
    expect(M.home_column_length).toBe(5);
    expect(M.steps_to_goal).toBe(56);
    expect(M.colors_clockwise).toEqual(["red", "green", "yellow", "blue"]);
  });

  it("has a closed track of unique cells: neighbours, except the four diagonal steps around the centre", () => {
    expect(new Set(M.track.map(key)).size).toBe(52);
    const diagonal: number[] = [];
    M.track.forEach((c, i) => {
      expect(inGrid(c)).toBe(true);
      const next = M.track[(i + 1) % 52]!;
      const dx = Math.abs(c[0]! - next[0]!);
      const dy = Math.abs(c[1]! - next[1]!);
      if (dx === 1 && dy === 1) diagonal.push(i);
      else expect(dx + dy, `step ${i} -> ${i + 1}`).toBe(1);
    });
    // Classic Ludo: the path cuts the inner corner of the cross (e.g. (5,6) -> (6,5)).
    expect(diagonal).toEqual([4, 17, 30, 43]);
  });

  it("places the starts 13 apart and the stars 8 after each start", () => {
    expect(COLORS.map((c) => M.start_track_index[c])).toEqual([0, 13, 26, 39]);
    expect(M.star_track_indices).toEqual([8, 21, 34, 47]);
    expect([...M.safe_track_indices].sort((a, b) => a - b)).toEqual([0, 8, 13, 21, 26, 34, 39, 47]);
  });

  it("enters each corridor from the track cell next to it, and the corridor leads to the centre", () => {
    for (const c of COLORS) {
      const home = M.home_columns[c]!;
      expect(home).toHaveLength(5);
      const lastTrack = M.track[(M.start_track_index[c]! + 50) % 52]!;
      expect(manhattan(lastTrack, home[0]!)).toBe(1);
      for (let i = 1; i < 5; i++) expect(manhattan(home[i - 1]!, home[i]!)).toBe(1);
      const k5 = home[4]!;
      expect(M.goal_cells.some((g) => manhattan(g, k5) === 1)).toBe(true);
    }
  });

  it("has a 3x3 goal in the centre and four non-overlapping 6x6 yards in the corners", () => {
    expect(new Set(M.goal_cells.map(key))).toEqual(new Set([6, 7, 8].flatMap((x) => [6, 7, 8].map((y) => `${x},${y}`))));
    const corners: Record<string, number[]> = { red: [0, 0], green: [9, 0], yellow: [9, 9], blue: [0, 9] };
    for (const c of COLORS) {
      const y = M.yards[c]!;
      expect(y.rect).toEqual([...corners[c]!, 6, 6]);
      expect(y.slots).toHaveLength(4);
      for (const s of y.slots) {
        expect(s[0]! > y.rect[0]! && s[0]! < y.rect[0]! + 6 && s[1]! > y.rect[1]! && s[1]! < y.rect[1]! + 6).toBe(true);
      }
    }
  });

  it("keeps track, corridors, goal and yards apart", () => {
    const used = new Map<string, string>();
    const claim = (c: number[], what: string) => {
      expect(used.has(key(c)), `${what} overlaps ${used.get(key(c))} at ${key(c)}`).toBe(false);
      used.set(key(c), what);
    };
    M.track.forEach((c) => claim(c, "track"));
    for (const c of COLORS) M.home_columns[c]!.forEach((h) => claim(h, `${c} corridor`));
    M.goal_cells.forEach((g) => claim(g, "goal"));
    for (const c of COLORS) {
      const [x0, y0] = M.yards[c]!.rect;
      for (let x = x0!; x < x0! + 6; x++) for (let y = y0!; y < y0! + 6; y++) claim([x, y], `${c} yard`);
    }
    expect(used.size).toBe(15 * 15);
  });

  it("describes each colour's path consistently with the track and the corridor", () => {
    for (const c of COLORS) {
      const path = M.paths[c]!;
      expect(path).toHaveLength(57);
      for (let st = 0; st <= 50; st++) expect(path[st]).toEqual(M.track[(M.start_track_index[c]! + st) % 52]);
      for (let k = 0; k < 5; k++) expect(path[51 + k]).toEqual(M.home_columns[c]![k]);
      expect(path[56]).toBe("GOAL");
    }
  });

  it("is rotation-symmetric: a clockwise quarter turn maps each colour onto the next", () => {
    for (let i = 0; i < 52; i++) expect(B.rotate(M.track[i] as [number, number], 1)).toEqual(M.track[(i + 13) % 52]);
    for (let ci = 0; ci < 4; ci++) {
      const c = COLORS[ci]!;
      const next = COLORS[(ci + 1) % 4]!;
      M.home_columns[c]!.forEach((h, k) => expect(B.rotate(h as [number, number], 1)).toEqual(M.home_columns[next]![k]));
    }
  });

  it("maps steps to track indices and cells", () => {
    expect(B.trackIndex("blue", 0)).toBe(39);
    expect(B.trackIndex("blue", 13)).toBe(0);
    expect(B.trackIndex("red", 50)).toBe(50);
    expect(B.trackIndex("red", 51)).toBe(-1);
    expect(B.trackIndex("red", -1)).toBe(-1);
    expect(B.cellOf("red", 0)).toEqual([1, 6]);
    expect(B.cellOf("red", 51)).toEqual([1, 7]);
    expect(B.cellOf("red", 56)).toBeNull();
  });

  it("rotates every colour to the bottom-left corner", () => {
    for (const c of COLORS) {
      const turns = B.quarterTurnsToBottomLeft(c);
      const [x0, y0] = M.yards[c]!.rect;
      // The yard's centre cell ends up in the bottom-left yard.
      const centre = B.rotate([x0! + 2, y0! + 2], turns);
      expect(centre[0] < 6 && centre[1] > 8, `${c} after ${turns} turns -> ${centre}`).toBe(true);
    }
    expect(B.quarterTurnsToBottomLeft("blue")).toBe(0);
    expect(B.quarterTurnsToBottomLeft("red")).toBe(3);
  });

  it("can be constructed from another map object", () => {
    expect(new BoardGeometry(M).goalStep).toBe(56);
  });
});
