class_name PlayerProfileScreen
extends AppScreen
## Another player's profile: name#tag, avatar, live status (friends only),
## online totals and the actions that fit the relation (add, accept, remove,
## block, invite to the player's private room).

var user_id := ""
var status: StatusCard
var _box: VBoxContainer
var _msg: Label
var info := {}


func _title() -> String:
	return tr("PLAYER_TITLE")


func _build() -> void:
	user_id = String(params.get("user_id", ""))
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(_reload)
	_box = UiKit.vbox(UiTokens.S3)
	content.add_child(_box)
	Online.hub.presence_changed.connect(func() -> void: if not info.is_empty(): _render())
	_reload()


func _reload() -> void:
	status.loading(tr("FRIENDS_LOADING"))
	var r := await Online.social.profile(user_id)
	if not is_inside_tree():
		return
	if not r["ok"]:
		if r["error"] == "NOT_FOUND":
			status.empty("person", tr("PLAYER_NOT_FOUND"))
		else:
			status.error(tr("PROFILE_OFFLINE") if r["error"] == "OFFLINE" else tr("ONLINE_ERR_SERVER"), tr("ONLINE_RETRY"))
		return
	status.clear()
	info = r["data"]
	_render()


func _render() -> void:
	for c: Node in _box.get_children():
		c.queue_free()
	var rel := String(info.get("relation", "none"))
	var top := UiKit.vbox(UiTokens.S1)
	var av := Avatar.new()
	av.custom_minimum_size = Vector2(176, 176)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	av.setup(String(info.get("display_name", "?")), "yellow", false)
	av.ring_color = UiPalette.CREAM_50
	av.set_fill(OnlineProfile.avatar_index(String(info.get("avatar_id", "default"))))
	top.add_child(av)
	top.add_child(UiKit.label(OnlineSocial.display(info), "H2Label", HORIZONTAL_ALIGNMENT_CENTER))
	if rel == "friend":
		var st := Online.hub.status_of(user_id)
		var chip := UiKit.chip(PersonRow.status_text(st), Color(PersonRow.status_color(st), 0.22), PersonRow.status_color(st))
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		top.add_child(chip)
	else:
		var chip2 := UiKit.chip(tr("REL_" + rel.to_upper()), Color(0, 0, 0, 0.3), UiPalette.ON_NIGHT_DIM)
		chip2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		top.add_child(chip2)
	_box.add_child(top)
	var stats_panel := PanelContainer.new()
	stats_panel.theme_type_variation = "CreamCard"
	var stats := UiKit.vbox(UiTokens.S2)
	stats_panel.add_child(stats)
	stats.add_child(UiKit.label(tr("PROFILE_ONLINE_STATS"), "InkH3Label"))
	var m := int(info.get("matches_2p", 0)) + int(info.get("matches_4p", 0))
	var w := int(info.get("wins_2p", 0)) + int(info.get("wins_4p", 0))
	for pair: Array in [[tr("STAT_MATCHES"), str(m)], [tr("STAT_WINS"), str(w)], [tr("STAT_RATE"), "–" if m == 0 else "%d%%" % roundi(100.0 * w / m)]]:
		var r := UiKit.hbox(UiTokens.S2)
		var k := UiKit.label(pair[0], "InkBodyLabel")
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(k)
		r.add_child(UiKit.label(pair[1], "InkH3Label"))
		stats.add_child(r)
	if info.get("friends_since") != null:
		stats.add_child(UiKit.label(tr("FRIENDS_SINCE") % MatchRow.when(String(info["friends_since"])), "InkDimLabel"))
	_box.add_child(stats_panel)
	_msg = wrapped(UiKit.label("", "DimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_box.add_child(_msg)
	var actions := UiKit.vbox(UiTokens.S2)
	_box.add_child(actions)
	match rel:
		"none":
			_action(actions, tr("FRIEND_ADD"), "primary", func() -> Dictionary: return await Online.social.send_request(user_id))
		"incoming":
			_action(actions, tr("FRIEND_ACCEPT"), "primary", func() -> Dictionary:
				var req := Online.social.incoming.filter(func(x: Dictionary) -> bool: return x["user_id"] == user_id)
				if req.is_empty():
					return await Online.social.send_request(user_id)   # their pending request -> accepted
				return await Online.social.respond(int(req[0]["id"]), user_id, true))
		"outgoing":
			var l := UiKit.label(tr("REQUEST_SENT"), "DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
			actions.add_child(l)
		"friend":
			if Online.room != null and Online.room.state.get("phase", "") == "lobby":
				_action(actions, tr("INVITE_TO_ROOM"), "primary", func() -> Dictionary: return await Online.hub.send_invite(user_id, Online.room.code))
			_action(actions, tr("FRIEND_REMOVE"), "secondary", func() -> Dictionary: return await Online.social.remove(user_id))
	_action(actions, tr("BLOCK"), "secondary", func() -> Dictionary:
		var r := await Online.social.block(user_id)
		if r["ok"]:
			back_requested.emit()
		return r)


func _action(parent: Control, text: String, kind: String, run: Callable) -> void:
	var b := UiKit.button(text, kind, "s")
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(func() -> void:
		b.disabled = true
		var r: Dictionary = await run.call()
		if not is_inside_tree():
			return
		if r["ok"]:
			if (r["data"] as Dictionary).has("invite"):
				_msg.text = tr("INVITE_SENT")
				b.disabled = false
				return
			await _reload()
		else:
			b.disabled = false
			_msg.text = RoomLobbyScreen.error_text(r["error"]) if text == tr("INVITE_TO_ROOM") else PlayerSearchScreen.social_error(r["error"]))
	parent.add_child(b)
