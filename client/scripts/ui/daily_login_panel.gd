class_name DailyLoginPanel
extends Control
## Daily login reward (Phase 6.3): the 7-day cycle with today's reward highlighted,
## the streak, and the collect button. The server decides everything (day, streak,
## once per TR day by the server clock); this panel only shows it and asks to claim.

signal finished

var status := {}
var _box: VBoxContainer
var _busy := false


static func open(host: Node, p_status: Dictionary) -> DailyLoginPanel:
	var p := DailyLoginPanel.new()
	p.status = p_status
	host.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 2500
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiPalette.NIGHT_900, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "CreamCard"
	card.custom_minimum_size = Vector2(640, 0)
	center.add_child(card)
	_box = UiKit.vbox(UiTokens.S2)
	card.add_child(_box)
	_render()
	if not Settings.get_value("reduced_motion"):
		card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.2)


func _render() -> void:
	for c: Node in _box.get_children():
		c.queue_free()
	var t := UiKit.label(tr("LOGIN_TITLE"), "InkH2Label", HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_color", UiPalette.MANGO_700)
	_box.add_child(t)
	var streak := int(status.get("streak", 0))
	_box.add_child(UiKit.label(tr("LOGIN_STREAK") % streak if streak > 0 else tr("LOGIN_INFO"), "InkBodyLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var can := bool(status.get("can_claim", false))
	var next := int(status.get("next_day", 1))
	var claimed_upto := next - 1 if can else int(status.get("claimed_today_day", next - 1))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for c: Dictionary in status.get("cycle", []):
		var day := int(c["day"])
		grid.add_child(_tile(c, day <= claimed_upto, can and day == next))
	var center := CenterContainer.new()
	center.add_child(grid)
	_box.add_child(center)
	if can:
		var b := UiKit.button(tr("LOGIN_CLAIM") % next, "primary", "l")
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func() -> void: _claim(b))
		_box.add_child(b)
	else:
		_box.add_child(UiKit.label(tr("LOGIN_COME_BACK"), "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_box.add_child(wrapped_label(tr("LOGIN_RULE")))
	var close := UiKit.button(tr("LOGIN_CLOSE"), "secondary", "s")
	close.mouse_filter = Control.MOUSE_FILTER_PASS
	close.pressed.connect(_close)
	_box.add_child(close)


func _tile(c: Dictionary, claimed: bool, today: bool) -> Control:
	var tile := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(UiTokens.R_S)
	sb.bg_color = UiPalette.MANGO_500 if today else (UiPalette.CREAM_200 if not claimed else Color(UiPalette.MINT_500, 0.35))
	sb.border_color = UiPalette.MANGO_700 if today else UiPalette.CREAM_300
	sb.set_border_width_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	tile.add_theme_stylebox_override("panel", sb)
	tile.custom_minimum_size = Vector2(132, 150)
	var col := UiKit.vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_child(col)
	var day := int(c["day"])
	col.add_child(UiKit.label(tr("LOGIN_DAY") % day, "InkDimLabel" if not today else "InkH3Label", HORIZONTAL_ALIGNMENT_CENTER))
	var icon := TextureRect.new()
	icon.texture = UiTheme.icon("check" if claimed else ("trophy" if day == 7 else ("bag" if c.has("gold") else "star")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(0, 44)
	icon.modulate = UiPalette.INK_900 if today else UiPalette.MANGO_700
	col.add_child(icon)
	var parts: PackedStringArray = []
	if c.has("gold"):
		parts.append(tr("LOGIN_GOLD") % int(c["gold"]))
	if c.has("xp"):
		parts.append("%d XP" % int(c["xp"]))
	var l := UiKit.label("\n".join(parts), "InkBodyLabel", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", 24)
	col.add_child(l)
	return tile


func wrapped_label(t: String) -> Label:
	var l := UiKit.label(t, "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _claim(b: Button) -> void:
	if _busy:
		return
	_busy = true
	b.disabled = true
	var r := await Online.progress.claim_login()
	_busy = false
	if not is_inside_tree():
		return
	if not r["ok"]:
		b.disabled = false
		b.text = tr("PROFILE_OFFLINE_SAVE") if r["error"] == "OFFLINE" else (tr("LOGIN_ALREADY") if r["error"] == "ALREADY_CLAIMED" else tr("ERR_GENERIC_SHORT"))
		return
	var d: Dictionary = r["data"]
	status = Online.progress.login
	_render()
	var lines: Array = []
	if int(d.get("gold", 0)) > 0:
		lines.append(["bag", tr("REWARD_GOLD") % int(d["gold"])])
	if int(d.get("xp", 0)) > 0:
		lines.append(["star", "+%d XP" % int(d["xp"])])
	if d.get("badge") != null:
		lines.append(["medal", tr("BADGE_" + String(d["badge"]).to_upper())])
	if int(d.get("level_after", 0)) > int(d.get("level_before", 0)):
		lines.append(["medal", tr("LEVEL_UP_TITLE") % int(d["level_after"])])
	Celebration.pop(get_parent(), tr("LOGIN_DONE") % int(d.get("day", 1)), tr("LOGIN_STREAK") % int(d.get("streak", 1)), lines)
	_close()


func _close() -> void:
	finished.emit()
	queue_free()
