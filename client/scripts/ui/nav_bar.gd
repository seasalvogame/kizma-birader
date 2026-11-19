class_name NavBar
extends PanelContainer
## Bottom navigation of the main tabs (UI_SCREEN_SPECIFICATIONS §3): Home,
## Friends, Store, Quests, Ranking. Sits on the bottom edge and pads itself by
## the gesture-bar inset.

signal tab_selected(id: String)

const TABS := [
	["home", "home", "NAV_HOME"],
	["friends", "friends", "NAV_FRIENDS"],
	["store", "bag", "NAV_STORE"],
	["quests", "quest", "NAV_QUESTS"],
	["ranking", "podium", "NAV_RANKING"],
]

var current := "home"
var bottom_inset := 0.0
var buttons := {}
## Tabs with something waiting (e.g. a quest reward to collect): a small mango dot.
static var dots := {}


func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiPalette.NIGHT_800, 0.97)
	box.corner_radius_top_left = UiTokens.R_L
	box.corner_radius_top_right = UiTokens.R_L
	box.border_width_top = 2
	box.border_color = UiPalette.GLASS_EDGE
	box.content_margin_left = UiTokens.S1
	box.content_margin_right = UiTokens.S1
	box.content_margin_top = UiTokens.S1
	box.content_margin_bottom = UiTokens.S1 + bottom_inset
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 18
	add_theme_stylebox_override("panel", box)
	var row := UiKit.hbox(0)
	add_child(row)
	for t: Array in TABS:
		var id: String = t[0]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.text = tr(t[2])
		b.icon = UiTheme.icon(t[1])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 48)
		b.add_theme_font_override("font", UiTheme.body_font(800))
		b.add_theme_font_size_override("font_size", UiTokens.MICRO)
		b.custom_minimum_size = Vector2(0, 112)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var on := id == current
		var col := UiPalette.MANGO_300 if on else UiPalette.ON_NIGHT_DIM
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(state, col)
		for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(state, col)
		b.pressed.connect(func() -> void: tab_selected.emit(id))
		buttons[id] = b
		row.add_child(b)
		if on:
			var marker := Control.new()
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			marker.draw.connect(func() -> void:
				var w := marker.size.x
				marker.draw_line(Vector2(w * 0.5 - 22, 7), Vector2(w * 0.5 + 22, 7), UiPalette.MANGO_300, 4.0, true))
			b.add_child(marker)
		if dots.get(id, false):
			var dot := Control.new()
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			dot.draw.connect(func() -> void:
				dot.draw_circle(Vector2(dot.size.x * 0.5 + 30, 14), 10, UiPalette.MANGO_500))
			b.add_child(dot)
