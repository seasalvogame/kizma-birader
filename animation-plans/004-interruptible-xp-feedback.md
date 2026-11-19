# 004 — Make XP Progress Updates Interruptible

**Status:** implemented in current worktree; verification pending.
**Source commit:** `8682029`.

## Files and exact change

In `client/scripts/ui/xp_bar.gd`, add `_progress_tween`. In `animate_to()` kill a valid previous tween, set the target instantly with reduced motion, otherwise tween from current `_fill` to the clamped destination over `UiTokens.duration(UiTokens.T_BASE)` using cubic ease-out.

## Boundaries

Do not change XP calculation, level data, the progress-bar visual token, or server-provided progress payloads.

## Verification

- Call `animate_to()` twice before the first animation finishes; the fill must finish at the second target without snapping backwards.
- With reduced motion enabled it reaches the target immediately.
