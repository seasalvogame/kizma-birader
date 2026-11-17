class_name RoomLobbyScreen
extends AppScreen
## Private room lobby (live from the server): room code, players with colour,
## ready flag and host crown, colour choice, ready, start (host), invite friends,
## leave. When the host starts, every player goes into the normal online match
## screen of the same match. After the match the room is a lobby again.

const COLORS := ["red", "green", "yellow", "blue"]

var room: OnlineRoom
var status: StatusCard
var _box: VBoxContainer
var _msg: Label
var _ready_btn: Button
var _start_btn: Button
var _entering := false


func _title() -> String:
	return tr("ROOM_TITLE")


func _build() -> void:
	room = Online.room
	status = StatusCard.new()
	content.add_child(status)
	_box = UiKit.vbox(UiTokens.S3)
	content.add_child(_box)
	_msg = wrapped(UiKit.label("", "DimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(_msg)
	_ready_btn = UiKit.button(tr("ROOM_READY"), "secondary", "l")
	_ready_btn.pressed.connect(func() -> void: room.set_ready(not bool(room.me().get("ready", false))))
	footer.add_child(_ready_btn)
	_start_btn = UiKit.button(tr("ROOM_START"), "primary", "l")
	_start_btn.pressed.connect(func() -> void: room.start_match())
	footer.add_child(_start_btn)
	if room == null:
		status.empty("lock", tr("ROOM_NONE"))
		_ready_btn.hide()
		_start_btn.hide()
		return
	room.state_changed.connect(func(_s: Dictionary) -> void: _render())
	room.started.connect(_on_started)
	room.failed.connect(_on_failed)
	room.closed.connect(func(reason: String) -> void:
		Online.leave_room()
		status.empty("lock", tr("ROOM_CLOSED_TIMEOUT") if reason == "timeout" else tr("ROOM_CLOSED"))
		_clear())
	room.action_refused.connect(func(code: String) -> void: _say(error_text(code), true))
	room.connection_changed.connect(func(_c: bool) -> void: _render())
	Online.hub.presence_changed.connect(_render)
	Online.start_social()
	if room.state.is_empty():
		status.loading(tr("ROOM_CONNECTING"))
	_render()


func _clear() -> void:
	for c: Node in _box.get_children():
		c.queue_free()
	_ready_btn.hide()
	_start_btn.hide()


func _render() -> void:
	if not is_inside_tree() or room == null or room.state.is_empty():
		return
	if room.connected:
		status.clear()
	else:
		status.error(tr("ROOM_RECONNECTING"))
	for c: Node in _box.get_children():
		c.queue_free()
	var s := room.state
	var players := int(s.get("players", 2))
	var members: Array = s.get("members", [])
	# --- code card
	var code_panel := PanelContainer.new()
	code_panel.theme_type_variation = "CreamCard"
	var cc := UiKit.vbox(UiTokens.S1)
	code_panel.add_child(cc)
	cc.add_child(UiKit.label(tr("ROOM_CODE"), "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var code_l := UiKit.label(String(s.get("code", "")), "InkH2Label", HORIZONTAL_ALIGNMENT_CENTER)
	code_l.add_theme_color_override("font_color", UiPalette.MANGO_700)
	code_l.add_theme_font_size_override("font_size", 72)
	cc.add_child(code_l)
	cc.add_child(UiKit.label(tr("ROOM_INFO") % [tr("SETUP_TWO_PLAYERS") if players == 2 else tr("SETUP_FOUR_PLAYERS"), members.size(), players], "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var copy := UiKit.button(tr("ROOM_COPY"), "secondary", "s")
	copy.mouse_filter = Control.MOUSE_FILTER_PASS
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(String(s.get("code", "")))
		_say(tr("ROOM_COPIED"), false))
	cc.add_child(copy)
	_box.add_child(code_panel)
	# --- players
	_box.add_child(UiKit.label(tr("ROOM_PLAYERS"), "H3Label"))
	for m: Dictionary in members:
		var row := PersonRow.new()
		row.person_name = "%s#%d" % [String(m["name"]), int(m["tag"])]
		row.avatar_id = String(m.get("avatar", "default"))
		row.color = String(m["color"])
		var bits: PackedStringArray = [tr("COLOR_" + String(m["color"]).to_upper())]
		if m.get("host", false):
			bits.append(tr("ROOM_HOST"))
		if m["userId"] == Online.session.user_id:
			bits.append(tr("ROLE_YOU"))
		if not m.get("connected", true):
			bits.append(tr("ROOM_DISCONNECTED"))
		row.subtitle = " · ".join(bits)
		row.status = "online" if m.get("ready", false) or m.get("host", false) else ""
		var chip := UiKit.chip(tr("ROOM_IS_READY") if m.get("ready", false) else (tr("ROOM_HOST") if m.get("host", false) else tr("ROOM_NOT_READY")),
			Color(UiPalette.MINT_500, 0.25) if m.get("ready", false) else Color(0, 0, 0, 0.08),
			UiPalette.INK_900)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.actions.add_child(chip)
		_box.add_child(row)
	for i in players - members.size():
		var empty := UiKit.label(tr("ROOM_WAITING_SLOT"), "DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
		empty.custom_minimum_size = Vector2(0, 80)
		_box.add_child(empty)
	# --- colour choice
	var pick := PanelContainer.new()
	pick.theme_type_variation = "CreamCard"
	var pc := UiKit.vbox(UiTokens.S2)
	pick.add_child(pc)
	pc.add_child(UiKit.label(tr("ROOM_COLOR") if players == 4 else tr("ROOM_COLOR_2P"), "InkH3Label"))
	var swatches := UiKit.hbox(UiTokens.S2)
	swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	var mine := String(room.me().get("color", ""))
	var taken := members.filter(func(x: Dictionary) -> bool: return x["userId"] != Online.session.user_id).map(func(x: Dictionary) -> String: return x["color"])
	for c: String in COLORS:
		swatches.add_child(_swatch(c, c == mine, players == 4 and c in taken))
	pc.add_child(swatches)
	_box.add_child(pick)
	# --- invite friends (online friends who are not in the room)
	if s.get("phase", "") == "lobby" and members.size() < players:
		var inv := PanelContainer.new()
		inv.theme_type_variation = "CreamCard"
		var ic := UiKit.vbox(UiTokens.S2)
		inv.add_child(ic)
		ic.add_child(UiKit.label(tr("ROOM_INVITE_FRIENDS"), "InkH3Label"))
		var ids := members.map(func(x: Dictionary) -> String: return x["userId"])
		var shown := 0
		for f: Dictionary in Online.social.friends:
			var st := Online.hub.status_of(f["user_id"])
			if st == "offline" or f["user_id"] in ids:
				continue
			var row2 := PersonRow.new()
			row2.person_name = OnlineSocial.display(f)
			row2.avatar_id = String(f.get("avatar_id", "default"))
			row2.status = st
			row2.subtitle = PersonRow.status_text(st)
			var b := row2.add_action(tr("INVITE"))
			var uid: String = f["user_id"]
			b.pressed.connect(func() -> void:
				b.disabled = true
				var r := await Online.hub.send_invite(uid, room.code)
				if is_instance_valid(b):
					b.text = tr("INVITE_SENT") if r["ok"] else error_text(r["error"]))
			ic.add_child(row2)
			shown += 1
		if shown == 0:
			ic.add_child(wrapped(UiKit.label(tr("ROOM_NO_ONLINE_FRIENDS") if Online.social.loaded else tr("ROOM_FRIENDS_NOT_LOADED"), "InkDimLabel")))
		_box.add_child(inv)
	var leave := UiKit.button(tr("ROOM_LEAVE"), "secondary", "s")
	leave.add_theme_color_override("font_color", Color("#c03a3f"))
	leave.mouse_filter = Control.MOUSE_FILTER_PASS
	leave.pressed.connect(func() -> void:
		Online.leave_room()
		back_requested.emit())
	_box.add_child(leave)
	# --- footer
	var host := room.is_host()
	var all_ready := members.size() == players and members.all(func(x: Dictionary) -> bool: return x.get("host", false) or x.get("ready", false))
	_start_btn.visible = host
	_start_btn.disabled = not all_ready
	_ready_btn.visible = not host
	_ready_btn.text = tr("ROOM_NOT_READY_BTN") if room.me().get("ready", false) else tr("ROOM_READY")
	if host and not all_ready:
		_say(tr("ROOM_WAIT_FULL") if members.size() < players else tr("ROOM_WAIT_READY"), false)
	elif not host:
		_say(tr("ROOM_WAIT_HOST") if room.me().get("ready", false) else tr("ROOM_PRESS_READY"), false)
	else:
		_say(tr("ROOM_CAN_START"), false)
	if Online.social.friends.is_empty() and not Online.social.loaded:
		Online.social.refresh()


func _swatch(c: String, selected: bool, taken: bool) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.custom_minimum_size = Vector2(110, 110)
	b.disabled = taken
	b.tooltip_text = tr("COLOR_" + c.to_upper())
	b.draw.connect(func() -> void:
		var center := b.size * 0.5
		if selected:
			b.draw_circle(center, 50, UiPalette.MANGO_500)
		b.draw_circle(center + Vector2(0, 4), 40, UiPalette.player(c, "dark"))
		b.draw_circle(center, 40, Color(UiPalette.player(c), 0.35 if taken else 1.0)))
	b.pressed.connect(func() -> void: room.set_color(c))
	return b


func _on_started(info: Dictionary) -> void:
	if _entering:
		return
	_entering = true
	_say(tr("ROOM_STARTING"), false)
	var conn := Online.new_match_connection()
	conn.open(Online.session, String(info["matchId"]))
	var result := {"snap": {}}
	conn.snapshot_received.connect(func(p: Dictionary) -> void: result["snap"] = p, CONNECT_ONE_SHOT)
	var until := Time.get_ticks_msec() + 20000
	while (result["snap"] as Dictionary).is_empty() and Time.get_ticks_msec() < until and is_inside_tree():
		await get_tree().process_frame
	_entering = false
	if not is_inside_tree():
		return
	if (result["snap"] as Dictionary).is_empty():
		conn.close()
		_say(tr("ONLINE_ERR_SERVER"), true)
		return
	var config := OnlineQueueScreen.match_config(result["snap"], conn)
	config["online"]["room"] = room.code
	navigate.emit("match", {"config": config})


func _on_failed(code: String) -> void:
	Online.leave_room()
	room = null
	status.error(error_text(code))
	_clear()


func _say(t: String, is_error: bool) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", Color("#ff8e91") if is_error else UiPalette.ON_NIGHT_DIM)


static func error_text(code: String) -> String:
	var key := "ERR_" + code
	var t := TranslationServer.translate(key)
	return t if t != key else TranslationServer.translate("ERR_GENERIC")
