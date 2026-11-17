class_name MoveValidator
extends RefCounted
## MoveValidator + CaptureResolver (GAME_RULES §4, §5, §7, §8) — twin of
## server/game-engine/src/moves.ts. Same ordering: moves by pawn index,
## captures by seat then pawn index.


## Opponent pawns captured when `color`'s move ends on `to_step`. Safe cells
## and the corridor capture nothing; a whole stack is captured (capture_stack all).
static func capture_targets(state: Dictionary, board: BoardGeometry, seat: int, color: String, to_step: int) -> Array:
	var target := board.track_index(color, to_step)
	if target < 0 or board.is_safe_track(target):
		return []
	var out: Array = []
	for p: Dictionary in state["players"]:
		if int(p["seat"]) == seat or p["status"] != "active":
			continue
		var steps: Array = state["pawns"][p["color"]]
		for i in 4:
			var step := int(steps[i])
			if board.track_index(p["color"], step) == target:
				out.append({"color": p["color"], "pawn": i, "from": step})
	return out


## Legal moves of `seat` for dice `value`, ordered by pawn index.
static func legal_moves(state: Dictionary, board: BoardGeometry, seat: int, value: int) -> Array:
	var color: String = state["players"][seat]["color"]
	var steps: Array = state["pawns"][color]
	var enter_on: Array = state["ruleset"]["enter_on"]
	var out: Array = []
	for i in 4:
		var from := int(steps[i])
		if from == board.goal_step:
			continue
		var to: int
		if from == BoardGeometry.YARD:
			if not enter_on.has(value):
				continue
			to = 0
		else:
			to = from + value
			if to > board.goal_step:
				continue
		out.append({
			"pawn": i, "from": from, "to": to,
			"captures": capture_targets(state, board, seat, color, to),
			"finishes": to == board.goal_step,
		})
	return out


## True when every legal move is the same move (same from and to): K-20.
static func is_single_option(moves: Array) -> bool:
	if moves.is_empty():
		return false
	var first: Dictionary = moves[0]
	for m: Dictionary in moves:
		if m["from"] != first["from"] or m["to"] != first["to"]:
			return false
	return true


## Steps passed for animation: [0] when entering, else from+1..to.
static func path_of(from: int, to: int) -> Array:
	if from == BoardGeometry.YARD:
		return [0]
	var out: Array = []
	for st in range(from + 1, to + 1):
		out.append(st)
	return out
