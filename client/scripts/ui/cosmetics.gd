class_name Cosmetics
extends RefCounted
## How every cosmetic looks (Phase 7), shared by the store, the collection, the profile
## and the match. Dice and pawn skins are SVG files (tools/make_cosmetics.py); board
## themes, frames, profile effects, name styles and emote bubbles are drawn here.
## Purely visual: nothing here can change the game.

const CATEGORIES := ["dice", "pawns", "board", "frame", "effect", "name", "emotes", "badge"]
const DEFAULTS := {"dice": "dice_classic", "pawns": "pawns_classic", "board": "board_classic", "frame": "frame_none",
	"effect": "effect_none", "name": "name_plain", "emotes": "emotes_classic"}

const RARITY_COLORS := {
	"common": Color("#9a90b0"),
	"rare": Color("#8b5cf6"),
	"epic": Color("#ec4899"),
	"legendary": Color("#f5b70a"),
}

## Board palettes: only the board, cells and stars change; player colours never do.
const BOARDS := {
	"board_classic": {"board": Color("#fff6e6"), "cell": Color("#ffffff"), "edge": Color("#ead7bb"), "star": Color("#ffd04a"), "star_edge": Color("#d49a00")},
	"board_mint": {"board": Color("#e3f6ec"), "cell": Color("#ffffff"), "edge": Color("#b5dec7"), "star": Color("#ffd04a"), "star_edge": Color("#c98f00")},
	"board_night": {"board": Color("#2d2350"), "cell": Color("#f6f0ff"), "edge": Color("#5b4a92"), "star": Color("#ffd04a"), "star_edge": Color("#fff3c4")},
	"board_sunset": {"board": Color("#ffd9b8"), "cell": Color("#fffaf3"), "edge": Color("#efb084"), "star": Color("#fff1a8"), "star_edge": Color("#c2410c")},
}

const EMOTE_PHRASES := {
	"emotes_classic": ["hello", "gg", "go", "wow"],
	"emotes_cheer": ["great", "lucky", "close", "thanks"],
	"emotes_star": ["star", "champ", "rematch", "amazing"],
}

static var _dice_cache := {}
static var _pawn_cache := {}


static func dice_face(skin: String, value: int) -> Texture2D:
	var key := "%s:%d" % [skin, value]
	if not _dice_cache.has(key):
		var path := "res://assets/dice/dice_%d.svg" % value
		if skin != "" and skin != "dice_classic":
			path = "res://assets/cosmetics/dice/%s/dice_%d.svg" % [skin.trim_prefix("dice_"), value]
		_dice_cache[key] = load(path) if ResourceLoader.exists(path) else load("res://assets/dice/dice_%d.svg" % value)
	return _dice_cache[key]


static func pawn_texture(skin: String, color: String) -> Texture2D:
	var key := "%s:%s" % [skin, color]
	if not _pawn_cache.has(key):
		var path := "res://assets/pawns/pawn_%s.svg" % color
		# The default set is a high-resolution PNG painting. SVG cosmetics remain
		# available as-is, and a missing PNG safely falls back to the old classic.
		if skin == "pawns_classic":
			var atelier := "res://assets/pawns/atelier_png/pawn_%s_atelier.png" % color
			if ResourceLoader.exists(atelier):
				path = atelier
		elif skin != "":
			path = "res://assets/cosmetics/pawns/%s/pawn_%s.svg" % [skin.trim_prefix("pawns_"), color]
		_pawn_cache[key] = load(path) if ResourceLoader.exists(path) else load("res://assets/pawns/pawn_%s.svg" % color)
	return _pawn_cache[key]


static func board_palette(id: String) -> Dictionary:
	return BOARDS.get(id, BOARDS["board_classic"])


