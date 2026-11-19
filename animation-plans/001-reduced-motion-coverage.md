# 001 — Cover Game and Loading Motion With Reduce Motion

**Status:** implemented in current worktree; verification pending.
**Source commit:** `8682029`.

## Files and exact change

- `client/scripts/board/dice_view.gd::roll`: if `Settings.get_value("reduced_motion")`, set `value`, clear `_spin` / `_rolling`, redraw, and return. The method remains awaitable by its existing callers.
- `client/scripts/board/pawn_sprite.gd::hop_along`, `fly_to`, `pop`: set the final position / scale and return when reduced motion is on; do not change passed movement paths or gameplay state.
- `client/scripts/ui/screens/online_queue_screen.gd::_process`: stop phase advancement and redraw only once to reset a previously moving die.
- `client/scripts/ui/status_card.gd::_process`: leave the loading state and label visible but stop icon rotation; reset its rotation to zero.

## Boundaries

Do not remove status text, elapsed queue time, haptics, dice result visibility, legal-move target cues, or the call-site `await`s in `MatchScreen`.

## Verification

1. Toggle `reduced_motion` in Settings, start a bot match, roll, move, capture, and finish a pawn.
2. Confirm the final game state matches normal motion with no waiting animation.
3. Open online queue and a `StatusCard.loading()` state; the dice/icon must stay visually static while the textual status updates.
4. Run Godot board, match-flow, and navigation tests.
