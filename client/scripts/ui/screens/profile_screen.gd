class_name ProfileScreen
extends AppScreen
## Player profile (Phase 4): the server profile (name#tag, avatar), online
## stats and the last matches — all read from Supabase through RLS — plus name
## and avatar changes saved on the server (update_my_profile). Offline it shows
## the last known data, clearly marked. Practice stats of this device stay
## separate and never mix with online stats.

var avatar: Avatar
var name_edit: LineEdit
var status: StatusCard
var _status_label: Label
var _sections: VBoxContainer
var _fills: Array[Button] = []
var _saving := false


func _title() -> String:
	return tr("PROFILE_TITLE")


func _build() -> void:
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(_reload)
	_sections = UiKit.vbox(UiTokens.S3)
	content.add_child(_sections)
	_render()
	_reload()


func _reload() -> void:
	if Online.profile.loaded_at == 0:
		status.loading(tr("PROFILE_LOADING"))
	var ok := await Online.profile.refresh(5)
	if not is_inside_tree():
		return
	if ok:
		status.clear()
	elif Online.profile.loaded_at > 0:
		status.error(tr("PROFILE_OFFLINE_CACHED"), tr("ONLINE_RETRY"))
	elif Online.profile.last_error == "SESSION_EXPIRED":
		status.error(tr("ACCOUNT_SESSION_EXPIRED"), tr("ACCOUNT_OPEN"))
		status.action_pressed.connect(func() -> void: navigate.emit("account", {}), CONNECT_ONE_SHOT)
	else:
		status.error(tr("PROFILE_OFFLINE"), tr("ONLINE_RETRY"))
	_render()


