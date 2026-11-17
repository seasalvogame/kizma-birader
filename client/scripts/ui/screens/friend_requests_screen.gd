class_name FriendRequestsScreen
extends AppScreen
## Incoming friend requests (accept / decline), sent requests (cancel) and the
## players this player has blocked (unblock). Updated live by the social hub.

var status: StatusCard
var _box: VBoxContainer


func _title() -> String:
	return tr("REQUESTS_TITLE")


func _build() -> void:
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(_reload)
	_box = UiKit.vbox(UiTokens.S2)
	content.add_child(_box)
	Online.social.changed.connect(_render)
	_reload()


func _reload() -> void:
	status.loading(tr("FRIENDS_LOADING"))
	var ok := await Online.social.refresh()
	await Online.social.refresh_blocks()
	if not is_inside_tree():
		return
	if ok:
		status.clear()
	else:
		status.error(tr("PROFILE_OFFLINE") if Online.social.last_error == "OFFLINE" else tr("ONLINE_ERR_SERVER"), tr("ONLINE_RETRY"))
	_render()


func _render() -> void:
	if not is_inside_tree():
		return
	for c: Node in _box.get_children():
		c.queue_free()
	if not Online.social.loaded:
		return
	_section(tr("REQUESTS_IN"), Online.social.incoming, tr("REQUESTS_IN_EMPTY"), func(row: PersonRow, r: Dictionary) -> void:
		var acc := row.add_action(tr("FRIEND_ACCEPT"))
		var dec := row.add_action(tr("DECLINE"), "secondary")
		acc.pressed.connect(func() -> void: await _act(acc, func() -> Dictionary: return await Online.social.respond(int(r["id"]), r["user_id"], true)))
		dec.pressed.connect(func() -> void: await _act(dec, func() -> Dictionary: return await Online.social.respond(int(r["id"]), r["user_id"], false))))
	_section(tr("REQUESTS_OUT"), Online.social.outgoing, tr("REQUESTS_OUT_EMPTY"), func(row: PersonRow, r: Dictionary) -> void:
		var cancel := row.add_action(tr("CANCEL"), "secondary")
		cancel.pressed.connect(func() -> void: await _act(cancel, func() -> Dictionary: return await Online.social.cancel(int(r["id"]), r["user_id"]))))
	_section(tr("BLOCKED_TITLE"), Online.social.blocked, tr("BLOCKED_EMPTY"), func(row: PersonRow, r: Dictionary) -> void:
		var un := row.add_action(tr("UNBLOCK"), "secondary")
		un.pressed.connect(func() -> void:
			await _act(un, func() -> Dictionary: return await Online.social.unblock(r["user_id"]))
			_render()))


func _section(heading: String, rows: Array, empty_text: String, decorate: Callable) -> void:
	_box.add_child(UiKit.label(heading + ("  (%d)" % rows.size() if rows.size() > 0 else ""), "H3Label"))
	if rows.is_empty():
		var l := wrapped(UiKit.label(empty_text, "DimLabel"))
		_box.add_child(l)
		return
	for r: Dictionary in rows:
		var row := PersonRow.new()
		row.person_name = OnlineSocial.display(r)
		row.avatar_id = String(r.get("avatar_id", "default"))
		row.subtitle = MatchRow.when(String(r.get("created_at", "")))
		decorate.call(row, r)
		var uid: String = r["user_id"]
		row.pressed.connect(func() -> void: navigate.emit("player", {"user_id": uid}))
		_box.add_child(row)


func _act(b: Button, run: Callable) -> void:
	b.disabled = true
	var r: Dictionary = await run.call()
	if is_instance_valid(b) and not r["ok"]:
		b.disabled = false
		b.text = PlayerSearchScreen.social_error(r["error"])
