# 001 — Preserve Pawn Identity in Board Destination Cues

**Status:** implemented in the current worktree; verify with a finish-lane capture.

**Basis:** Improve UI audit, runtime path `App._match_screen()` → `MatchScreen._sync()` / `_animate_move()` → `BoardView._draw()`.

## Scope

Only visual destination and trail placement. Do not change move legality, `MatchController`, board geometry, online payloads, or input handling.

## Required change

1. In `client/scripts/ui/screens/match_screen.gd`, retain `m["pawn"]` when appending `board_view.targets`.
2. Retain the same `e["pawn"]` in `board_view.trail` inside `_animate_move`.
3. In `client/scripts/board/board_view.gd`, pass `int(t.get("pawn", 0))` to `pawn_position()` while drawing target rings.
4. In `_draw_trail`, read `trail.get("pawn", 0)` and use it for every generated trail point.
5. Keep the `get(..., 0)` fallback for existing test fixtures / older state dictionaries.

## Acceptance

- A legal finishing move for pawn 1–3 marks that pawn's exact goal-lane slot, not pawn 0's slot.
- A finishing-move trail ends at the same slot as the animated pawn.
- Normal track-path cues remain unchanged.
- Run the board layout and match-flow Godot tests plus a non-headless match screenshot tour.
