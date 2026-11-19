# 002 — Distinguish the Inactive Die From the Roll Action

**Status:** implemented in the current worktree; verify against an opponent-turn capture.

**Basis:** Improve UI audit, real renderer evidence `artifacts/phase7g/pawn-refresh/08_match_2p.png` and runtime state `MatchScreen._sync()` → `DiceView.set_active()` → `DiceView._draw()`.

## Scope

Only the `DiceView` visual treatment for `active == false`. Do not alter whether a player may roll, the click handler, value generation, or turn logic.

## Required change

1. Keep the existing active mango pad/pulse exactly as the local player's roll affordance.
2. In `client/scripts/board/dice_view.gd::_draw`, render the face at `0.62` of the available size and tint it `Color(0.72, 0.67, 0.78, 0.82)` when inactive.
3. Retain `0.72` and `Color.WHITE` when active.
4. Use `draw_texture_rect(..., face_tint)` so the asset and pip value remain readable.

## Acceptance

- Opponent/bot-turn die is visibly contextual, not a competing primary call to action.
- Local roll state remains bright, mango-framed, and tappable.
- Dice face values remain legible in both states.
- Run app navigation and match screenshot tour checks.
