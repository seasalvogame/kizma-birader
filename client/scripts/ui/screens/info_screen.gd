class_name InfoScreen
extends AppScreen
## Honest "coming soon" screen for features that need the online backend
## (friends, store, quests, ranking, achievements, online match, private
## room). It says what the feature will be and what can be played now; it
## never shows fake data. Main tabs keep the bottom bar.

const KINDS := {
	"friends": {"icon": "friends", "tab": "friends"},
	"store": {"icon": "bag", "tab": "store"},
	"quests": {"icon": "quest", "tab": "quests"},
	"ranking": {"icon": "podium", "tab": "ranking"},
	"achievements": {"icon": "medal", "tab": ""},
	"online": {"icon": "globe", "tab": ""},
	"private": {"icon": "lock", "tab": ""},
}

var kind := "friends"


func _title() -> String:
	kind = String(params.get("kind", "friends"))
	return tr("INFO_%s_TITLE" % kind.to_upper())


func _nav_tab() -> String:
	return KINDS.get(String(params.get("kind", "friends")), {}).get("tab", "")


func _build() -> void:
	content.add_child(UiKit.spacer())
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(0, 220)
	var tex := UiTheme.icon(KINDS[kind]["icon"])
	badge.draw.connect(func() -> void:
		var c := Vector2(badge.size.x * 0.5, 110)
		badge.draw_circle(c, 104, Color(1, 1, 1, 0.06))
		badge.draw_circle(c, 84, Color(UiPalette.MANGO_500, 0.18))
		badge.draw_texture_rect(tex, Rect2(c - Vector2(56, 56), Vector2(112, 112)), false))
	content.add_child(badge)
	content.add_child(wrapped(UiKit.label(tr("INFO_%s_HEAD" % kind.to_upper()), "H2Label", HORIZONTAL_ALIGNMENT_CENTER)))
	content.add_child(wrapped(UiKit.label(tr("INFO_%s_BODY" % kind.to_upper()), "DimLabel", HORIZONTAL_ALIGNMENT_CENTER)))
	var chip := UiKit.chip(tr("INFO_STATUS"), Color(UiPalette.MANGO_500, 0.2), UiPalette.MANGO_300)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(chip)
	var col := card(tr("INFO_NOW"))
	col.add_child(wrapped(UiKit.label(tr("INFO_NOW_TEXT"), "InkBodyLabel")))
	var play := UiKit.button(tr("INFO_PLAY_PRACTICE"), "primary")
	play.mouse_filter = Control.MOUSE_FILTER_PASS
	play.pressed.connect(func() -> void: navigate.emit("setup", {"players": int(Settings.get_value("last_players")), "mode": "bots"}))
	col.add_child(play)
