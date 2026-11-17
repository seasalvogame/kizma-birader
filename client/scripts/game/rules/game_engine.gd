class_name GameEngine
extends RefCounted
## Pure state transition — twin of server/game-engine/src/engine.ts.
## apply(state, action, dice) -> {ok: true, state, events} or
## {ok: false, error, state} (input state untouched). Never reads a clock or
## a random source: timers and dice belong to the caller.
##
## action: {type: "roll"|"move"|"timeout"|"leave", seat, turn_id, pawn}
## dice: 1..6 for a roll and for a timeout in the roll phase; -1 = none.

const NO_DICE := -1

var board: BoardGeometry


func _init(p_board: BoardGeometry = null) -> void:
	board = p_board if p_board != null else BoardGeometry.default_board()


## Highest dice value allowed for the next roll (GAME_RULES §6.2) — twin of
## maxDiceValue in engine.ts. With third_six_action "exclude_six", after
## max_consecutive_sixes - 1 sixes in a row the next roll is 1..5.
static func max_dice_value(state: Dictionary) -> int:
	var rules: Dictionary = state["ruleset"]
	if rules["third_six_action"] == "exclude_six" and int(state["turn"]["sixes"]) >= int(rules["max_consecutive_sixes"]) - 1:
		return 5
	return 6


func apply(state: Dictionary, action: Dictionary, dice: int = NO_DICE) -> Dictionary:
	if state["turn"]["phase"] == "game_over":
		return _fail("GAME_OVER", state)
	var seat := int(action.get("seat", -1))
	var players: Array = state["players"]
	if seat < 0 or seat >= players.size():
		return _fail("UNKNOWN_SEAT", state)
	if players[seat]["status"] != "active":
		return _fail("NOT_ACTIVE", state)
	var type := String(action.get("type", ""))
	if type == "leave":
		var left := state.duplicate(true)
		var left_events: Array = []
		_leave(left, seat, left_events)
		left["version"] = int(left["version"]) + 1
		return {"ok": true, "state": left, "events": left_events}
	if seat != int(state["turn"]["seat"]):
		return _fail("NOT_YOUR_TURN", state)
	if int(action.get("turn_id", -1)) != int(state["turn"]["turn_id"]):
		return _fail("STALE_TURN", state)
	var needs_dice: bool = type == "roll" or (type == "timeout" and state["turn"]["phase"] == "roll")
	if needs_dice:
		if dice == NO_DICE:
			return _fail("DICE_REQUIRED", state)
		if dice < 1 or dice > max_dice_value(state):
			return _fail("INVALID_DICE", state)
	var s := state.duplicate(true)
	var events: Array = []
	if type == "roll":
		if s["turn"]["phase"] != "roll":
			return _fail("WRONG_PHASE", state)
		_player_acted(s, seat, events)
		_roll(s, dice, false, events)
	elif type == "move":
		if s["turn"]["phase"] != "move":
			return _fail("WRONG_PHASE", state)
		var chosen: Dictionary = {}
		for m: Dictionary in s["legal"]:
			if int(m["pawn"]) == int(action.get("pawn", -1)):
				chosen = m
				break
		if chosen.is_empty():
			return _fail("ILLEGAL_MOVE", state)
		_player_acted(s, seat, events)
		_move(s, chosen, false, events)
	elif type == "timeout":
		_timed_out(s, seat, events)
		if s["turn"]["phase"] == "roll":
			_roll(s, dice, true, events)
		if s["turn"]["phase"] == "move" and int(s["turn"]["seat"]) == seat:
			_move(s, BotPolicy.choose(s, board), true, events)
	else:
		return _fail("UNKNOWN_ACTION", state)
	s["version"] = int(s["version"]) + 1
	return {"ok": true, "state": s, "events": events}


func _fail(code: String, state: Dictionary) -> Dictionary:
	return {"ok": false, "error": code, "state": state}


func _player_acted(s: Dictionary, seat: int, events: Array) -> void:
	var p: Dictionary = s["players"][seat]
	p["timeouts"] = 0
	if p["autopilot"]:
		p["autopilot"] = false
		events.append({"type": "autopilot_changed", "seat": seat, "on": false})


