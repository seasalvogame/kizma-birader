# CODEX_HANDOFF

## Project Goal

Kızma Birader'in Akşam Masası görsel kimliğini ve oyun/online/economy
sözleşmelerini koruyarak ölçülü, test edilebilir oyun iyileştirmeleri yapmak.

## Current Phase

- Phase: Maintenance / UI accessibility hardening
- Status: First safe slice completed; no release action taken.

## Latest Completed Work

- Bottom navigation now participates in keyboard and gamepad focus. The active
  tab receives entry focus; left/right and Tab traversal wrap across all five
  tabs; the focused tab has a palette-owned mango focus ring.
- The regression test covers focus mode, wrapping neighbours, initial focus,
  actual Right-arrow input, touch target size, and portrait screen sizes.
- A fresh non-headless Godot visual tour was captured before and after the
  slice under `artifacts/full-audit/`. Its static UI pixels are intentionally
  unchanged; this slice changes the input path rather than screen composition.
- See `FULL_AUDIT_UI_ACCESSIBILITY_REPORT.md` for the audit, evidence and
  known linter limitation.

## Important Modified Files

- `client/scripts/ui/nav_bar.gd`
- `client/tests/scene/test_app_navigation.gd`
- `artifacts/full-audit/`
- `FULL_AUDIT_UI_ACCESSIBILITY_REPORT.md`

## Verification

- `godot_console --headless --path client res://tests/test_runner.tscn`:
  passed (full offline suite; exit 0).
- Focused app-navigation suite: 9 tests, 0 failures.
- `npm --prefix server/game-engine test`: 85 tests, 0 failures.
- Game-engine and Worker `tsc --noEmit`: passed (combined command exit 0).
- Fresh visual tour: 43 baseline and 45 after-capture PNGs, rendered by Godot
  Compatibility/OpenGL on Intel UHD 620.
- `git diff --check`: passed.

## Known Risks / Untested Areas

- No physical Android device, TalkBack, or gamepad was available. Godot
  `SubViewport` keyboard input is covered, but physical-device input remains
  untested.
- The third-party static linter reports four existing false positives for
  runtime-formatted asset paths in `cosmetics.gd`, `play_card.gd` and
  `ui_theme.gd`; none originates from this slice. Runtime/scene suites pass.
- Preserve the pre-existing dirty worktree. Do not reset, overwrite unrelated
  UI changes, commit, push, deploy, migrate, or touch production data.

## Next Safest Task

Run a device-focused accessibility pass: real controller navigation, Android
safe-area behaviour, text scaling and TalkBack labels, while leaving gameplay,
backend and economy ownership unchanged.

## Follow-up — live equipped cosmetics

- The active-match cosmetic signal was expanded without changing the visual
  identity or game contracts: a confirmed loadout refresh now repaints the
  local die, board, four pawns, avatar frame/effect and name style in place.
- Added owners: `BoardView.set_theme_id`, `PawnSprite.set_skin`, and
  `PlayerCard.apply_cosmetics`; `MatchScreen` uses them only for its local
  seat after `Online.cosmetics.changed`.
- Verified by `test_board_view_and_layout` (8/8) and real non-headless capture
  `artifacts/full-audit/after/05c_match_live_cosmetic_refresh.png`.
- Preserve the unfinished Phase 7G and accessibility-hardening changes. No
  `DEBUG_HANDOFF.md` was needed: this root-cause hypothesis passed on its
  first targeted test.
