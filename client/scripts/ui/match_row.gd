class_name MatchRow
extends Button
## One finished online match in a list (profile "last matches", history):
## place badge, result, opponents, mode and date. Cream card like the design
## system; tapping opens the match details.

var info := {}
var my_user_id := ""

var _face := StyleBoxFlat.new()


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 156)


func _ready() -> void:
	_face.bg_color = UiPalette.CREAM_100
	_face.set_corner_radius_all(UiTokens.R_M)
	_face.border_width_bottom = 6
	_face.border_color = UiPalette.CREAM_300
	var me := my_seat(info, my_user_id)
	var rank := int(me.get("rank", 0))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var row := UiKit.hbox(UiTokens.S2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(84, 84)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: String = String(me.get("color", "red"))
	badge.draw.connect(func() -> void:
		var c := badge.size * 0.5
		badge.draw_circle(c + Vector2(0, 3), 40, UiPalette.player(color, "dark"))
		badge.draw_circle(c, 40, UiPalette.player(color))
		var txt := "%d." % rank if rank > 0 else "–"
		var f := UiTheme.display_font()
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		badge.draw_string(f, c + Vector2(-w * 0.5, 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE))
	row.add_child(badge)
	var col := UiKit.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UiKit.label(result_text(info, rank), "InkH3Label")
	if rank == 1:
		title.add_theme_color_override("font_color", UiPalette.MANGO_700)
	col.add_child(title)
	var opp := UiKit.label(tr("HISTORY_VS") % opponents(info, my_user_id), "InkBodyLabel")
	opp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(opp)
	col.add_child(UiKit.label("%s · %s" % [tr("SETUP_TWO_PLAYERS") if int(info.get("players", 2)) == 2 else tr("SETUP_FOUR_PLAYERS"), when(String(info.get("ended_at", "")))], "InkDimLabel"))
	for l: Label in [title, opp]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var down := is_pressed() or get_draw_mode() == DRAW_PRESSED
	_face.bg_color = UiPalette.CREAM_200 if down else UiPalette.CREAM_100
	draw_style_box(_face, Rect2(Vector2.ZERO, size))


static func my_seat(m: Dictionary, user_id: String) -> Dictionary:
	for p: Dictionary in m.get("match_players", []):
		if String(p.get("user_id", "")) == user_id and user_id != "":
			return p
	return {}


static func result_text(m: Dictionary, rank: int) -> String:
	if rank == 1:
		return TranslationServer.translate("HISTORY_WIN")
	if String(m.get("end_reason", "")) == "left" and rank == int(m.get("players", 2)):
		return TranslationServer.translate("HISTORY_LEFT")
	return TranslationServer.translate("HISTORY_PLACE") % rank


static func opponents(m: Dictionary, user_id: String) -> String:
	var names: PackedStringArray = []
	for p: Dictionary in m.get("match_players", []):
		if String(p.get("user_id", "")) != user_id or user_id == "":
			names.append(player_name(p))
	return ", ".join(names)


static func player_name(p: Dictionary) -> String:
	var n := String(p.get("display_name", "")) if p.get("display_name") != null else ""
	if bool(p.get("is_bot", false)):
		return n if n != "" else "Bot"
	if n == "":
		return TranslationServer.translate("HISTORY_DELETED")
	return "%s#%d" % [n, int(p.get("tag", 0))] if p.get("tag") != null else n


## "17.11 · 21:40" in local time (from an ISO UTC timestamp).
static func when(iso: String) -> String:
	var t := unix(iso)
	if t <= 0:
		return ""
	var local: int = t + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%02d.%02d · %02d:%02d" % [d["day"], d["month"], d["hour"], d["minute"]]


static func unix(iso: String) -> int:
	if iso.length() < 19:
		return 0
	return int(Time.get_unix_time_from_datetime_string(iso.substr(0, 19)))


static func duration(m: Dictionary) -> String:
	var s := maxi(0, unix(String(m.get("ended_at", ""))) - unix(String(m.get("started_at", ""))))
	return TranslationServer.translate("HISTORY_DURATION") % [s / 60, s % 60]
