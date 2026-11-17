class_name UiTokens
extends RefCounted
## Design tokens of "Akşam Masası" (docs/UI_UX_DESIGN_SYSTEM.md §3, §4).
## The design is specified in pt; the canvas is 720 px wide for 360 pt, so
## every value here is pt x 2 (canvas pixels).

# Spacing
const S1 := 8
const S2 := 16
const S3 := 24
const S4 := 32
const S5 := 40
const S6 := 48
const S8 := 64
const EDGE := 32

# Radii
const R_S := 20
const R_M := 32
const R_L := 44
const R_XL := 56

# Sizes
const TOUCH_MIN := 88
const BUTTON_L := 112
const BUTTON_XL := 128
const BUTTON_S := 80
const ICON_BUTTON := 88
const AVATAR_L := 128
const AVATAR_M := 104
const AVATAR_S := 76
const DICE_PAD := 184
const BOARD_MARGIN := 24

# Type scale (Baloo 2 for display / headings / buttons, Nunito for text)
const DISPLAY := 68
const H1 := 52
const H2 := 40
const H3 := 34
const BUTTON_TEXT := 36
const BUTTON_TEXT_S := 30
const BUTTON_TEXT_XL := 48
const BODY := 30
const LABEL := 26
const CAPTION := 24
const MICRO := 21

# Motion (ms; scaled by Settings.anim_scale())
const T_INSTANT := 90
const T_FAST := 160
const T_BASE := 240
const T_SLOW := 360
const T_CELEBRATE := 900
const STEP_HOP_MS := 90
const DICE_MIN_MS := 350
const DICE_MAX_MS := 850
