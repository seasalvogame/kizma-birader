class_name AchievementsScreen
extends AppScreen
## Achievements (Phase 6.4): long-term goals computed by the server from recorded
## online matches. Three looks: reached and waiting to be collected (mango, collect
## button), collected (mint check), still open (dimmed with progress).

const CATEGORIES := ["match", "skill", "social"]

var status: StatusCard
var _box: VBoxContainer
var _busy := false


func _title() -> String:
	return tr("ACH_TITLE")


func _build() -> void:
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(_reload)
	_box = UiKit.vbox(UiTokens.S3)
	content.add_child(_box)
	Online.progress.changed.connect(_render)
	_reload()


func _reload() -> void:
	if Online.progress.achievements.is_empty():
		status.loading(tr("ACH_LOADING"))
	var ok := await Online.progress.refresh_achievements()
	if not is_inside_tree():
		return
	if ok:
		status.clear()
	elif Online.progress.last_error == "OFFLINE" or Online.progress.last_error == "NO_CONFIG":
		status.error(tr("PROFILE_OFFLINE"), tr("ONLINE_RETRY"))
	else:
		status.error(tr("ONLINE_ERR_SERVER"), tr("ONLINE_RETRY"))
	_render()


func _render() -> void:
	if not is_inside_tree():
		return
	for c: Node in _box.get_children():
		c.queue_free()
	var list: Array = Online.progress.achievements.get("achievements", [])
	if list.is_empty():
		return
	var done := list.filter(func(a: Dictionary) -> bool: return a.get("completed", false)).size()
	_box.add_child(UiKit.label(tr("ACH_SUMMARY") % [done, list.size()], "DimLabel"))
	for cat: String in CATEGORIES:
		var rows := list.filter(func(a: Dictionary) -> bool: return a.get("category", "") == cat)
		if rows.is_empty():
			continue
		_box.add_child(UiKit.label(tr("ACH_CAT_" + cat.to_upper()), "H3Label"))
		# waiting rewards first, then open ones, collected last
		rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return _order(x) < _order(y))
		for a: Dictionary in rows:
			_box.add_child(_card(a))


static func _order(a: Dictionary) -> int:
	if a.get("completed", false) and not a.get("claimed", false):
		return 0
	return 2 if a.get("claimed", false) else 1


func _card(a: Dictionary) -> PanelContainer:
	var completed: bool = a.get("completed", false)
	var claimed: bool = a.get("claimed", false)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CreamCard"
	if not completed:
		panel.modulate = Color(1, 1, 1, 0.82)
	var col := UiKit.vbox(UiTokens.S1)
	panel.add_child(col)
	var top := UiKit.hbox(UiTokens.S2)
	var icon := TextureRect.new()
	icon.texture = UiTheme.icon("check" if claimed else ("trophy" if completed else "lock"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(64, 64)
	icon.modulate = UiPalette.MINT_500.darkened(0.2) if claimed else (UiPalette.MANGO_700 if completed else UiPalette.INK_500)
	top.add_child(icon)
	var texts := UiKit.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UiKit.label(tr("ACH_" + String(a["id"]).to_upper()), "InkH3Label"))
	var desc := UiKit.label(tr("ACH_" + String(a["id"]).to_upper() + "_DESC"), "InkDimLabel")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc)
	top.add_child(texts)
	var rewards := UiKit.vbox(4)
	rewards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if int(a.get("gold", 0)) > 0:
		rewards.add_child(UiKit.chip(tr("REWARD_GOLD") % int(a["gold"]), Color(UiPalette.GOLD_300, 0.6), UiPalette.INK_900))
	if int(a.get("xp", 0)) > 0:
		rewards.add_child(UiKit.chip("+%d XP" % int(a["xp"]), Color(UiPalette.MANGO_500, 0.25), UiPalette.MANGO_700))
	if a.has("badge"):
		rewards.add_child(UiKit.chip(tr("ACH_BADGE") % tr("BADGE_" + String(a["badge"]).to_upper()), Color(UiPalette.MINT_500, 0.25), UiPalette.INK_900))
	top.add_child(rewards)
	col.add_child(top)
	if not completed:
		var row := UiKit.hbox(UiTokens.S2)
		var bar := XpBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.set_progress(0, int(a.get("progress", 0)), int(a.get("target", 1)))
		row.add_child(bar)
		row.add_child(UiKit.label("%d / %d" % [int(a.get("progress", 0)), int(a.get("target", 0))], "InkH3Label"))
		col.add_child(row)
	elif not claimed:
		var b := UiKit.button(tr("QUEST_CLAIM"), "primary", "s")
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func() -> void: _claim(a, b))
		col.add_child(b)
	else:
		var chip := UiKit.chip(tr("QUEST_CLAIMED"), Color(UiPalette.MINT_500, 0.25), UiPalette.INK_900)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_END
		col.add_child(chip)
	return panel


func _claim(a: Dictionary, b: Button) -> void:
	if _busy:
		return
	_busy = true
	b.disabled = true
	var r := await Online.progress.claim_achievement(String(a["id"]))
	_busy = false
	if not is_inside_tree():
		return
	if not r["ok"]:
		if is_instance_valid(b):
			b.disabled = false
			b.text = tr("PROFILE_OFFLINE_SAVE") if r["error"] == "OFFLINE" else tr("ERR_GENERIC_SHORT")
		return
	var d: Dictionary = r["data"]
	QuestsScreen.reward_celebration(self, tr("ACH_DONE_TITLE"), tr("ACH_" + String(a["id"]).to_upper()), d)
	if d.get("badge") != null:
		_box.add_child(UiKit.label(tr("ACH_BADGE_HINT"), "DimLabel"))
