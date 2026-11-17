class_name QuestsScreen
extends AppScreen
## Daily and weekly quests (Phase 6.2, bottom tab "Görevler"): name, description,
## progress bar, progress / target, reward, state and the collect button. Progress
## is computed by the server from recorded online matches; collecting is a server
## call that pays each reward exactly once.

var status: StatusCard
var _box: VBoxContainer
var _timer_label: Label
var _busy := false


func _title() -> String:
	return tr("QUESTS_TITLE")


func _nav_tab() -> String:
	return "quests"


func _build() -> void:
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(_reload)
	_box = UiKit.vbox(UiTokens.S3)
	content.add_child(_box)
	Online.progress.changed.connect(_render)
	_reload()


func _process(_d: float) -> void:
	if _timer_label != null and is_instance_valid(_timer_label) and not Online.progress.quests.is_empty():
		_timer_label.text = tr("QUESTS_DAILY_RESETS") % _left(String(Online.progress.quests.get("daily_resets_at", "")))


func _reload() -> void:
	if Online.progress.quests.is_empty():
		status.loading(tr("QUESTS_LOADING"))
	var ok := await Online.progress.refresh_quests()
	if not is_inside_tree():
		return
	if ok:
		status.clear()
	elif Online.progress.last_error == "OFFLINE" or Online.progress.last_error == "NO_CONFIG":
		status.error(tr("PROFILE_OFFLINE"), tr("ONLINE_RETRY"))
	elif Online.progress.last_error == "SESSION_EXPIRED":
		status.error(tr("ACCOUNT_SESSION_EXPIRED"))
	else:
		status.error(tr("ONLINE_ERR_SERVER"), tr("ONLINE_RETRY"))
	_render()


func _render() -> void:
	if not is_inside_tree():
		return
	for c: Node in _box.get_children():
		c.queue_free()
	var q := Online.progress.quests
	if q.is_empty():
		return
	_box.add_child(wrapped(UiKit.label(tr("QUESTS_INFO"), "DimLabel")))
	var old: Array = q.get("unclaimed_old", [])
	if not old.is_empty():
		_section(tr("QUESTS_OLD"), "", old)
	_timer_label = UiKit.label("", "DimLabel")
	_section(tr("QUESTS_DAILY"), "", q.get("daily", []), _timer_label)
	_section(tr("QUESTS_WEEKLY"), tr("QUESTS_WEEKLY_RESETS") % _left(String(q.get("weekly_resets_at", ""))), q.get("weekly", []))


func _section(heading: String, sub: String, rows: Array, sub_label: Label = null) -> void:
	var head := UiKit.hbox(UiTokens.S2)
	var h := UiKit.label(heading, "H3Label")
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h)
	if sub_label != null:
		head.add_child(sub_label)
	elif sub != "":
		head.add_child(UiKit.label(sub, "DimLabel"))
	_box.add_child(head)
	if rows.is_empty():
		_box.add_child(wrapped(UiKit.label(tr("QUESTS_EMPTY"), "DimLabel")))
		return
	for row: Dictionary in rows:
		_box.add_child(_card(row))


func _card(q: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CreamCard"
	var col := UiKit.vbox(UiTokens.S1)
	panel.add_child(col)
	var top := UiKit.hbox(UiTokens.S2)
	var texts := UiKit.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UiKit.label(OnlineProgress.quest_title(q), "InkH3Label"))
	texts.add_child(wrapped(UiKit.label(OnlineProgress.quest_hint(q), "InkDimLabel")))
	top.add_child(texts)
	var rewards := UiKit.vbox(4)
	rewards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if int(q.get("gold", 0)) > 0:
		rewards.add_child(UiKit.chip(tr("REWARD_GOLD") % int(q["gold"]), Color(UiPalette.GOLD_300, 0.6), UiPalette.INK_900))
	if int(q.get("xp", 0)) > 0:
		rewards.add_child(UiKit.chip("+%d XP" % int(q["xp"]), Color(UiPalette.MANGO_500, 0.25), UiPalette.MANGO_700))
	top.add_child(rewards)
	col.add_child(top)
	var bar_row := UiKit.hbox(UiTokens.S2)
	var bar := XpBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_progress(0, int(q.get("progress", 0)), int(q.get("target", 1)))
	bar_row.add_child(bar)
	bar_row.add_child(UiKit.label("%d / %d" % [int(q.get("progress", 0)), int(q.get("target", 0))], "InkH3Label"))
	col.add_child(bar_row)
	if q.get("claimed", false):
		var done := UiKit.chip(tr("QUEST_CLAIMED"), Color(UiPalette.MINT_500, 0.25), UiPalette.INK_900)
		done.size_flags_horizontal = Control.SIZE_SHRINK_END
		col.add_child(done)
	elif q.get("completed", false):
		var b := UiKit.button(tr("QUEST_CLAIM"), "primary", "s")
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func() -> void: _claim(q, b))
		col.add_child(b)
	return panel


func _claim(q: Dictionary, b: Button) -> void:
	if _busy:
		return
	_busy = true
	b.disabled = true
	var r := await Online.progress.claim_quest(q)
	_busy = false
	if not is_inside_tree():
		return
	if not r["ok"]:
		if is_instance_valid(b):
			b.disabled = false
			b.text = tr("PROFILE_OFFLINE_SAVE") if r["error"] == "OFFLINE" else tr("ERR_GENERIC_SHORT")
		return
	reward_celebration(self, tr("QUEST_DONE_TITLE"), OnlineProgress.quest_title(q), r["data"])


## Celebration for any claimed reward: gold, XP and a level-up if it happened.
static func reward_celebration(host: Node, title: String, subtitle: String, d: Dictionary) -> void:
	var lines: Array = []
	if int(d.get("gold", 0)) > 0:
		lines.append(["bag", TranslationServer.translate("REWARD_GOLD") % int(d["gold"])])
	if int(d.get("xp", 0)) > 0:
		lines.append(["star", "+%d XP" % int(d["xp"])])
	var after := int(d.get("level_after", 0))
	if after > int(d.get("level_before", after)):
		lines.append(["medal", TranslationServer.translate("LEVEL_UP_TITLE") % after])
		if int(d.get("level_gold", 0)) > 0:
			lines.append(["bag", TranslationServer.translate("REWARD_GOLD") % int(d["level_gold"])])
	Celebration.pop(host, title, subtitle, lines)


## "5 sa 12 dk" until an ISO timestamp (server time).
func _left(iso: String) -> String:
	var t := MatchRow.unix(iso)
	if t <= 0:
		return ""
	var s := maxi(0, t - int(Time.get_unix_time_from_system()))
	if s >= 86400:
		return tr("TIME_DH") % [s / 86400, (s % 86400) / 3600]
	return tr("TIME_HM") % [s / 3600, (s % 3600) / 60]
