class_name GameState
extends RefCounted
## Game state as a plain Dictionary with the same JSON shape as the
## TypeScript engine (server/game-engine/src/state.ts), so snapshots and
## test vectors are interchangeable. create() returns {} on error and sets
## last_error. Connection status is not part of the rules state.
##
## {
##   ruleset: {...}, players: [{seat, color, kind, status, rank, timeouts, autopilot}],
##   pawns: {color: [step x4]}, turn: {seat, phase, dice, sixes, turn_id},
##   legal: [{pawn, from, to, captures: [{color, pawn, from}], finishes}],
##   ranks: [seat...], left_order: [seat...], version: int
## }

static var last_error := ""


## options: players (2|4), seats ([{color, kind}]), ruleset ({}), first_seat (int).
static func create(options: Dictionary = {}, board: BoardGeometry = null) -> Dictionary:
	last_error = ""
	if board == null:
		board = BoardGeometry.default_board()
	var seats: Array = options.get("seats", [])
	if seats.is_empty():
		seats = default_seats(int(options.get("players", 4)), board)
	if seats.size() != 2 and seats.size() != 4:
		return _fail("a game has 2 or 4 players")
	var order: Array[int] = []
	var colors: Array[String] = []
	for seat: Dictionary in seats:
		var c := String(seat["color"])
		if colors.has(c):
			return _fail("duplicate colour")
		colors.append(c)
		order.append(BoardGeometry.COLORS.find(c))
	for i in range(1, order.size()):
		if order[i] <= order[i - 1]:
			return _fail("seats must be in clockwise colour order")
	if seats.size() == 2 and absi(order[1] - order[0]) != 2:
		return _fail("2-player colours must face each other")
	var first := int(options.get("first_seat", 0))
	if first < 0 or first >= seats.size():
		return _fail("bad first seat")
	var ruleset := Ruleset.make(options.get("ruleset", {}))
	if ruleset.is_empty():
		return _fail(Ruleset.last_error)
	var players: Array = []
	var pawns := {}
	for i in seats.size():
		var c := colors[i]
		players.append({
			"seat": i, "color": c, "kind": String(seats[i].get("kind", "human")),
			"status": "active", "rank": 0, "timeouts": 0, "autopilot": false,
		})
		pawns[c] = [-1, -1, -1, -1]
	return {
		"ruleset": ruleset,
		"players": players,
		"pawns": pawns,
		"turn": {"seat": first, "phase": "roll", "dice": 0, "sixes": 0, "turn_id": 1},
		"legal": [],
		"ranks": [],
		"left_order": [],
		"version": 0,
	}


static func default_seats(players: int, board: BoardGeometry = null) -> Array:
	if board == null:
		board = BoardGeometry.default_board()
	var out: Array = []
	var colors: Array[String] = board.two_player_colors if players == 2 else BoardGeometry.COLORS
	for c: String in colors:
		out.append({"color": c})
	return out


static func player_by_color(state: Dictionary, color: String) -> Dictionary:
	for p: Dictionary in state["players"]:
		if p["color"] == color:
			return p
	return {}


static func _fail(message: String) -> Dictionary:
	last_error = message
	return {}
