class_name PrivateRoomScreen
extends AppScreen
## Private room entry: create a 2- or 4-player room, join one with its code, or
## return to the room the player is already in.

var status: StatusCard
var _code: LineEdit
var _msg: Label
var _busy := false


func _title() -> String:
	return tr("PRIVATE_TITLE")


func _build() -> void:
	status = StatusCard.new()
	content.add_child(status)
	if Online.room != null:
		var back_card := card(tr("PRIVATE_IN_ROOM"))
		back_card.add_child(UiKit.label(tr("ROOM_CODE") + ": " + Online.room.code, "InkH3Label"))
		var go := UiKit.button(tr("PRIVATE_BACK_TO_ROOM"), "primary", "s")
		go.mouse_filter = Control.MOUSE_FILTER_PASS
		go.pressed.connect(func() -> void: navigate.emit("room", {}))
		back_card.add_child(go)
	var create := card(tr("PRIVATE_CREATE"))
	create.add_child(wrapped(UiKit.label(tr("PRIVATE_CREATE_INFO"), "InkDimLabel")))
	var row := UiKit.hbox(UiTokens.S2)
	for n: int in [2, 4]:
		var b := UiKit.button(tr("SETUP_TWO_PLAYERS") if n == 2 else tr("SETUP_FOUR_PLAYERS"), "primary", "s")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func() -> void: _create(n))
		row.add_child(b)
	create.add_child(row)
	var join := card(tr("PRIVATE_JOIN"))
	join.add_child(wrapped(UiKit.label(tr("PRIVATE_JOIN_INFO"), "InkDimLabel")))
	var jr := UiKit.hbox(UiTokens.S2)
	_code = LineEdit.new()
	_code.placeholder_text = "ABC234"
	_code.max_length = 7
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size = Vector2(0, UiTokens.BUTTON_S)
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	ProfileScreen._style_edit(_code)
	_code.add_theme_font_size_override("font_size", UiTokens.H2)
	_code.text_changed.connect(func(t: String) -> void:
		var up := OnlineRoom.normalize(t)
		if up != t:
			_code.text = up
			_code.caret_column = up.length())
	_code.text_submitted.connect(func(_t: String) -> void: _join())
	jr.add_child(_code)
	var jb := UiKit.button(tr("JOIN"), "primary", "s")
	jb.custom_minimum_size = Vector2(170, UiTokens.BUTTON_S)
	jb.mouse_filter = Control.MOUSE_FILTER_PASS
	jb.pressed.connect(_join)
	jr.add_child(jb)
	join.add_child(jr)
	_msg = wrapped(UiKit.label("", "InkDimLabel"))
	join.add_child(_msg)
	var invites := MenuCard.new()
	invites.wide = true
	invites.icon_name = "chat"
	invites.title = tr("INVITES_TITLE")
	invites.subtitle = tr("PRIVATE_INVITES_SUB")
	invites.pressed.connect(func() -> void: navigate.emit("invites", {}))
	content.add_child(invites)
	Online.start_social()


func _create(players: int) -> void:
	if _busy:
		return
	_busy = true
	status.loading(tr("PRIVATE_CREATING"))
	var r := await OnlineRoom.create(Online.api, players)
	_busy = false
	if not is_inside_tree():
		return
	if r["ok"]:
		status.clear()
		Online.enter_room(r["code"])
		Online.start_social()
		navigate.emit("room", {})
	elif r["error"] == "ALREADY_IN_ROOM" and r["code"] != "":
		status.clear()
		Online.enter_room(r["code"])      # back into the room this player is already in
		navigate.emit("room", {})
	else:
		status.error(RoomLobbyScreen.error_text(r["error"]), "")


func _join() -> void:
	var c := OnlineRoom.normalize(_code.text)
	if not OnlineRoom.valid_code(c):
		_say(tr("ROOM_CODE_INVALID"))
		return
	Online.enter_room(c)
	Online.start_social()
	navigate.emit("room", {})


func _say(t: String) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", Color("#c03a3f"))