func _timed_out(s: Dictionary, seat: int, events: Array) -> void:
	var p: Dictionary = s["players"][seat]
	p["timeouts"] = int(p["timeouts"]) + 1
	if not p["autopilot"] and p["kind"] == "human" and int(p["timeouts"]) >= int(s["ruleset"]["afk_timeouts_to_autopilot"]):
		p["autopilot"] = true
		events.append({"type": "autopilot_changed", "seat": seat, "on": true})


func _roll(s: Dictionary, value: int, auto: bool, events: Array) -> void:
	var turn: Dictionary = s["turn"]
	var seat := int(turn["seat"])
	events.append({"type": "dice_rolled", "seat": seat, "value": value, "auto": auto})
	turn["sixes"] = int(turn["sixes"]) + 1 if value == 6 else 0
	var rules: Dictionary = s["ruleset"]
	if value == 6 and rules["third_six_action"] == "forfeit_turn" and int(turn["sixes"]) >= int(rules["max_consecutive_sixes"]):
		events.append({"type": "turn_forfeited", "seat": seat, "reason": "three_sixes"})
		TurnManager.pass_turn(s, events)
		return
	var moves := MoveValidator.legal_moves(s, board, seat, value)
	if moves.is_empty():
		events.append({"type": "no_moves", "seat": seat})
		if value == 6 and rules["bonus_roll_on_six"]:
			TurnManager.start_bonus_roll(s, "six", events)
		else:
			TurnManager.pass_turn(s, events)
		return
	turn["phase"] = "move"
	turn["dice"] = value
	s["legal"] = moves


func _move(s: Dictionary, m: Dictionary, auto: bool, events: Array) -> void:
	var turn: Dictionary = s["turn"]
	var seat := int(turn["seat"])
	var color: String = s["players"][seat]["color"]
	var dice := int(turn["dice"])
	var pawn := int(m["pawn"])
	var from := int(m["from"])
	var to := int(m["to"])
	s["pawns"][color][pawn] = to
	events.append({"type": "pawn_moved", "seat": seat, "color": color, "pawn": pawn, "from": from, "to": to,
		"path": MoveValidator.path_of(from, to), "auto": auto})
	var captures: Array = m["captures"]
	for c: Dictionary in captures:
		s["pawns"][c["color"]][int(c["pawn"])] = -1
		var owner: Dictionary = GameState.player_by_color(s, c["color"])
		events.append({"type": "pawn_captured", "seat": int(owner["seat"]), "by_seat": seat, "color": c["color"],
			"pawn": int(c["pawn"]), "from": int(c["from"])})
	if m["finishes"]:
		events.append({"type": "pawn_finished", "seat": seat, "color": color, "pawn": pawn})
	s["legal"] = []
	turn["dice"] = 0
	var player_done := TurnManager.check_player_finished(s, board, seat, events)
	if TurnManager.is_game_over(s):
		TurnManager.finish_game(s, events)
		return
	if player_done:
		TurnManager.pass_turn(s, events)
		return
	var rules: Dictionary = s["ruleset"]
	var reason := ""
	if dice == 6 and rules["bonus_roll_on_six"]:
		reason = "six"
	elif not captures.is_empty() and rules["bonus_roll_on_capture"]:
		reason = "capture"
	elif m["finishes"] and rules["bonus_roll_on_finish"]:
		reason = "finish"
	if reason != "":
		TurnManager.start_bonus_roll(s, reason, events)
	else:
		TurnManager.pass_turn(s, events)


func _leave(s: Dictionary, seat: int, events: Array) -> void:
	var p: Dictionary = s["players"][seat]
	p["status"] = "left"
	s["pawns"][p["color"]] = [-1, -1, -1, -1]
	(s["left_order"] as Array).append(seat)
	events.append({"type": "player_left", "seat": seat})
	if TurnManager.is_game_over(s):
		TurnManager.finish_game(s, events)
		return
	if int(s["turn"]["seat"]) == seat:
		TurnManager.pass_turn(s, events)
	elif s["turn"]["phase"] == "move":
		s["legal"] = MoveValidator.legal_moves(s, board, int(s["turn"]["seat"]), int(s["turn"]["dice"]))
