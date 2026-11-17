class_name PlayerSearchScreen
extends AppScreen
## Find players by name ("Ayşe") or name#tag ("Ayşe#1234") and send friend
## requests. The server never returns the player themselves or blocked players.

var status: StatusCard
var _edit: LineEdit
var _list: VBoxContainer
var _busy := false


func _title() -> String:
	return tr("SEARCH_TITLE")


func _build() -> void:
	var box := card(tr("SEARCH_HINT_TITLE"))
	var row := UiKit.hbox(UiTokens.S2)
	_edit = LineEdit.new()
	_edit.placeholder_text = tr("SEARCH_HINT")
	_edit.max_length = 24
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.custom_minimum_size = Vector2(0, UiTokens.BUTTON_S)
	ProfileScreen._style_edit(_edit)
	_edit.text_submitted.connect(func(_t: String) -> void: _search())
	row.add_child(_edit)
	var go := UiKit.button(tr("SEARCH_GO"), "primary", "s")
	go.custom_minimum_size = Vector2(150, UiTokens.BUTTON_S)
	go.mouse_filter = Control.MOUSE_FILTER_PASS
	go.pressed.connect(_search)
	row.add_child(go)
	box.add_child(row)
	var me := Online.profile
	if me.tag() > 0:
		box.add_child(wrapped(UiKit.label(tr("SEARCH_YOUR_TAG") % ("%s#%d" % [me.display_name(), me.tag()]), "InkDimLabel")))
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(_search)
	_list = UiKit.vbox(UiTokens.S2)
	content.add_child(_list)


func _search() -> void:
	var q := _edit.text.strip_edges()
	if q.length() < 2 or _busy:
		status.empty("person", tr("SEARCH_TOO_SHORT"))
		return
	_busy = true
	status.loading(tr("SEARCH_LOADING"))
	for c: Node in _list.get_children():
		c.queue_free()
	var r := await Online.social.search(q)
	_busy = false
	if not is_inside_tree():
		return
	if not r["ok"]:
		status.error(tr("PROFILE_OFFLINE") if r["error"] == "OFFLINE" else tr("ONLINE_ERR_SERVER"), tr("ONLINE_RETRY"))
		return
	var rows: Array = r["data"]
	if rows.is_empty():
		status.empty("person", tr("SEARCH_EMPTY"))
		return
	status.clear()
	for p: Dictionary in rows:
		_list.add_child(_row(p))


func _row(p: Dictionary) -> PersonRow:
	var row := PersonRow.new()
	row.person_name = OnlineSocial.display(p)
	row.avatar_id = String(p.get("avatar_id", "default"))
	var uid: String = p["user_id"]
	var rel := String(p.get("relation", "none"))
	row.subtitle = tr("REL_" + rel.to_upper())
	if rel == "none":
		var add := row.add_action(tr("FRIEND_ADD"))
		add.pressed.connect(func() -> void: await _add(uid, add))
	elif rel == "incoming":
		var acc := row.add_action(tr("FRIEND_ACCEPT"))
		acc.pressed.connect(func() -> void: await _add(uid, acc))
	row.pressed.connect(func() -> void: navigate.emit("player", {"user_id": uid}))
	return row


func _add(uid: String, b: Button) -> void:
	b.disabled = true
	var r := await Online.social.send_request(uid)
	if not is_instance_valid(b):
		return
	if r["ok"]:
		b.text = tr("FRIEND_ADDED") if (r["data"] as Dictionary).get("status") == "accepted" else tr("REQUEST_SENT")
	else:
		b.disabled = false
		b.text = social_error(r["error"])


static func social_error(code: String) -> String:
	match code:
		"ALREADY_FRIENDS":
			return TranslationServer.translate("ERR_ALREADY_FRIENDS")
		"ALREADY_PENDING":
			return TranslationServer.translate("REQUEST_SENT")
		"NOT_ALLOWED":
			return TranslationServer.translate("ERR_NOT_ALLOWED")
		"FRIEND_LIMIT", "REQUEST_LIMIT":
			return TranslationServer.translate("ERR_LIMIT")
		"OFFLINE":
			return TranslationServer.translate("ERR_OFFLINE_SHORT")
		_:
			return TranslationServer.translate("ERR_GENERIC_SHORT")
