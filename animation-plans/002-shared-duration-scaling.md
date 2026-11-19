# 002 — Make Fast Animations Reach Shared UI Motion

**Status:** implemented in current worktree; verification pending.
**Source commit:** `8682029`.

## Files and exact change

1. Add `UiTokens.duration(ms: float) -> float` in `client/scripts/ui/ui_tokens.gd`, returning `ms / 1000.0 * Settings.anim_scale()`.
2. Use that resolver for route fade/slide in `client/scripts/app/main.gd`, toast fades, bottom sheet entry, result entry, player-leave fade in `client/scripts/ui/screens/match_screen.gd`, and celebration entry/exit in `client/scripts/ui/celebration.gd`.
3. Use existing tokens only: `T_FAST` (160), `T_BASE` (240), `T_SLOW` (360). Do not create a second duration scale or rescale message dwell time.

## Boundaries

Do not shorten server timeouts, turn timers, queue timeout, dice-result minimum time, or text reading intervals. `Settings.anim_scale()` is already the authoritative fast-animation preference.

## Verification

- Compare a route transition, result card, sheet, and reward popup with fast animations on versus off; the duration should be 65% while the final state and sequence are identical.
- Confirm reduced-motion branches remain instantaneous.