func _render() -> void:
	for c: Node in _sections.get_children():
		c.queue_free()
	_fills.clear()
	var p := Online.profile
	var online := p.loaded_at > 0
	# --- identity
	var top := UiKit.vbox(UiTokens.S1)
	avatar = Avatar.new()
	avatar.custom_minimum_size = Vector2(176, 176)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar.setup(p.display_name(), "yellow", false)
	avatar.ring_color = UiPalette.CREAM_50
	avatar.set_fill(int(Settings.get_value("profile_avatar")))
	avatar.set_cosmetics(Online.cosmetics.equipped("frame"), Online.cosmetics.equipped("effect"))
	top.add_child(avatar)
	var name_line := UiKit.label(p.display_name() + (" #%d" % p.tag() if p.tag() > 0 else ""), "H2Label", HORIZONTAL_ALIGNMENT_CENTER)
	Cosmetics.style_name(name_line, Online.cosmetics.equipped("name"))
	top.add_child(name_line)
	var chip := UiKit.chip(_account_text(), Color(UiPalette.MINT_500, 0.2) if not Online.session.is_anonymous else Color(0, 0, 0, 0.3),
		UiPalette.MINT_500 if not Online.session.is_anonymous else UiPalette.ON_NIGHT_DIM)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(chip)
	_sections.add_child(top)
	# --- level and XP (server: my_progress)
	if online and not p.progress.is_empty():
		var lv := _card(tr("PROGRESS_LEVEL") % int(p.progress.get("level", 1)))
		var bar := XpBar.new()
		bar.set_progress(int(p.progress["level"]), int(p.progress["xp_in_level"]), int(p.progress["xp_for_next"]))
		lv.add_child(bar)
		var maxed := int(p.progress["xp_for_next"]) <= 0
		lv.add_child(UiKit.label(tr("PROGRESS_MAX") if maxed else tr("PROGRESS_XP") % [int(p.progress["xp_in_level"]), int(p.progress["xp_for_next"])], "InkBodyLabel"))
		if not maxed:
			lv.add_child(UiKit.label(tr("PROGRESS_NEXT_REWARD") % int(p.progress.get("next_level_gold", 0)), "InkDimLabel"))
		lv.add_child(UiKit.label(tr("PROGRESS_TOTAL") % int(p.progress["xp"]), "InkDimLabel"))
		var badges: Array = p.progress.get("badges", [])
		if not badges.is_empty():
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 8)
			var shown := String(p.progress.get("badge_id", "")) if p.progress.get("badge_id") != null else ""
			for b: String in badges:
				row.add_child(_badge_button(b, b == shown))
			lv.add_child(row)
			lv.add_child(UiKit.label(tr("BADGE_PICK_HINT"), "InkDimLabel"))
	# --- online stats
	var stats := _card(tr("PROFILE_ONLINE_STATS"))
	if online:
		var t := p.totals()
		var row := UiKit.hbox(UiTokens.S1)
		for pair: Array in [[str(t["matches"]), "STAT_MATCHES"], [str(t["wins"]), "STAT_WINS"], [str(t["losses"]), "STAT_LOSSES"],
				["–" if t["rate"] < 0 else "%d%%" % t["rate"], "STAT_RATE"]]:
			var cell := UiKit.vbox(0)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var v := UiKit.label(pair[0], "InkH2Label", HORIZONTAL_ALIGNMENT_CENTER)
			v.add_theme_color_override("font_color", UiPalette.MANGO_700)
			cell.add_child(v)
			cell.add_child(UiKit.label(tr(pair[1]), "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER))
			row.add_child(cell)
		stats.add_child(row)
		for mode: String in ["2p", "4p"]:
			var r := UiKit.hbox(UiTokens.S2)
			var l := UiKit.label(tr("STAT_" + mode.to_upper()), "InkBodyLabel")
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(l)
			r.add_child(UiKit.label(tr("PROFILE_MODE_LINE") % [int(p.stats.get("matches_" + mode, 0)), int(p.stats.get("wins_" + mode, 0))], "InkH3Label"))
			stats.add_child(r)
	else:
		stats.add_child(wrapped(UiKit.label(tr("PROFILE_NO_DATA"), "InkDimLabel")))
	# --- last matches
	var recent := _card(tr("PROFILE_RECENT"))
	if online and p.recent.is_empty():
		recent.add_child(wrapped(UiKit.label(tr("HISTORY_EMPTY"), "InkDimLabel")))
		var play := UiKit.button(tr("HISTORY_PLAY_ONLINE"), "primary", "s")
		play.mouse_filter = Control.MOUSE_FILTER_PASS
		play.pressed.connect(func() -> void: navigate.emit("queue", {}))
		recent.add_child(play)
	elif online:
		for m: Dictionary in p.recent:
			var row := MatchRow.new()
			row.info = m
			row.my_user_id = Online.session.user_id
			row.pressed.connect(func() -> void: navigate.emit("match_detail", {"match": m}))
			recent.add_child(row)
		var all := UiKit.button(tr("HISTORY_ALL"), "secondary", "s")
		all.mouse_filter = Control.MOUSE_FILTER_PASS
		all.pressed.connect(func() -> void: navigate.emit("history", {}))
		recent.add_child(all)
	else:
		recent.add_child(wrapped(UiKit.label(tr("PROFILE_NO_DATA"), "InkDimLabel")))
	# --- name and avatar (saved on the server)
	var name_card := _card(tr("PROFILE_NAME"))
	var row2 := UiKit.hbox(UiTokens.S2)
	name_edit = LineEdit.new()
	name_edit.text = p.display_name()
	name_edit.max_length = 16
	name_edit.editable = online
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(0, UiTokens.BUTTON_S)
	_style_edit(name_edit)
	name_edit.text_submitted.connect(func(_t: String) -> void: _save_name())
	row2.add_child(name_edit)
	var save := UiKit.button(tr("PROFILE_SAVE"), "primary", "s")
	save.custom_minimum_size = Vector2(176, UiTokens.BUTTON_S)
	save.mouse_filter = Control.MOUSE_FILTER_PASS
	save.disabled = not online
	save.pressed.connect(_save_name)
	row2.add_child(save)
	name_card.add_child(row2)
	_status_label = UiKit.label(tr("PROFILE_NAME_RULES") if online else tr("PROFILE_EDIT_ONLINE_ONLY"), "InkDimLabel")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_card.add_child(_status_label)
	var fills := _card(tr("PROFILE_AVATAR"))
	var swatches := UiKit.hbox(UiTokens.S2)
	swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in Avatar.FILLS.size():
		swatches.add_child(_swatch(i, online))
	fills.add_child(swatches)
	# --- practice stats of this device (offline, never mixed with online)
	var practice := _card(tr("PROFILE_STATS"))
	for mode: String in ["2p", "4p"]:
		var r := UiKit.hbox(UiTokens.S2)
		var l := UiKit.label(tr("STAT_" + mode.to_upper()), "InkBodyLabel")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(UiKit.label(tr("PROFILE_MODE_LINE") % [int(Settings.get_value("stats_matches_" + mode)), int(Settings.get_value("stats_wins_" + mode))], "InkH3Label"))
		practice.add_child(r)
	practice.add_child(wrapped(UiKit.label(tr("HOME_STATS_NOTE"), "InkDimLabel")))
	# --- account and achievements
	var account := MenuCard.new()
	account.wide = true
	account.icon_name = "lock"
	account.title = tr("ACCOUNT_TITLE")
	account.subtitle = _account_text()
	account.pressed.connect(func() -> void: navigate.emit("account", {}))
	_sections.add_child(account)
	var collection := MenuCard.new()
	collection.wide = true
	collection.icon_name = "bag"
	collection.title = tr("COLLECTION_TITLE")
	collection.subtitle = tr("COLLECTION_CARD_SUB")
	collection.pressed.connect(func() -> void: navigate.emit("collection", {}))
	_sections.add_child(collection)
	var achievements := MenuCard.new()
	achievements.wide = true
	achievements.icon_name = "medal"
	achievements.title = tr("INFO_ACHIEVEMENTS_TITLE")
	var waiting := Online.progress.achievements_claimable
	achievements.subtitle = tr("ACH_CARD_READY") % waiting if waiting > 0 else tr("ACH_CARD_SUB")
	achievements.badge = str(waiting) if waiting > 0 else ""
	achievements.pressed.connect(func() -> void: navigate.emit("achievements", {}))
	_sections.add_child(achievements)


func _account_text() -> String:
	var s := Online.session
	if not s.is_anonymous and s.email != "":
		return tr("ACCOUNT_STATE_EMAIL") % s.email
	if s.new_email != "":
		return tr("ACCOUNT_STATE_PENDING")
	return tr("ACCOUNT_STATE_GUEST")


func _card(heading: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CreamCard"
	var col := UiKit.vbox(UiTokens.S2)
	panel.add_child(col)
	col.add_child(UiKit.label(heading, "InkH3Label"))
	_sections.add_child(panel)
	return col


func _swatch(i: int, enabled: bool) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.custom_minimum_size = Vector2(88, 88)
	b.disabled = not enabled
	b.draw.connect(func() -> void:
		var c := b.size * 0.5
		if i == int(Settings.get_value("profile_avatar")):
			b.draw_circle(c, 42, UiPalette.MANGO_500)
		b.draw_circle(c, 34, Avatar.FILLS[i][1])
		b.draw_circle(c + Vector2(0, -6), 26, Avatar.FILLS[i][0]))
	b.pressed.connect(func() -> void: _save_avatar(i))
	_fills.append(b)
	return b


func _save_avatar(i: int) -> void:
	if _saving:
		return
	_saving = true
	var before := int(Settings.get_value("profile_avatar"))
	Settings.set_value("profile_avatar", i)    # optimistic; reverted on error
	avatar.set_fill(i)
	for s: Button in _fills:
		s.queue_redraw()
	var r := await Online.profile.update(null, "fill:%d" % i)
	_saving = false
	if not is_inside_tree():
		return
	if not r["ok"]:
		Settings.set_value("profile_avatar", before)
		avatar.set_fill(before)
		for s: Button in _fills:
			s.queue_redraw()
		_show_status(_error_text(r["error"]), true)


func _save_name() -> void:
	if _saving:
		return
	var n := name_edit.text.strip_edges()
	if not OnlineProfile.valid_name(n):
		_show_status(tr("PROFILE_NAME_INVALID_RULES"), true)
		return
	_saving = true
	_show_status(tr("PROFILE_SAVING"), false)
	var r := await Online.profile.update(n, null)
	_saving = false
	if not is_inside_tree():
		return
	if r["ok"]:
		name_edit.release_focus()
		_render()
		_show_status(tr("PROFILE_SAVED"), false)
	else:
		_show_status(_error_text(r["error"]), true)


func _error_text(code: String) -> String:
	match code:
		"NAME_INVALID":
			return tr("PROFILE_NAME_INVALID_RULES")
		"NAME_TAKEN":
			return tr("PROFILE_NAME_TAKEN")
		"OFFLINE":
			return tr("PROFILE_OFFLINE_SAVE")
		_:
			return tr("ONLINE_ERR_SERVER")


func _show_status(text: String, is_error: bool) -> void:
	if _status_label == null or not is_instance_valid(_status_label):
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color("#c03a3f") if is_error else UiPalette.INK_500)


static func _style_edit(e: LineEdit) -> void:
	e.add_theme_font_override("font", UiTheme.body_font(800))
	e.add_theme_font_size_override("font_size", UiTokens.BODY)
	e.add_theme_color_override("font_color", UiPalette.INK_900)
	e.add_theme_color_override("font_placeholder_color", UiPalette.INK_500)
	e.add_theme_color_override("font_uneditable_color", UiPalette.INK_500)
	e.add_theme_color_override("caret_color", UiPalette.MANGO_700)
	for state: String in ["normal", "focus", "read_only"]:
		var box := StyleBoxFlat.new()
		box.bg_color = UiPalette.CREAM_50 if state != "read_only" else UiPalette.CREAM_200
		box.border_color = UiPalette.MANGO_500 if state == "focus" else UiPalette.CREAM_300
		box.set_border_width_all(3)
		box.set_corner_radius_all(UiTokens.R_S)
		box.content_margin_left = 20
		box.content_margin_right = 20
		e.add_theme_stylebox_override(state, box)


## A badge chip that can be tapped to show it on the profile (tap the shown one to hide it).
func _badge_button(id: String, shown: bool) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = ("★ " if shown else "") + tr("BADGE_" + id.to_upper())
	b.add_theme_font_override("font", UiTheme.body_font(800))
	b.add_theme_font_size_override("font_size", UiTokens.LABEL)
	for st: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, UiPalette.INK_900 if shown else UiPalette.MANGO_700)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiPalette.MANGO_500 if shown else Color(UiPalette.MANGO_500, 0.18)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	for st: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func() -> void:
		var r := await Online.progress.set_badge("" if shown else id)
		if is_inside_tree() and r["ok"]:
			_render())
	return b

