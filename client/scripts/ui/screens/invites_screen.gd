class_name InvitesScreen
extends AppScreen
## Incoming match invites (live): who invites, to a 2- or 4-player private room,
## time left. Accept = enter that room; decline = the inviter is told. Expired
## invites can no longer be accepted (the server decides).

var status: StatusCard
var _list: VBoxContainer
var _msg: Label
var _timers := {}     # invite id -> Label


func _title() -> String:
	return tr("INVITES_TITLE")


func _build() -> void:
	status = StatusCard.new()
	content.add_child(status)
	_msg = wrapped(UiKit.label("", "DimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(_msg)
	_list = UiKit.vbox(UiTokens.S2)
	content.add_child(_list)
	Online.hub.invites_changed.connect(_render)
	Online.hub.connection_changed.connect(func(_c: bool) -> void: _render())
	Online.start_social()
	_render()


func _process(_d: float) -> void:
	var now := Online.hub.server_now_ms()
	for inv: Dictionary in Online.hub.invites:
		var l: Label = _timers.get(inv["id"])
		if l != null and is_instance_valid(l):
			var left := int((float(inv["expires"]) - now) / 1000.0)
			l.text = tr("INVITE_LEFT") % maxi(0, left) if left > 0 else tr("INVITE_EXPIRED")


func _render() -> void:
	if not is_inside_tree():
		return
	for c: Node in _list.get_children():
		c.queue_free()
	_timers.clear()
	if not Online.hub.connected:
		if not Online.session.has_account():
			status.empty("chat", tr("INVITES_NEED_ACCOUNT"))
		else:
			status.loading(tr("INVITES_CONNECTING"))
		return
	var open := Online.hub.open_invites()
	if open.is_empty():
		status.empty("chat", tr("INVITES_EMPTY"))
		return
	status.clear()
	for inv: Dictionary in open:
		var row := PersonRow.new()
		row.person_name = "%s#%d" % [String(inv.get("fromName", "?")), int(inv.get("fromTag", 0))]
		row.avatar_id = String(inv.get("fromAvatar", "default"))
		row.subtitle = tr("INVITE_TO") % (tr("SETUP_TWO_PLAYERS") if int(inv.get("players", 2)) == 2 else tr("SETUP_FOUR_PLAYERS"))
		var acc := row.add_action(tr("JOIN"))
		var dec := row.add_action(tr("DECLINE"), "secondary")
		var id: String = inv["id"]
		acc.pressed.connect(func() -> void: await _answer(id, true, acc))
		dec.pressed.connect(func() -> void: await _answer(id, false, dec))
		_list.add_child(row)
		var t := UiKit.label("", "DimLabel", HORIZONTAL_ALIGNMENT_RIGHT)
		_list.add_child(t)
		_timers[id] = t


func _answer(id: String, accept: bool, b: Button) -> void:
	b.disabled = true
	var r := await Online.hub.answer_invite(id, accept)
	if not is_inside_tree():
		return
	if not r["ok"]:
		_msg.text = RoomLobbyScreen.error_text(r["error"])
		_render()
		return
	if accept:
		Online.enter_room(String(r["data"]["code"]))
		navigate.emit("room", {})
