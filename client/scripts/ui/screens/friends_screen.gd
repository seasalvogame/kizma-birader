class_name FriendsScreen
extends AppScreen
## Friends (Phase 5): friend list with live status (online / in a room / in a
## match / offline, pushed by the social hub), shortcuts to search, friend
## requests and match invites. All data from Supabase (RLS) — nothing faked.

var status: StatusCard
var _list: VBoxContainer
var _shortcuts: HBoxContainer
var _requests_card: MenuCard
var _invites_card: MenuCard


func _title() -> String:
	return tr("FRIENDS_TITLE")


func _nav_tab() -> String:
	return "friends"


func _build() -> void:
	_shortcuts = UiKit.hbox(UiTokens.S3)
	content.add_child(_shortcuts)
	var search := _tile("person", tr("SEARCH_TITLE"), tr("SEARCH_SUB"))
	search.pressed.connect(func() -> void: navigate.emit("search", {}))
	_requests_card = _tile("friends", tr("REQUESTS_TITLE"), "")
	_requests_card.pressed.connect(func() -> void: navigate.emit("requests", {}))
	_shortcuts.add_child(search)
	_shortcuts.add_child(_requests_card)
	_invites_card = MenuCard.new()
	_invites_card.wide = true
	_invites_card.icon_name = "chat"
	_invites_card.title = tr("INVITES_TITLE")
	_invites_card.tint = UiPalette.MANGO_500
	_invites_card.pressed.connect(func() -> void: navigate.emit("invites", {}))
	content.add_child(_invites_card)
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(_reload)
	_list = UiKit.vbox(UiTokens.S2)
	content.add_child(_list)
	Online.social.changed.connect(_render)
	Online.hub.presence_changed.connect(_render)
	Online.hub.invites_changed.connect(_update_counts)
	_update_counts()
	_reload()


func _tile(icon: String, title: String, sub: String) -> MenuCard:
	var t := MenuCard.new()
	t.icon_name = icon
	t.title = title
	t.subtitle = sub
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return t


func _update_counts() -> void:
	var n_inv := Online.hub.open_invites().size()
	_invites_card.subtitle = tr("INVITES_COUNT") % n_inv if n_inv > 0 else tr("INVITES_NONE")
	_invites_card.badge = str(n_inv) if n_inv > 0 else ""
	_invites_card.refresh()
	var n_req := Online.social.incoming.size()
	_requests_card.subtitle = tr("REQUESTS_COUNT") % n_req if n_req > 0 else tr("REQUESTS_NONE")
	_requests_card.badge = str(n_req) if n_req > 0 else ""
	_requests_card.refresh()


func _reload() -> void:
	if not Online.social.loaded:
		status.loading(tr("FRIENDS_LOADING"))
	var ok := await Online.social.refresh()
	if not is_inside_tree():
		return
	if ok:
		Online.start_social()
		status.clear()
	elif Online.social.last_error == "OFFLINE" or Online.social.last_error == "NO_CONFIG":
		status.error(tr("PROFILE_OFFLINE"), tr("ONLINE_RETRY"))
	elif Online.social.last_error == "SESSION_EXPIRED":
		status.error(tr("ACCOUNT_SESSION_EXPIRED"))
	else:
		status.error(tr("ONLINE_ERR_SERVER"), tr("ONLINE_RETRY"))
	_render()


func _render() -> void:
	if not is_inside_tree():
		return
	_update_counts()
	for c: Node in _list.get_children():
		c.queue_free()
	if not Online.social.loaded:
		return
	if Online.social.friends.is_empty():
		var empty := card(tr("FRIENDS_EMPTY_TITLE"))
		empty.get_parent().reparent(_list)
		empty.add_child(wrapped(UiKit.label(tr("FRIENDS_EMPTY"), "InkDimLabel")))
		var go := UiKit.button(tr("SEARCH_TITLE"), "primary", "s")
		go.mouse_filter = Control.MOUSE_FILTER_PASS
		go.pressed.connect(func() -> void: navigate.emit("search", {}))
		empty.add_child(go)
		return
	var head := UiKit.label(tr("FRIENDS_COUNT") % Online.social.friends.size(), "H3Label")
	_list.add_child(head)
	var order := {"match": 0, "room": 1, "online": 2, "offline": 3}
	var rows: Array = Online.social.friends.duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return order[Online.hub.status_of(a["user_id"])] < order[Online.hub.status_of(b["user_id"])])
	for f: Dictionary in rows:
		var st := Online.hub.status_of(f["user_id"])
		var row := PersonRow.new()
		row.person_name = OnlineSocial.display(f)
		row.avatar_id = String(f.get("avatar_id", "default"))
		row.status = st
		row.subtitle = PersonRow.status_text(st)
		var uid: String = f["user_id"]
		if Online.room != null and Online.room.state.get("phase", "") == "lobby" and st != "offline":
			var inv := row.add_action(tr("INVITE"), "primary")
			inv.pressed.connect(func() -> void: _invite(uid, inv))
		row.pressed.connect(func() -> void: navigate.emit("player", {"user_id": uid}))
		_list.add_child(row)


func _invite(uid: String, b: Button) -> void:
	b.disabled = true
	var r := await Online.hub.send_invite(uid, Online.room.code)
	if not is_instance_valid(b):
		return
	b.text = tr("INVITE_SENT") if r["ok"] else RoomLobbyScreen.error_text(r["error"])
