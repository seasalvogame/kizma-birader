class_name OnlineQueueScreen
extends AppScreen
## 2-player online quick match: guest sign-in -> queue -> match found ->
## connect to the match -> the normal match screen (config.online).
## The server assigns the opposite colours; the client decides nothing.

var _status: Label
var _elapsed: Label
var _dice: Control
var _retry: Button
var _cancel: Button
var _mm: OnlineMatchmaking
var _started := 0
var _searching := false
var _phase := 0.0
var _left := false


func _title() -> String:
	return tr("ONLINE_TITLE")


func _build() -> void:
	content.add_child(UiKit.spacer())
	_dice = Control.new()
	_dice.custom_minimum_size = Vector2(0, 260)
	var tex: Texture2D = load("res://assets/dice/dice_5.svg")
	_dice.draw.connect(func() -> void:
		var c := Vector2(_dice.size.x * 0.5, 130)
		_dice.draw_circle(c, 118, Color(1, 1, 1, 0.05))
		_dice.draw_circle(c, 96, Color(UiPalette.MANGO_500, 0.16))
		_dice.draw_set_transform(c, sin(_phase * 2.2) * 0.35, Vector2.ONE * (1.0 + 0.04 * sin(_phase * 4.4)))
		_dice.draw_texture_rect(tex, Rect2(-64, -64, 128, 128), false)
		_dice.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE))
	content.add_child(_dice)
	_status = UiKit.label(tr("ONLINE_CONNECTING"), "H2Label", HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)
	_elapsed = UiKit.label("", "DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_elapsed)
	var info := card()
	info.add_child(wrapped(UiKit.label(tr("ONLINE_INFO"), "InkBodyLabel")))
	_retry = UiKit.button(tr("ONLINE_RETRY"), "primary", "l")
	_retry.pressed.connect(_start)
	_retry.hide()
	footer.add_child(_retry)
	_cancel = UiKit.button(tr("CANCEL"), "secondary", "l")
	_cancel.pressed.connect(func() -> void: back_requested.emit())
	footer.add_child(_cancel)
	tree_exiting.connect(_stop)
	_start()


func handle_back() -> bool:
	return false   # the router goes back; tree_exiting cancels the queue


func _process(delta: float) -> void:
	# The searching state remains explicit in copy and elapsed time.  The dice
	# becomes a stable status mark when the player asked for reduced motion.
	if not Settings.get_value("reduced_motion"):
		_phase += delta
		_dice.queue_redraw()
	elif _phase != 0.0:
		_phase = 0.0
		_dice.queue_redraw()
	if _searching:
		var s := (Time.get_ticks_msec() - _started) / 1000
		_elapsed.text = tr("ONLINE_ELAPSED") % ("%d:%02d" % [s / 60, s % 60])


func _start() -> void:
	_retry.hide()
	_status.text = tr("ONLINE_CONNECTING")
	_elapsed.text = ""
	_stop()
	_mm = OnlineMatchmaking.new()
	add_child(_mm)
	_mm.searching.connect(func() -> void:
		_searching = true
		_started = Time.get_ticks_msec()
		_status.text = tr("ONLINE_SEARCHING"))
	_mm.failed.connect(_on_failed)
	_mm.found.connect(_on_found)
	_mm.start(Online.session, Settings.display_name())


func _stop() -> void:
	_searching = false
	if _mm != null:
		_mm.cancel()
		_mm.queue_free()
		_mm = null


func _on_failed(code: String) -> void:
	_searching = false
	_elapsed.text = ""
	if code == "NETWORK" or code == "OFFLINE":
		_status.text = tr("ONLINE_ERR_NETWORK")
	elif code == "SESSION_EXPIRED":
		_status.text = tr("ACCOUNT_SESSION_EXPIRED")
	elif code.begins_with("AUTH") or code == "NO_CONFIG":
		_status.text = tr("ONLINE_ERR_AUTH")
	else:
		_status.text = tr("ONLINE_ERR_SERVER")
	_retry.show()


func _on_found(info: Dictionary) -> void:
	_searching = false
	_elapsed.text = ""
	_status.text = tr("ONLINE_FOUND")
	var conn := Online.new_match_connection()
	conn.open(Online.session, String(info["matchId"]))
	var timer := get_tree().create_timer(20.0)
	var result := {"snap": {}}
	var on_snap := func(p: Dictionary) -> void: result["snap"] = p
	conn.snapshot_received.connect(on_snap, CONNECT_ONE_SHOT)
	while (result["snap"] as Dictionary).is_empty() and timer.time_left > 0.0 and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		conn.close()
		return
	var snap: Dictionary = result["snap"]
	if snap.is_empty():
		conn.close()
		_on_failed("SERVER")
		return
	navigate.emit("match", {"config": match_config(snap, conn)})


## Match screen config from the server snapshot (seats, names, colours, my seat).
static func match_config(snap: Dictionary, conn: OnlineMatchConnection) -> Dictionary:
	var my_seat := int(snap.get("yourSeat", 0))
	var seats: Array = []
	for s: Dictionary in snap.get("seats", []):
		var seat := int(s["seat"])
		seats.append({
			"color": s["color"],
			"name": String(s.get("name", "")),
			"kind": "bot" if s.get("is_bot", false) else "human",
			"role": "you" if seat == my_seat else ("bot" if s.get("is_bot", false) else "remote"),
		})
	return {"players": seats.size(), "seats": seats, "online": {"connection": conn, "seat": my_seat, "snapshot": snap}}
