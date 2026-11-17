class_name UiPalette
extends RefCounted
## Colours of "Akşam Masası" (docs/UI_UX_DESIGN_SYSTEM.md §2). Player colours
## are used only for pawns, yards, avatar rings and turn indicators.

const NIGHT_900 := Color("#140e2b")
const NIGHT_800 := Color("#1d1438")
const NIGHT_700 := Color("#2a1d52")
const NIGHT_600 := Color("#3a2a6b")
const GLOW := Color(1.0, 0.659, 0.298, 0.22)

const CREAM_50 := Color("#fffaf2")
const CREAM_100 := Color("#fff3e2")
const CREAM_200 := Color("#f5e6cf")
const CREAM_300 := Color("#e8d3b4")
const INK_900 := Color("#2a1f3d")
const INK_700 := Color("#4b3f62")
const INK_500 := Color("#7a6d91")
const ON_NIGHT := Color("#f6efff")
const ON_NIGHT_DIM := Color("#b9add6")
const GLASS := Color(1, 1, 1, 0.07)
const GLASS_EDGE := Color(1, 1, 1, 0.12)

const MANGO_300 := Color("#ffc35a")
const MANGO_500 := Color("#ff9a1f")
const MANGO_700 := Color("#c25f00")
const MANGO_INK := Color("#3d1c00")
const BERRY_500 := Color("#ff5d8f")
const MINT_500 := Color("#2fd39a")
const GOLD_300 := Color("#ffe08a")
const GOLD_500 := Color("#ffc531")
const GOLD_700 := Color("#c88a00")
const DANGER_500 := Color("#ff5a5f")

const BOARD := Color("#fff6e6")
const CELL := Color("#ffffff")
const CELL_EDGE := Color("#ead7bb")
const STAR := Color("#ffd04a")
const STAR_EDGE := Color("#d49a00")

const PLAYER := {
	"red": {"base": Color("#e5484d"), "dark": Color("#a8262b"), "soft": Color("#ffd5d6"), "light": Color("#ff8e91"), "symbol": "triangle"},
	"green": {"base": Color("#2fb463"), "dark": Color("#1c7a40"), "soft": Color("#cdf2dc"), "light": Color("#7be0a3"), "symbol": "circle"},
	"yellow": {"base": Color("#f5b70a"), "dark": Color("#b27f00"), "soft": Color("#ffeeb8"), "light": Color("#ffd968"), "symbol": "square"},
	"blue": {"base": Color("#3a7bf7"), "dark": Color("#1f4fb8"), "soft": Color("#d5e3ff"), "light": Color("#86adff"), "symbol": "diamond"},
}


static func player(color: String, key: String = "base") -> Color:
	return PLAYER[color][key]
