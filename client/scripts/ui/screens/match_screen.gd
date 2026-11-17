class_name MatchScreen
extends Control
## Active match (UI_SCREEN_SPECIFICATIONS §14, §15). Shows the state of
## MatchController and animates its events; no rules here.
## 4 players: cards in the board's corners next to their yards (rotation
## aware); 2 players: full-width cards above and below. Dice pad and hint at
## the bottom. Menu sheet, confirmation and result overlays.

signal exit_requested
signal restart_requested
## The match reached game over (emitted once, before the result overlay).
signal match_over(state: Dictionary)

var config := {}
var controller: MatchController
var board_view: BoardView
var dice: DiceView
var cards := {}          # seat -> PlayerCard
var card_dice := {}      # seat -> DiceView (small)
var pawns := {}          # "color:i" -> PawnSprite
var local_seat := 0
var two_players := false

var _top_bar: Control
var _menu_button: Button
var _mode_chip: Control
var _hint: PanelContainer
var _hint_label: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_queue: Array[String] = []
var _toast_busy := false
var _overlay: Control
var _closing := false
var _compact := false
## Online match (server authority): no restart, no pause, leaving tells the server.
var online := false


func _ready() -> void:
	add_child(NightBackground.new())
	online = config.has("online")
	controller = OnlineMatchController.new() if online else MatchController.new()
	add_child(controller)
	controller.applied.connect(_on_applied)
	controller.finished.connect(_on_finished)
	if online:
		var oc := controller as OnlineMatchController
		oc.resynced.connect(_on_resynced)
		oc.connection_changed.connect(func(c: bool) -> void:
			_show_toast(tr("ONLINE_RECONNECTED") if c else tr("ONLINE_RECONNECTING")))
		oc.fatal.connect(func(code: String) -> void: _show_toast(tr("ONLINE_FATAL") % code))
		oc.recorded.connect(func(_id: String) -> void:
			_show_toast(tr("ONLINE_RECORDED"))
			Online.profile.loaded_at = 0)   # profile reloads with the new stats
	var seats: Array = config.get("seats", [])
	two_players = seats.size() == 2
	for i in seats.size():
		if seats[i].get("role", "") == "you":
			local_seat = i
	_build()
	resized.connect(_layout)
	var start_config := config.duplicate()
	if config.has("first_seat"):
		start_config["first_seat"] = config["first_seat"]
	if not controller.start(start_config, config.get("dice", null)):
		_show_toast(tr("MATCH_START_FAILED"))
		return
	_sync(controller.state())
	_layout()


