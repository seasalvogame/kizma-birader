class_name BotPolicy
extends RefCounted
## Bot / autopilot move choice (GAME_RULES §10.4) — twin of
## server/game-engine/src/bot.ts. Deterministic. Priority: finish > capture
## > enter > escape danger to a safe cell > rearmost pawn > first legal move.


static func in_danger(state: Dictionary, board: BoardGeometry, seat: int, step: int) -> bool:
	var color: String = state["players"][seat]["color"]
	var target := board.track_index(color, step)
	if target < 0 or board.is_safe_track(target):
		return false
	for p: Dictionary in state["players"]:
		if int(p["seat"]) == seat or p["status"] != "active":
			continue
		for st: Variant in state["pawns"][p["color"]]:
			var from := board.track_index(p["color"], int(st))
			if from < 0:
				continue
			var distance := posmod(target - from, board.track_length)
			if distance >= 1 and distance <= 6 and int(st) + distance <= board.last_track_step:
				return true
	return false


static func _is_safe_step(board: BoardGeometry, color: String, step: int) -> bool:
	if step > board.last_track_step:
		return true
	return board.is_safe_track(board.track_index(color, step))


static func choose(state: Dictionary, board: BoardGeometry) -> Dictionary:
	var moves: Array = state["legal"]
	if moves.is_empty():
		push_error("bot asked to move without legal moves")
		return {}
	var seat := int(state["turn"]["seat"])
	var color: String = state["players"][seat]["color"]
	for m: Dictionary in moves:
		if m["finishes"]:
			return m
	for m: Dictionary in moves:
		if not (m["captures"] as Array).is_empty():
			return m
	for m: Dictionary in moves:
		if int(m["from"]) < 0:
			return m
	for m: Dictionary in moves:
		if int(m["from"]) >= 0 and in_danger(state, board, seat, int(m["from"])) and _is_safe_step(board, color, int(m["to"])):
			return m
	var rear: Dictionary = {}
	for m: Dictionary in moves:
		if int(m["from"]) >= 0 and (rear.is_empty() or int(m["from"]) < int(rear["from"])):
			rear = m
	return rear if not rear.is_empty() else moves[0]
