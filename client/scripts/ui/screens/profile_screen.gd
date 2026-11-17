class_name ProfileScreen
extends AppScreen
## Local profile (offline): player name and avatar colour used in matches,
## real practice stats of this device, the account status (guest) and the
## way to achievements. Online accounts and linking arrive later.

var avatar: Avatar
var name_edit: LineEdit
var _status: Label
var _fills: Array[Button] = []


func _title() -> String:
	return tr("PROFILE_TITLE")


func _build() -> void:
	var top := UiKit.vbox(UiTokens.S2)
	avatar = Avatar.new()
	avatar.custom_minimum_size = Vector2(176, 176)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar.setup(Settings.display_name(), "yellow", false)
	avatar.ring_color = UiPalette.CREAM_50
	avatar.set_fill(int(Settings.get_value("profile_avatar")))
	top.add_child(avatar)
	var chip := UiKit.chip(tr("HOME_GUEST"))
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(chip)
	content.add_child(top)

	var name_card := card(tr("PROFILE_NAME"))
	var row := UiKit.hbox(UiTokens.S2)
	name_edit = LineEdit.new()
	name_edit.text = String(Settings.get_value("profile_name"))
	name_edit.placeholder_text = tr("DEFAULT_NAME")
	name_edit.max_length = 16
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(0, UiTokens.BUTTON_S)
	name_edit.add_theme_font_override("font", UiTheme.body_font(800))
	name_edit.add_theme_font_size_override("font_size", UiTokens.BODY)
	name_edit.add_theme_color_override("font_color", UiPalette.INK_900)
	name_edit.add_theme_color_override("font_placeholder_color", UiPalette.INK_500)
	name_edit.add_theme_color_override("caret_color", UiPalette.MANGO_700)
	for state: String in ["normal", "focus", "read_only"]:
		var box := StyleBoxFlat.new()
		box.bg_color = UiPalette.CREAM_50
		box.border_color = UiPalette.MANGO_500 if state == "focus" else UiPalette.CREAM_300
		box.set_border_width_all(3)
		box.set_corner_radius_all(UiTokens.R_S)
		box.content_margin_left = 20
		box.content_margin_right = 20
		name_edit.add_theme_stylebox_override(state, box)
	name_edit.text_submitted.connect(func(_t: String) -> void: _save_name())
	row.add_child(name_edit)
	var save := UiKit.button(tr("PROFILE_SAVE"), "primary", "s")
	save.custom_minimum_size = Vector2(176, UiTokens.BUTTON_S)
	save.mouse_filter = Control.MOUSE_FILTER_PASS
	save.pressed.connect(_save_name)
	row.add_child(save)
	name_card.add_child(row)
	_status = UiKit.label(tr("PROFILE_NAME_HINT"), "InkDimLabel")
	name_card.add_child(_status)

	var fills := card(tr("PROFILE_AVATAR"))
	var swatches := UiKit.hbox(UiTokens.S2)
	swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in Avatar.FILLS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.custom_minimum_size = Vector2(88, 88)
		var idx := i
		b.draw.connect(func() -> void:
			var c := b.size * 0.5
			if idx == int(Settings.get_value("profile_avatar")):
				b.draw_circle(c, 42, UiPalette.MANGO_500)
			b.draw_circle(c, 34, Avatar.FILLS[idx][1])
			b.draw_circle(c + Vector2(0, -6), 26, Avatar.FILLS[idx][0]))
		b.pressed.connect(func() -> void:
			Settings.set_value("profile_avatar", idx)
			avatar.set_fill(idx)
			for s: Button in _fills:
				s.queue_redraw())
		_fills.append(b)
		swatches.add_child(b)
	fills.add_child(swatches)

	var stats := card(tr("PROFILE_STATS"))
	for p: String in ["2p", "4p"]:
		var r := UiKit.hbox(UiTokens.S2)
		var label := UiKit.label(tr("STAT_" + p.to_upper()), "InkBodyLabel")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(label)
		var m := int(Settings.get_value("stats_matches_" + p))
		var w := int(Settings.get_value("stats_wins_" + p))
		r.add_child(UiKit.label("%d %s · %d %s" % [m, tr("STAT_MATCHES"), w, tr("STAT_WINS")], "InkH3Label"))
		stats.add_child(r)

	var achievements := MenuCard.new()
	achievements.wide = true
	achievements.icon_name = "medal"
	achievements.title = tr("INFO_ACHIEVEMENTS_TITLE")
	achievements.subtitle = tr("INFO_ACHIEVEMENTS_HEAD")
	achievements.soon = true
	achievements.pressed.connect(func() -> void: navigate.emit("info", {"kind": "achievements"}))
	content.add_child(achievements)

	var account := card(tr("PROFILE_ACCOUNT"))
	account.add_child(wrapped(UiKit.label(tr("PROFILE_ACCOUNT_GUEST"), "InkBodyLabel")))


func _save_name() -> void:
	var n := name_edit.text.strip_edges()
	if not Settings.valid_name(n):
		_status.text = tr("PROFILE_NAME_INVALID")
		_status.add_theme_color_override("font_color", Color("#c03a3f"))
		return
	Settings.set_value("profile_name", n)
	name_edit.release_focus()
	avatar.setup(n, "yellow", false)
	avatar.ring_color = UiPalette.CREAM_50
	avatar.set_fill(int(Settings.get_value("profile_avatar")))
	_status.text = tr("PROFILE_SAVED")
	_status.add_theme_color_override("font_color", UiPalette.MINT_500.darkened(0.3))
