class_name MatchHistoryScreen
extends AppScreen
## All finished online matches of the player (server data via RLS), newest
## first, 20 per page. Loading / error / empty states; no practice matches.

const PAGE := 20

var status: StatusCard
var _list: VBoxContainer
var _more: Button
var _last_end := ""
var _loading := false


func _title() -> String:
	return tr("HISTORY_TITLE")


func _build() -> void:
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(func() -> void:
		if _list.get_child_count() == 0 and _last_end == "" and status._button.text == tr("HISTORY_PLAY_ONLINE"):
			navigate.emit("queue", {})
		else:
			_load_page())
	_list = UiKit.vbox(UiTokens.S2)
	content.add_child(_list)
	_more = UiKit.button(tr("HISTORY_MORE"), "secondary", "s")
	_more.mouse_filter = Control.MOUSE_FILTER_PASS
	_more.pressed.connect(_load_page)
	_more.hide()
	content.add_child(_more)
	_load_page()


func _load_page() -> void:
	if _loading:
		return
	_loading = true
	_more.disabled = true
	if _list.get_child_count() == 0:
		status.loading(tr("HISTORY_LOADING"))
	var r := await Online.profile.history(PAGE, _last_end)
	_loading = false
	if not is_inside_tree():
		return
	_more.disabled = false
	if not r["ok"]:
		if _list.get_child_count() == 0:
			status.error(tr("PROFILE_OFFLINE") if r["error"] == "OFFLINE" else tr("ONLINE_ERR_SERVER"), tr("ONLINE_RETRY"))
		return
	var rows: Array = r["data"]
	if rows.is_empty() and _list.get_child_count() == 0:
		status.empty("podium", tr("HISTORY_EMPTY"), tr("HISTORY_PLAY_ONLINE"))
		_more.hide()
		return
	status.clear()
	for m: Dictionary in rows:
		var row := MatchRow.new()
		row.info = m
		row.my_user_id = Online.session.user_id
		row.pressed.connect(func() -> void: navigate.emit("match_detail", {"match": m}))
		_list.add_child(row)
		_last_end = String(m.get("ended_at", ""))
	_more.visible = rows.size() == PAGE
