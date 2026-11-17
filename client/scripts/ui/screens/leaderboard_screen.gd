class_name LeaderboardScreen
extends AppScreen
## Weekly leaderboard (Phase 6.5, bottom tab "Sıralama"): my place and points, the top
## 100 of this week or last week (50 per page), countdown to the end of the week and
## how points are earned. Everything comes from the server; the client never sends a score.

const PAGE := 50

var status: StatusCard
var _box: VBoxContainer
var _list: VBoxContainer
var _more: Button
var _week := ""          # "" = this week
var _offset := 0
var _me := {}
var _tabs: HBoxContainer


func _title() -> String:
	return tr("LB_TITLE")


func _nav_tab() -> String:
	return "ranking"


func _build() -> void:
	_tabs = UiKit.hbox(UiTokens.S2)
	content.add_child(_tabs)
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(_reload)
	_box = UiKit.vbox(UiTokens.S2)
	content.add_child(_box)
	_list = UiKit.vbox(UiTokens.S2)
	content.add_child(_list)
	_more = UiKit.button(tr("HISTORY_MORE"), "secondary", "s")
	_more.mouse_filter = Control.MOUSE_FILTER_PASS
	_more.pressed.connect(_load_page)
	_more.hide()
	content.add_child(_more)
	var rules := card(tr("LB_RULES_TITLE"))
	rules.add_child(wrapped(UiKit.label(tr("LB_RULES"), "InkBodyLabel")))
	_render_tabs()
	_reload()


func _render_tabs() -> void:
	for c: Node in _tabs.get_children():
		c.queue_free()
	for pair: Array in [["", tr("LB_THIS_WEEK")], ["prev", tr("LB_LAST_WEEK")]]:
		var on: bool = (_week == "") == (pair[0] == "")
		var b := UiKit.button(pair[1], "primary" if on else "secondary", "s")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		var key: String = pair[0]
		b.pressed.connect(func() -> void:
			if key == "prev":
				_week = String(_me.get("previous_week", ""))
			else:
				_week = ""
			_render_tabs()
			_reload())
		_tabs.add_child(b)


func _reload() -> void:
	status.loading(tr("LB_LOADING"))
	for c: Node in _list.get_children():
		c.queue_free()
	for c: Node in _box.get_children():
		c.queue_free()
	_offset = 0
	var me := await Online.progress.leaderboard_me(_week)
	if not is_inside_tree():
		return
	if not me["ok"]:
		status.error(tr("PROFILE_OFFLINE") if me["error"] in ["OFFLINE", "NO_CONFIG"] else tr("ONLINE_ERR_SERVER"), tr("ONLINE_RETRY"))
		return
	_me = me["data"]
	_render_me()
	await _load_page()


func _render_me() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CreamCard"
	var col := UiKit.vbox(UiTokens.S1)
	panel.add_child(col)
	var row := UiKit.hbox(UiTokens.S2)
	var rank: Variant = _me.get("rank")
	var big := UiKit.label("#%d" % int(rank) if rank != null else "–", "InkH2Label")
	big.add_theme_font_size_override("font_size", 64)
	big.add_theme_color_override("font_color", UiPalette.MANGO_700)
	row.add_child(big)
	var texts := UiKit.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UiKit.label(tr("LB_MY_POINTS") % int(_me.get("points", 0)), "InkH3Label"))
	texts.add_child(UiKit.label(tr("LB_MY_LINE") % [int(_me.get("wins", 0)), int(_me.get("matches", 0)), int(_me.get("players", 0))], "InkDimLabel"))
	row.add_child(texts)
	col.add_child(row)
	if _week == "":
		col.add_child(UiKit.label(tr("LB_ENDS") % _left(String(_me.get("ends_at", ""))), "InkDimLabel"))
	if rank == null:
		col.add_child(wrapped(UiKit.label(tr("LB_NOT_RANKED"), "InkDimLabel")))
	var last: Variant = _me.get("last_reward")
	if last is Dictionary:
		var l: Dictionary = last
		var t := tr("LB_LAST_REWARD") % [int(l.get("rank", 0)), int(l.get("gold", 0))]
		col.add_child(UiKit.chip(t, Color(UiPalette.GOLD_300, 0.6), UiPalette.INK_900))
	_box.add_child(panel)


func _load_page() -> void:
	_more.disabled = true
	var r := await Online.progress.leaderboard_top(_week, PAGE, _offset)
	if not is_inside_tree():
		return
	_more.disabled = false
	if not r["ok"]:
		status.error(tr("PROFILE_OFFLINE") if r["error"] in ["OFFLINE", "NO_CONFIG"] else tr("ONLINE_ERR_SERVER"), tr("ONLINE_RETRY"))
		return
	var rows: Array = r["data"].get("rows", [])
	if rows.is_empty() and _offset == 0:
		status.empty("podium", tr("LB_EMPTY"))
		_more.hide()
		return
	status.clear()
	for x: Dictionary in rows:
		_list.add_child(_row(x))
	_offset += rows.size()
	_more.visible = rows.size() == PAGE and _offset < 100


func _row(x: Dictionary) -> PersonRow:
	var row := PersonRow.new()
	var rank := int(x.get("rank", 0))
	row.person_name = "%d. %s#%d" % [rank, String(x.get("display_name", "?")), int(x.get("tag", 0))]
	row.avatar_id = String(x.get("avatar_id", "default"))
	row.avatar_name = String(x.get("display_name", "?"))
	row.color = "yellow" if rank == 1 else ("blue" if rank == 2 else ("red" if rank == 3 else "green"))
	var bits: PackedStringArray = [tr("PROGRESS_LEVEL_SHORT") % int(x.get("level", 1)), tr("LB_WINS") % int(x.get("wins", 0))]
	if x.get("badge_id") != null:
		bits.append(tr("BADGE_" + String(x["badge_id"]).to_upper()))
	if x.get("me", false):
		bits.append(tr("ROLE_YOU"))
	row.subtitle = " · ".join(bits)
	var chip := UiKit.chip(tr("LB_POINTS") % int(x.get("points", 0)), UiPalette.MANGO_500 if x.get("me", false) else Color(UiPalette.MANGO_500, 0.22),
		UiPalette.INK_900)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.actions.add_child(chip)
	var uid := String(x.get("user_id", ""))
	if not x.get("me", false):
		row.pressed.connect(func() -> void: navigate.emit("player", {"user_id": uid}))
	return row


func _left(iso: String) -> String:
	var t := MatchRow.unix(iso)
	if t <= 0:
		return ""
	var s := maxi(0, t - int(Time.get_unix_time_from_system()))
	if s >= 86400:
		return tr("TIME_DH") % [s / 86400, (s % 86400) / 3600]
	return tr("TIME_HM") % [s / 3600, (s % 3600) / 60]