func _build() -> void:
	var seats: Array = config["seats"]
	var colors: Array = seats.map(func(s: Dictionary) -> String: return s["color"])
	board_view = BoardView.new()
	board_view.show_symbols = bool(Settings.get_value("color_symbols"))
	board_view.setup(BoardGeometry.default_board(), colors, seats[local_seat]["color"])
	board_view.pawn_tapped.connect(_on_pawn_tapped)
	add_child(board_view)
	for i in seats.size():
		var c: String = seats[i]["color"]
		for k in 4:
			var p := PawnSprite.new(c, k)
			board_view.add_child(p)
			pawns["%s:%d" % [c, k]] = p
			board_view.pawns["%s:%d" % [c, k]] = p
	_top_bar = Control.new()
	add_child(_top_bar)
	_menu_button = UiKit.icon_button("menu", tr("MATCH_MENU"))
	_menu_button.pressed.connect(_open_menu)
	_top_bar.add_child(_menu_button)
	_mode_chip = UiKit.chip(tr("MATCH_MODE_2P_ONLINE") if online else (tr("MATCH_MODE_2P") if two_players else tr("MATCH_MODE_4P")))
	_top_bar.add_child(_mode_chip)
	for i in seats.size():
		var corner := _corner_of(seats[i]["color"])
		var card := PlayerCard.new()
		card.setup(i, seats[i]["color"], seats[i]["name"], seats[i]["kind"] == "bot", corner == 1 or corner == 2, i == local_seat)
		add_child(card)
		cards[i] = card
		var small := DiceView.new()
		small.custom_minimum_size = Vector2(72, 72)
		small.size = Vector2(72, 72)
		small.visible = false
		add_child(small)
		card_dice[i] = small
	dice = DiceView.new()
	dice.size = Vector2(UiTokens.DICE_PAD, UiTokens.DICE_PAD)
	dice.tapped.connect(_on_dice_tapped)
	add_child(dice)
	_hint = PanelContainer.new()
	_hint.add_theme_stylebox_override("panel", UiTheme.glass_box(36))
	_hint_label = UiKit.label("", "BodyLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.add_child(_hint_label)
	add_child(_hint)
	_toast = PanelContainer.new()
	var tb := UiTheme.glass_box(36)
	tb.bg_color = Color(UiPalette.NIGHT_900, 0.92)
	tb.border_color = Color(1, 1, 1, 0.16)
	_toast.add_theme_stylebox_override("panel", tb)
	_toast_label = UiKit.label("", "BodyLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_child(_toast_label)
	_toast.visible = false
	_toast.z_index = 2100
	add_child(_toast)


## Corner of a colour after rotation: 0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left.
func _corner_of(color: String) -> int:
	return posmod(BoardGeometry.COLORS.find(color) + board_view.turns, 4)


# --- Layout ------------------------------------------------------------------------

func _layout() -> void:
	if board_view == null:
		return
	var w := size.x
	var h := size.y
	var insets := SafeArea.insets(get_viewport_rect().size)
	var top := insets.x + UiTokens.S2
	var bottom := h - insets.y - UiTokens.S2
	_compact = h / w < 1.9
	_top_bar.position = Vector2(UiTokens.EDGE, top)
	_top_bar.size = Vector2(w - UiTokens.EDGE * 2, UiTokens.ICON_BUTTON)
	_menu_button.position = Vector2.ZERO
	_menu_button.size = Vector2(UiTokens.ICON_BUTTON, UiTokens.ICON_BUTTON)
	_mode_chip.reset_size()
	_mode_chip.position = Vector2((_top_bar.size.x - _mode_chip.size.x) * 0.5, (UiTokens.ICON_BUTTON - _mode_chip.size.y) * 0.5)
	var card_h := 112.0
	var dice_size := 150.0 if _compact else float(UiTokens.DICE_PAD)
	var hint_h := 0.0 if _compact else 76.0
	var above := top + UiTokens.ICON_BUTTON + UiTokens.S2 + card_h + UiTokens.S2
	var below_needed := card_h + UiTokens.S2 + dice_size + UiTokens.S2 + hint_h
	var side := minf(w - UiTokens.BOARD_MARGIN * 2, bottom - below_needed - above)
	side = maxf(side, 300.0)
	var spare := (bottom - below_needed - above) - side
	var board_y := above + maxf(0.0, spare * 0.35)
	board_view.position = Vector2((w - side) * 0.5, board_y)
	board_view.size = Vector2(side, side)
	var bx := board_view.position.x
	var after_board := board_y + side + UiTokens.S2
	var card_w := (side - UiTokens.S2) * 0.5
	for seat: int in cards:
		var card: PlayerCard = cards[seat]
		var corner := _corner_of(config["seats"][seat]["color"])
		if two_players:
			card.size = Vector2(side, card_h)
			card.position = Vector2(bx, board_y - card_h - UiTokens.S2) if seat != local_seat else Vector2(bx, after_board)
		else:
			card.size = Vector2(card_w, card_h)
			var cx := bx if corner == 0 or corner == 3 else bx + side - card_w
			var cy := board_y - card_h - UiTokens.S2 if corner <= 1 else after_board
			card.position = Vector2(cx, cy)
		# The rival's small dice sits on the side opposite the avatar.
		var small: DiceView = card_dice[seat]
		var mirrored := card.alignment == BoxContainer.ALIGNMENT_END
		small.position = card.position + Vector2(8 if mirrored else card.size.x - 80, (card_h - 72) * 0.5)
	dice.size = Vector2(dice_size, dice_size)
	dice.position = Vector2((w - dice_size) * 0.5, after_board + card_h + UiTokens.S2)
	_hint.visible = not _compact
	_hint.reset_size()
	_hint.position = Vector2((w - _hint.size.x) * 0.5, bottom - hint_h + 6)
	_toast.reset_size()
	_toast.position = Vector2((w - _toast.size.x) * 0.5, board_y + side * 0.18)
	for key: String in pawns:
		var p: PawnSprite = pawns[key]
		p.cell_size = board_view.cell_size()
	if controller != null and controller.session != null:
		_place_all(controller.state())
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.size = size


# --- State -> view -------------------------------------------------------------------

func _place_all(state: Dictionary) -> void:
	var stacks := {}
	for p: Dictionary in state["players"]:
		var c: String = p["color"]
		var steps: Array = state["pawns"][c]
		for k in 4:
			var st := int(steps[k])
			var sprite: PawnSprite = pawns["%s:%d" % [c, k]]
			sprite.step = st
			sprite.visible = p["status"] != "left"
			sprite.set_finished_look(st >= 56)
			var pos := board_view.pawn_position(c, st, k)
			var key := "%d,%d" % [int(pos.x), int(pos.y)]
			if st >= 0 and st < 56:
				stacks[key] = stacks.get(key, []) + [sprite]
			sprite.position = pos
	# Pawns on the same cell sit side by side (UI_UX_DESIGN_SYSTEM §7.2).
	for key: String in stacks:
		var list: Array = stacks[key]
		if list.size() < 2:
			continue
		for i in list.size():
			var s: PawnSprite = list[i]
			s.position += Vector2((i - (list.size() - 1) * 0.5) * board_view.cell_size() * 0.32, -i * board_view.cell_size() * 0.08)
	for key: String in pawns:
		var s: PawnSprite = pawns[key]
		s.z_index = clampi(int(s.position.y / maxf(board_view.size.y, 1.0) * 900.0), 0, 900)


func _sync(state: Dictionary) -> void:
	_place_all(state)
	var turn: Dictionary = state["turn"]
	var seat := int(turn["seat"])
	var seats: Array = config["seats"]
	for i: int in cards:
		var card: PlayerCard = cards[i]
		var p: Dictionary = state["players"][i]
		var finished := 0
		for st: Variant in state["pawns"][p["color"]]:
			if int(st) >= 56:
				finished += 1
		card.set_finished_pawns(finished)
		card.set_out(int(p["rank"]) if p["status"] == "finished" or turn["phase"] == "game_over" else 0, p["status"] == "left")
		var status := ""
		if p["status"] == "left":
			status = tr("MATCH_STATUS_LEFT")
		elif p["autopilot"]:
			status = tr("MATCH_STATUS_AUTOPILOT")
		elif p["status"] == "finished":
			status = tr("MATCH_STATUS_FINISHED") % int(p["rank"])
		elif i == seat and turn["phase"] != "game_over":
			status = tr("MATCH_STATUS_TURN")
		card.set_status(status, p["autopilot"])
		card.set_turn(i == seat and turn["phase"] != "game_over")
	var human_turn: bool = controller.is_human_turn()
	var human_roll: bool = human_turn and turn["phase"] == "roll"
	var human_move: bool = human_turn and turn["phase"] == "move"
	dice.set_active(human_roll)
	board_view.selectable = []
	board_view.targets = []
	for key: String in pawns:
		(pawns[key] as PawnSprite).selectable = false
	if human_move:
		var color: String = seats[seat]["color"]
		for m: Dictionary in state["legal"]:
			board_view.selectable.append({"color": color, "pawn": int(m["pawn"])})
			board_view.targets.append({"color": color, "step": int(m["to"])})
			(pawns["%s:%d" % [color, int(m["pawn"])]] as PawnSprite).selectable = true
	board_view.queue_redraw()
	var name: String = seats[seat]["name"]
	if turn["phase"] == "game_over":
		_hint_label.text = tr("MATCH_HINT_OVER")
	elif human_roll:
		_hint_label.text = tr("MATCH_HINT_ROLL") if seat == local_seat or seats.filter(func(s: Dictionary) -> bool: return s["kind"] == "human").size() == 1 else tr("MATCH_HINT_ROLL_NAMED") % name
	elif human_move:
		_hint_label.text = tr("MATCH_HINT_MOVE")
	elif seats[seat]["kind"] == "bot":
		_hint_label.text = tr("MATCH_HINT_BOT") % name
	else:
		_hint_label.text = tr("MATCH_HINT_WAIT") % name
	_hint.reset_size()
	_hint.position.x = (size.x - _hint.size.x) * 0.5


func _process(_delta: float) -> void:
	if controller == null or controller.session == null:
		return
	var total := controller.phase_seconds()
	var seat := int(controller.state()["turn"]["seat"])
	if total > 0.0 and cards.has(seat):
		var left := controller.seconds_left()
		(cards[seat] as PlayerCard).set_turn(true, left / total, left < 3.0)


# --- Input ------------------------------------------------------------------------

func _on_dice_tapped() -> void:
	var seat := int(controller.state()["turn"]["seat"])
	if controller.is_human_turn(seat):
		controller.human_roll(seat)


func _on_pawn_tapped(color: String, pawn: int) -> void:
	var seat := int(controller.state()["turn"]["seat"])
	if controller.is_human_turn(seat) and config["seats"][seat]["color"] == color:
		controller.human_move(seat, pawn)


# --- Events -> animation -----------------------------------------------------------

func _on_applied(events: Array, state: Dictionary) -> void:
	dice.set_active(false)
	board_view.selectable = []
	board_view.targets = []
	for key: String in pawns:
		(pawns[key] as PawnSprite).selectable = false
	board_view.queue_redraw()
	await _animate(events)
	if _closing or not is_inside_tree():
		return
	_sync(state)
	controller.view_done()


func _animate(events: Array) -> void:
	var k := Settings.anim_scale()
	var seats: Array = config["seats"]
	for e: Dictionary in events:
		if _closing or not is_inside_tree():
			return
		var seat := int(e.get("seat", -1))
		match String(e["type"]):
			"dice_rolled":
				var value := int(e["value"])
				if seats[seat]["kind"] == "human" and not controller.state()["players"][seat]["autopilot"]:
					await dice.roll(value, 0.55 * k)
				else:
					for s: int in card_dice:
						(card_dice[s] as DiceView).visible = s == seat
					var small: DiceView = card_dice[seat]
					await small.roll(value, 0.42 * k)
					dice.value = value
					dice.queue_redraw()
				if e.get("auto", false) and seats[seat]["kind"] == "human":
					_show_toast(tr("MATCH_TOAST_TIMEOUT"))
			"no_moves":
				_show_toast(tr("MATCH_TOAST_NO_MOVES"))
				await _wait(0.75 * k)
			"pawn_moved":
				await _animate_move(e, k)
			"pawn_captured":
				Settings.vibrate(60)
				var victim: PawnSprite = pawns["%s:%d" % [e["color"], int(e["pawn"])]]
				_shake_board()
				var home := board_view.pawn_position(e["color"], -1, int(e["pawn"]))
				await victim.fly_to(home, 0.45 * k)
				_toast_capture(int(e["by_seat"]), seat, String(e["color"]))
			"pawn_finished":
				var sprite: PawnSprite = pawns["%s:%d" % [e["color"], int(e["pawn"])]]
				sprite.set_finished_look(true)
				sprite.pop()
				await _wait(0.25 * k)
			"bonus_roll":
				if String(e["reason"]) == "six":
					_show_toast(tr("MATCH_TOAST_SIX"))
				else:
					_show_toast(tr("MATCH_TOAST_BONUS"))
			"turn_forfeited":
				_show_toast(tr("MATCH_TOAST_THREE_SIXES"))
				await _wait(0.6 * k)
			"player_finished":
				Settings.vibrate(40)
				_show_toast(tr("MATCH_TOAST_PLAYER_FINISHED") % [seats[seat]["name"], int(e["rank"])])
			"player_left":
				for i in 4:
					var sp: PawnSprite = pawns["%s:%d" % [seats[seat]["color"], i]]
					create_tween().tween_property(sp, "modulate:a", 0.0, 0.3)
			"autopilot_changed":
				if e["on"]:
					_show_toast(tr("MATCH_TOAST_AUTOPILOT") % seats[seat]["name"])
			"turn_changed":
				for s: int in card_dice:
					if s != int(e["seat"]):
						(card_dice[s] as DiceView).visible = false
	board_view.trail = {}


func _animate_move(e: Dictionary, k: float) -> void:
	var color: String = e["color"]
	var sprite: PawnSprite = pawns["%s:%d" % [color, int(e["pawn"])]]
	sprite.z_index = 950
	var points: Array[Vector2] = []
	for st: Variant in e["path"]:
		points.append(board_view.pawn_position(color, int(st), int(e["pawn"])))
	if int(e["from"]) < 0:
		await sprite.fly_to(points[0], 0.3 * k)
		sprite.pop()
	else:
		await sprite.hop_along(points, UiTokens.STEP_HOP_MS / 1000.0 * k)
	board_view.trail = {"color": color, "from": int(e["from"]), "to": int(e["to"])}
	board_view.queue_redraw()


func _toast_capture(by_seat: int, victim_seat: int, victim_color: String) -> void:
	var seats: Array = config["seats"]
	if victim_seat == local_seat:
		_show_toast(tr("MATCH_TOAST_YOU_WERE_CAPTURED") % seats[by_seat]["name"])
	elif by_seat == local_seat:
		_show_toast(tr("MATCH_TOAST_YOU_CAPTURED"))
	else:
		_show_toast(tr("MATCH_TOAST_CAPTURED") % [seats[by_seat]["name"], tr("COLOR_" + victim_color.to_upper() + "_ACC")])


func _shake_board() -> void:
	if Settings.get_value("reduced_motion"):
		return
	var origin := board_view.position
	var t := create_tween()
	for d: Vector2 in [Vector2(8, 0), Vector2(-8, 4), Vector2(6, -4), Vector2.ZERO]:
		t.tween_property(board_view, "position", origin + d, 0.03)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _show_toast(text: String) -> void:
	_toast_queue.append(text)
	if not _toast_busy:
		_run_toasts()


func _run_toasts() -> void:
	_toast_busy = true
	while not _toast_queue.is_empty() and is_inside_tree():
		_toast_label.text = _toast_queue.pop_front()
		_toast.visible = true
		_toast.modulate.a = 0.0
		_toast.reset_size()
		_toast.position.x = (size.x - _toast.size.x) * 0.5
		var t := create_tween()
		t.tween_property(_toast, "modulate:a", 1.0, 0.16)
		t.tween_interval(1.3 if _toast_queue.is_empty() else 0.7)
		t.tween_property(_toast, "modulate:a", 0.0, 0.2)
		await t.finished
	_toast.visible = false
	_toast_busy = false


# --- Menu, confirmation, result -----------------------------------------------------

## Android back / Escape: close an open sheet, leave from the result screen,
## otherwise open the match menu (never leaves a running match silently).
func handle_back() -> bool:
	if _overlay != null and is_instance_valid(_overlay):
		if controller != null and controller.state().get("turn", {}).get("phase", "") == "game_over":
			_leave(false)
		else:
			_close_overlay()
		return true
	_open_menu()
	return true


func _open_menu() -> void:
	controller.pause()
	var sheet := _sheet()
	var col: VBoxContainer = sheet.get_meta("content")
	col.add_child(UiKit.label(tr("MENU_TITLE"), "InkH2Label"))
	var resume := UiKit.button(tr("MENU_RESUME"), "primary")
	resume.pressed.connect(_close_overlay)
	col.add_child(resume)
	for key: String in ["fast_animations", "auto_single_move", "color_symbols"]:
		col.add_child(_toggle_row(key))
	if not online:
		var restart := UiKit.button(tr("MENU_RESTART"), "secondary")
		restart.pressed.connect(func() -> void: _confirm(tr("CONFIRM_RESTART"), tr("MENU_RESTART"), func() -> void: _leave(true)))
		col.add_child(restart)
	var leave := UiKit.button(tr("MENU_LEAVE"), "secondary")
	leave.add_theme_color_override("font_color", Color("#c03a3f"))
	var confirm_text := tr("CONFIRM_LEAVE_ONLINE") if online else tr("CONFIRM_LEAVE")
	leave.pressed.connect(func() -> void: _confirm(confirm_text, tr("MENU_LEAVE"), func() -> void: _leave(false)))
	col.add_child(leave)


func _toggle_row(key: String) -> Control:
	var b := UiKit.button("", "secondary", "s")
	var refresh := func() -> void:
		b.text = "%s: %s" % [tr("SETTING_" + key.to_upper()), tr("ON") if Settings.get_value(key) else tr("OFF")]
	refresh.call()
	b.pressed.connect(func() -> void:
		Settings.set_value(key, not Settings.get_value(key))
		refresh.call()
		if key == "color_symbols":
			board_view.show_symbols = bool(Settings.get_value(key))
			board_view.queue_redraw()
		elif key == "auto_single_move":
			controller.auto_single_move = bool(Settings.get_value(key)))
	return b


func _sheet() -> PanelContainer:
	_close_overlay(false)
	_overlay = Control.new()
	_overlay.size = size
	_overlay.z_index = 2000
	var dim := ColorRect.new()
	dim.color = Color(UiPalette.NIGHT_900, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	var sheet := PanelContainer.new()
	sheet.theme_type_variation = "SheetPanel"
	var col := UiKit.vbox(UiTokens.S2)
	sheet.add_child(col)
	sheet.set_meta("content", col)
	_overlay.add_child(sheet)
	add_child(_overlay)
	_place_sheet.call_deferred(sheet)
	return sheet


func _place_sheet(sheet: PanelContainer) -> void:
	if not is_instance_valid(sheet):
		return
	var insets := SafeArea.insets(get_viewport_rect().size)
	sheet.size = Vector2(minf(size.x, 960), 0)
	sheet.reset_size()
	sheet.size.x = minf(size.x, 960)
	var col: Control = sheet.get_meta("content")
	col.add_theme_constant_override("separation", UiTokens.S2)
	sheet.position = Vector2((size.x - sheet.size.x) * 0.5, size.y - sheet.size.y - insets.y * 0.0)
	var pad := sheet.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	pad.content_margin_bottom = UiTokens.S4 + insets.y
	sheet.add_theme_stylebox_override("panel", pad)
	sheet.reset_size()
	sheet.size.x = minf(size.x, 960)
	sheet.position = Vector2((size.x - sheet.size.x) * 0.5, size.y - sheet.size.y)
	if not Settings.get_value("reduced_motion"):
		var final_y := sheet.position.y
		sheet.position.y = size.y
		create_tween().tween_property(sheet, "position:y", final_y, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _close_overlay(resume: bool = true) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	if resume and controller != null:
		controller.resume()


func _confirm(text: String, action_text: String, on_yes: Callable) -> void:
	var sheet := _sheet()
	var col: VBoxContainer = sheet.get_meta("content")
	var l := UiKit.label(text, "InkBodyLabel", HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	var row := UiKit.hbox(UiTokens.S2)
	var no := UiKit.button(tr("CANCEL"), "secondary")
	var yes := UiKit.button(action_text, "berry")
	for b: Button in [no, yes]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	no.pressed.connect(_close_overlay)
	yes.pressed.connect(on_yes)
	col.add_child(row)


func _leave(restart: bool) -> void:
	_closing = true
	if online and controller.state().get("turn", {}).get("phase", "") != "game_over":
		controller.leave(local_seat)   # the server ends my part of the match
	controller.stop()
	if restart:
		restart_requested.emit()
	else:
		exit_requested.emit()


## Online: after a reconnect the server's full state replaces the screen.
func _on_resynced(state: Dictionary) -> void:
	if _closing or not is_inside_tree():
		return
	_place_all(state)
	_sync(state)


func _on_finished(state: Dictionary) -> void:
	match_over.emit(state)
	await _wait(0.6)
	if _closing or not is_inside_tree():
		return
	_show_result(state)


func _show_result(state: Dictionary) -> void:
	_close_overlay(false)
	_overlay = Control.new()
	_overlay.size = size
	_overlay.z_index = 2000
	var dim := ColorRect.new()
	dim.color = Color(UiPalette.NIGHT_900, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var seats: Array = config["seats"]
	var ranks: Array = state["ranks"]
	var my_rank := place_of(ranks, local_seat)
	var col := UiKit.vbox(UiTokens.S3)
	col.position = Vector2(UiTokens.EDGE, SafeArea.insets(get_viewport_rect().size).x + 80)
	col.size = Vector2(size.x - UiTokens.EDGE * 2, 0)
	var title := UiKit.label(tr("RESULT_PLACE") % my_rank if my_rank == 1 else tr("RESULT_PLACE_OTHER") % my_rank, "DisplayLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", UiPalette.GOLD_300 if my_rank == 1 else UiPalette.ON_NIGHT)
	col.add_child(title)
	col.add_child(UiKit.label(tr("RESULT_ONLINE_NOTE") if online else tr("RESULT_PRACTICE_NOTE"), "DimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var card := PanelContainer.new()
	card.theme_type_variation = "CreamCard"
	var list := UiKit.vbox(UiTokens.S1)
	card.add_child(list)
	for i in ranks.size():
		var seat := int(ranks[i])
		var row := UiKit.hbox(UiTokens.S2)
		var place := UiKit.label(str(i + 1), "InkH2Label", HORIZONTAL_ALIGNMENT_CENTER)
		place.custom_minimum_size = Vector2(48, 0)
		if i == 0:
			place.add_theme_color_override("font_color", UiPalette.GOLD_700)
		row.add_child(place)
		var av := Avatar.new()
		av.custom_minimum_size = Vector2(80, 80)
		av.setup(seats[seat]["name"], seats[seat]["color"], seats[seat]["kind"] == "bot")
		row.add_child(av)
		var n := UiKit.label(seats[seat]["name"], "InkH3Label")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var p: Dictionary = state["players"][seat]
		if p["status"] == "left":
			row.add_child(UiKit.label(tr("MATCH_STATUS_LEFT"), "InkDimLabel"))
		elif seats[seat]["kind"] == "bot":
			row.add_child(UiKit.chip(tr("MATCH_BOT_TAG"), UiPalette.CREAM_200, UiPalette.INK_700))
		list.add_child(row)
	col.add_child(card)
	var buttons := UiKit.hbox(UiTokens.S2)
	var menu := UiKit.button(tr("RESULT_MENU"), "secondary")
	var again := UiKit.button(tr("RESULT_AGAIN"), "primary")
	for b: Button in [menu, again]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	menu.pressed.connect(func() -> void: _leave(false))
	again.pressed.connect(func() -> void: _leave(true))
	col.add_child(buttons)
	_overlay.add_child(col)
	add_child(_overlay)
	if not Settings.get_value("reduced_motion"):
		col.modulate.a = 0.0
		col.scale = Vector2(0.92, 0.92)
		col.pivot_offset = Vector2(col.size.x * 0.5, 300)
		var t := create_tween().set_parallel()
		t.tween_property(col, "modulate:a", 1.0, 0.24)
		t.tween_property(col, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 1-based place of a seat in a ranks array (0 = not ranked). Online states come from
## JSON, so the seats in `ranks` are floats (2.0): Array.find(2) would not match them.
static func place_of(ranks: Array, seat: int) -> int:
	for i in ranks.size():
		if int(ranks[i]) == seat:
			return i + 1
	return 0

