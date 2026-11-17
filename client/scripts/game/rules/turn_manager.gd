class_name TurnManager
extends RefCounted
## TurnManager + WinCondition (GAME_RULES §2, §6, §9, §11) — twin of
## server/game-engine/src/turn.ts.


static func next_active_seat(state: Dictionary, seat: int) -> int:
	var players: Array = state["players"]
	var n := players.size()
	for k in range(1, n + 1):
		var candidate := (seat + k) % n
		if players[candidate]["status"] == "active":
			return candidate
	return seat


static func pass_turn(state: Dictionary, events: Array) -> void:
	var turn: Dictionary = state["turn"]
	var next := next_active_seat(state, int(turn["seat"]))
	state["turn"] = {"seat": next, "phase": "roll", "dice": 0, "sixes": 0, "turn_id": int(turn["turn_id"]) + 1}
	state["legal"] = []
	events.append({"type": "turn_changed", "seat": next, "turn_id": int(turn["turn_id"]) + 1})


static func start_bonus_roll(state: Dictionary, reason: String, events: Array) -> void:
	var turn: Dictionary = state["turn"]
	turn["phase"] = "roll"
	turn["dice"] = 0
	turn["turn_id"] = int(turn["turn_id"]) + 1
	state["legal"] = []
	events.append({"type": "bonus_roll", "seat": int(turn["seat"]), "reason": reason})


static func check_player_finished(state: Dictionary, board: BoardGeometry, seat: int, events: Array) -> bool:
	var p: Dictionary = state["players"][seat]
	if p["status"] != "active":
		return false
	for st: Variant in state["pawns"][p["color"]]:
		if int(st) != board.goal_step:
			return false
	p["status"] = "finished"
	var ranks: Array = state["ranks"]
	ranks.append(seat)
	p["rank"] = ranks.size()
	events.append({"type": "player_finished", "seat": seat, "rank": ranks.size()})
	return true


static func is_game_over(state: Dictionary) -> bool:
	var active := 0
	for p: Dictionary in state["players"]:
		if p["status"] == "active":
			active += 1
	if active <= 1:
		return true
	return state["ruleset"]["four_player_end"] == "first_finisher" and (state["ranks"] as Array).size() >= 1


## Ranks the rest (progress desc, then seat), then leavers (last leaver first).
static func finish_game(state: Dictionary, events: Array) -> void:
	var remaining: Array = []
	for p: Dictionary in state["players"]:
		if p["status"] == "active":
			remaining.append(int(p["seat"]))
	remaining.sort_custom(func(a: int, b: int) -> bool:
		var pa := _progress(state, a)
		var pb := _progress(state, b)
		return pa > pb if pa != pb else a < b)
	var ranks: Array = state["ranks"]
	ranks.append_array(remaining)
	var left: Array = state["left_order"]
	for i in range(left.size() - 1, -1, -1):
		ranks.append(int(left[i]))
	for i in ranks.size():
		state["players"][int(ranks[i])]["rank"] = i + 1
	var turn: Dictionary = state["turn"]
	turn["phase"] = "game_over"
	turn["dice"] = 0
	state["legal"] = []
	events.append({"type": "game_over", "ranks": ranks.duplicate()})


static func _progress(state: Dictionary, seat: int) -> int:
	var sum := 0
	for st: Variant in state["pawns"][state["players"][seat]["color"]]:
		sum += int(st) + 1
	return sum
