class_name BoardGeometry
extends RefCounted
## Board geometry read from res://data/board_map.json — a byte-identical copy
## of the single source docs/design/board/board_map.json (MAP_SPECIFICATION.md).
## Nothing about the board is re-encoded here. GDScript twin of
## server/game-engine/src/board.ts.

const COLORS: Array[String] = ["red", "green", "yellow", "blue"]
const YARD := -1
const DEFAULT_PATH := "res://data/board_map.json"

var map: Dictionary = {}
var grid := 15
var track_length := 52
var goal_step := 56
## Last step on the common track (50); the next step enters the corridor.
var last_track_step := 50
var track: Array[Vector2i] = []
var safe_indices: Array[int] = []
var star_indices: Array[int] = []
var home_columns: Dictionary = {}   # color -> Array[Vector2i]
var goal_cells: Array[Vector2i] = []
var yard_rects: Dictionary = {}     # color -> Rect2i
var yard_slots: Dictionary = {}     # color -> Array[Vector2] (cell coordinates, float)
var two_player_colors: Array[String] = []
var load_error := ""
var _start: Dictionary = {}
var _safe: Dictionary = {}

static var _default: BoardGeometry


static func default_board() -> BoardGeometry:
	if _default == null:
		_default = BoardGeometry.new()
	return _default


func _init(path: String = DEFAULT_PATH) -> void:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_error = "cannot read board map: %s" % path
		push_error(load_error)
		return
	map = parsed
	grid = int(map["grid"])
	track_length = int(map["track_length"])
	goal_step = int(map["steps_to_goal"])
	last_track_step = goal_step - int(map["home_column_length"]) - 1
	for c: Array in map["track"]:
		track.append(Vector2i(int(c[0]), int(c[1])))
	for i: Variant in map["safe_track_indices"]:
		safe_indices.append(int(i))
		_safe[int(i)] = true
	for i: Variant in map["star_track_indices"]:
		star_indices.append(int(i))
	for color: String in COLORS:
		_start[color] = int(map["start_track_index"][color])
		var column: Array[Vector2i] = []
		for c: Array in map["home_columns"][color]:
			column.append(Vector2i(int(c[0]), int(c[1])))
		home_columns[color] = column
		var yard: Dictionary = map["yards"][color]
		var r: Array = yard["rect"]
		yard_rects[color] = Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		var slots: Array[Vector2] = []
		for s: Array in yard["slots"]:
			slots.append(Vector2(float(s[0]), float(s[1])))
		yard_slots[color] = slots
	for c: Array in map["goal_cells"]:
		goal_cells.append(Vector2i(int(c[0]), int(c[1])))
	for c: Variant in map["two_player_colors"]["default"]:
		two_player_colors.append(String(c))


func start_index(color: String) -> int:
	return int(_start[color])


## Common-track index of a step, or -1 when the step is not on the common track.
func track_index(color: String, step: int) -> int:
	if step < 0 or step > last_track_step:
		return -1
	return (start_index(color) + step) % track_length


func is_safe_track(index: int) -> bool:
	return _safe.has(index)


## Grid cell of a step (-1, -1 for the yard and the goal).
func cell_of(color: String, step: int) -> Vector2i:
	if step < 0 or step >= goal_step:
		return Vector2i(-1, -1)
	if step <= last_track_step:
		return track[track_index(color, step)]
	var column: Array[Vector2i] = home_columns[color]
	return column[step - last_track_step - 1]


## Clockwise quarter turns that bring `color`'s yard to the bottom-left (K-09).
func quarter_turns_to_bottom_left(color: String) -> int:
	return posmod(COLORS.find("blue") - COLORS.find(color), 4)


## Rotates a cell clockwise by `turns` quarter turns around the grid centre.
func rotate_cell(cell: Vector2i, turns: int) -> Vector2i:
	var p := cell
	for i in posmod(turns, 4):
		p = Vector2i(grid - 1 - p.y, p.x)
	return p


## Rotates a point in continuous cell space (0..grid) clockwise.
func rotate_point(point: Vector2, turns: int) -> Vector2:
	var p := point
	for i in posmod(turns, 4):
		p = Vector2(grid - p.y, p.x)
	return p