## Draws an avatar frame around a circle (center c, radius r) on any CanvasItem.
static func draw_frame(ci: CanvasItem, id: String, c: Vector2, r: float, phase: float = 0.0) -> void:
	match id:
		"frame_mint":
			ci.draw_arc(c, r + 5, 0, TAU, 48, UiPalette.MINT_500, 5, true)
			ci.draw_arc(c, r + 12, 0, TAU, 48, Color(UiPalette.MINT_500, 0.5), 3, true)
		"frame_gold":
			ci.draw_arc(c, r + 7, 0, TAU, 56, Color("#b27f00"), 10, true)
			ci.draw_arc(c, r + 6, 0, TAU, 56, Color("#ffd04a"), 6, true)
			ci.draw_arc(c, r + 6, -2.4, -1.6, 12, Color(1, 1, 1, 0.8), 3, true)
		"frame_star":
			ci.draw_arc(c, r + 6, 0, TAU, 56, Color("#ffd04a"), 7, true)
			for i in 5:
				var a := -PI / 2 + TAU * i / 5.0 + phase * 0.2
				_star(ci, c + Vector2(cos(a), sin(a)) * (r + 7), r * 0.16, Color("#fff3c4"))
		"frame_champion":
			ci.draw_arc(c, r + 8, 0, TAU, 56, Color("#f08a24"), 12, true)
			ci.draw_arc(c, r + 8, 0, TAU, 56, Color("#ffd04a"), 6, true)
			_star(ci, c + Vector2(0, -(r + 10)), r * 0.28, Color("#ffd04a"))
		"frame_royal":
			for i in 3:
				ci.draw_arc(c, r + 5 + i * 4, 0, TAU, 56, [Color("#a855f7"), Color("#ffd04a"), Color("#a855f7")][i], 4, true)
			for i in 8:
				var a := TAU * i / 8.0 + phase * 0.3
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * (r + 9), 3.5, Color("#fff3c4"))


## Profile effect behind / around the avatar (cheap: a few circles, one phase value).
static func draw_effect(ci: CanvasItem, id: String, c: Vector2, r: float, phase: float) -> void:
	match id:
		"effect_sparkle":
			for i in 8:
				var a := TAU * i / 8.0 + phase * 0.6
				var rr := r * (1.45 + 0.08 * sin(phase * 3.0 + i))
				_star(ci, c + Vector2(cos(a), sin(a)) * rr, r * (0.07 + 0.03 * sin(phase * 4.0 + i)), Color("#fff3c4"))
		"effect_aurora":
			for i in 3:
				var k := 1.25 + 0.12 * i + 0.05 * sin(phase * 2.0 + i)
				ci.draw_circle(c, r * k, Color([Color("#5eead4"), Color("#a855f7"), Color("#f472b6")][i], 0.16))


## Name decorations: colour / outline / prefix of a name label.
static func style_name(label: Label, id: String) -> void:
	match id:
		"name_mango":
			label.add_theme_color_override("font_color", UiPalette.MANGO_500)
		"name_gold":
			label.add_theme_color_override("font_color", Color("#ffd04a"))
			label.add_theme_color_override("font_outline_color", Color("#7a4b00"))
			label.add_theme_constant_override("outline_size", 6)
		"name_star":
			label.text = "★ " + label.text + " ★"
			label.add_theme_color_override("font_color", Color("#ffe08a"))
			label.add_theme_color_override("font_outline_color", Color("#5b2a86"))
			label.add_theme_constant_override("outline_size", 6)


static func phrases(emote_set: String) -> Array:
	return EMOTE_PHRASES.get(emote_set, EMOTE_PHRASES["emotes_classic"])


static func item_name(id: String) -> String:
	return TranslationServer.translate("COS_" + id.to_upper())


static func item_desc(id: String) -> String:
	var key := "COS_" + id.to_upper() + "_DESC"
	var t := TranslationServer.translate(key)
	return t if t != key else ""


## Where an item comes from, for the collection ("level:15" -> "Seviye 15 ödülü").
static func source_text(source: String) -> String:
	var parts := source.split(":")
	var kind := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	match kind:
		"default":
			return TranslationServer.translate("COS_SRC_DEFAULT")
		"store":
			return TranslationServer.translate("COS_SRC_STORE")
		"level":
			return TranslationServer.translate("COS_SRC_LEVEL") % int(arg)
		"achievement":
			return TranslationServer.translate("COS_SRC_ACHIEVEMENT") % TranslationServer.translate("ACH_" + arg.to_upper())
		"quest":
			return TranslationServer.translate("COS_SRC_QUEST")
		"leaderboard":
			return TranslationServer.translate("COS_SRC_LEADERBOARD") % int(arg)
		"daily_login":
			return TranslationServer.translate("COS_SRC_LOGIN")
	return TranslationServer.translate("COS_SRC_REWARD")


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)
