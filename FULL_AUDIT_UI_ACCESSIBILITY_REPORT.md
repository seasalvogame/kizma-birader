# Full Audit — UI Accessibility Slice

**Date:** 19 November 2026
**Phase:** Maintenance / focused UI accessibility hardening
**Scope:** Bottom navigation input accessibility only. Existing game rules,
economy, saves, matchmaking, online state, cosmetics authority and backend
contracts were not changed.

## Player outcome

A player using a hardware keyboard or gamepad can enter the bottom navigation,
see which tab owns focus, and move predictably between its five destinations.
Touch behaviour, tab routing and the Akşam Masası visual hierarchy remain
unchanged.

## Audit finding and correction

| Priority | Finding | Evidence | Correction |
|---|---|---|
| P2 | Bottom tabs set `FOCUS_NONE`, preventing keyboard/gamepad traversal. | `client/scripts/ui/nav_bar.gd` before this slice; the app exposes five primary destinations in that component. | Set `FOCUS_ALL`, add a palette-owned focus StyleBox, give the current tab entry focus, and define wrapping left/right/Tab neighbours. |

The correction is intentionally narrow: it changes neither route ownership nor
the selected-tab state; it only supplies an alternative input path and visible
focus feedback. The 112-canvas-pixel (56 pt) tab hit target remains unchanged.

## Changed files

- `client/scripts/ui/nav_bar.gd`
  - explicit focus participation and entry focus;
  - wrapping left/right/Tab paths;
  - mango focus ring consistent with the shared palette.
- `client/tests/scene/test_app_navigation.gd`
  - verifies focus eligibility, circular neighbour paths, initial focus and a
    real Right-arrow `SubViewport` input transition across all tested phone
    dimensions.

## Evidence

Fresh real Godot Compatibility-renderer captures were created with:

```text
godot_console --path client --resolution 540x1170 res://tests/visual/screenshot_tour.tscn -- --shots=<output> --settings-path=user://... --safe-insets=94,48 --locale=tr
```

- [Before capture set](artifacts/full-audit/before): 43 PNGs.
- [After capture set](artifacts/full-audit/after): 45 PNGs.
- [Parity comparisons](artifacts/full-audit/comparisons): home, settings and
  store. Each has zero pixel delta, which is expected because this is an input
  and focus-ownership fix rather than a composition or content change.

The focused home tab is visible in the real home capture; actual directional
input is proved by the new Godot scene test rather than inferred from a still.

## Verification

| Check | Result |
|---|---|
| Focused app-navigation Godot suite | 9 tests / 0 failures |
| Full offline Godot suite | Passed; command exit 0 |
| TypeScript deterministic game engine | 85 tests / 0 failures |
| Game-engine typecheck | Passed |
| Worker typecheck | Passed |
| `git diff --check` | Passed |
| Non-headless Godot visual tour | Completed; OpenGL 3.3 Compatibility renderer, Intel UHD 620 |

## Linter note

The supplied static `lint_project.py` completed but reports four pre-existing
`missing_resource` false positives: it treats runtime-formatted `%d` and `%s`
paths in `cosmetics.gd`, `play_card.gd` and `ui_theme.gd` as literal resources.
It reports no finding in the changed navigation component. The full Godot test
suite and visual renderer run both passed.

## Remaining risk and next safe slice

No physical Android device, TalkBack session or controller was available, so
their behaviour is not claimed as verified. The next safe slice is a
device-focused accessibility pass covering controller navigation, safe areas,
text scaling and screen-reader labels—without modifying gameplay or backend
authority.
