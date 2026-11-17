class_name PersonRow
extends Button
## A player in a list (friends, search, requests, invites, room): avatar, name#tag,
## a status / subtitle line with a coloured dot, and action buttons on the right.
## Cream card like the design system; tapping the row (outside the buttons) opens it.

var person_name := ""
var avatar_name := ""       # letter on the avatar (default: person_name)
var subtitle := ""
var avatar_id := "default"
var status := ""             # "online" | "room" | "match" | "offline" | "" (no dot)
var color := "yellow"        # avatar ring colour (room seat colour)
var actions: HBoxContainer

var _face := StyleBoxFlat.new()


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 132)
	actions = UiKit.hbox(UiTokens.S1)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _ready() -> void:
	_face.set_corner_radius_all(UiTokens.R_M)
	_face.border_width_bottom = 6
	_face.border_color = UiPalette.CREAM_300
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var row := UiKit.hbox(UiTokens.S2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var av := Avatar.new()
	av.custom_minimum_size = Vector2(88, 88)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.setup(avatar_name if avatar_name != "" else person_name, color, false)
	av.set_fill(OnlineProfile.avatar_index(avatar_id))
	row.add_child(av)
	var col := UiKit.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var n := UiKit.label(person_name, "InkH3Label")
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(n)
	if subtitle != "" or status != "":
		var sub := UiKit.hbox(8)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if status != "":
			var dot := Control.new()
			dot.custom_minimum_size = Vector2(18, 18)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var c := status_color(status)
			dot.draw.connect(func() -> void: dot.draw_circle(Vector2(9, 9), 8, c))
			sub.add_child(dot)
		var s := UiKit.label(subtitle, "InkDimLabel")
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_child(s)
		col.add_child(sub)
	row.add_child(col)
	row.add_child(actions)


## A small action button on the row.
func add_action(text: String, kind: String = "primary") -> Button:
	var b := UiKit.button(text, kind, "s")
	b.custom_minimum_size = Vector2(150, 76)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(b)
	return b


func _draw() -> void:
	var down := is_pressed() or get_draw_mode() == DRAW_PRESSED
	_face.bg_color = UiPalette.CREAM_200 if down else UiPalette.CREAM_100
	draw_style_box(_face, Rect2(Vector2.ZERO, size))


static func status_color(s: String) -> Color:
	match s:
		"online":
			return UiPalette.MINT_500
		"room":
			return UiPalette.MANGO_500
		"match":
			return Color("#3a7bf7")
		_:
			return Color("#b8aecb")


static func status_text(s: String) -> String:
	match s:
		"online":
			return TranslationServer.translate("STATUS_ONLINE")
		"room":
			return TranslationServer.translate("STATUS_ROOM")
		"match":
			return TranslationServer.translate("STATUS_MATCH")
		_:
			return TranslationServer.translate("STATUS_OFFLINE")
