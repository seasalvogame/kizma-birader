# 003 — Keep Reward and Turn Motion Small and Intentional

**Status:** implemented in current worktree; verification pending.
**Source commit:** `8682029`.

## Files and exact change

- `client/scripts/ui/celebration.gd`: start the card at `Vector2(0.94, 0.94)`, not `Vector2(0.6, 0.6)`; fade with `T_FAST`, settle with `T_SLOW`, `TRANS_BACK`, `EASE_OUT`.
- `client/scripts/ui/player_card.gd`: keep one `_turn_tween`, transition only when active state changes, use scale `1.04` / `1.0`, and use a `T_FAST` cubic ease-out. Set the final scale immediately for reduced motion.

## Boundaries

Keep the avatar countdown ring and status copy. Do not add perpetual scale pulsing or a new entrance animation.

## Verification

- A reward feels like a nearby card settling into place, not an element appearing from zero.
- On repeated countdown progress calls, active avatar scale does not restart/jitter.
- Switching turns interrupts the old tween cleanly.
