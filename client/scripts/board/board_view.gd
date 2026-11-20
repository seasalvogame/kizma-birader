class_name BoardView
extends Control
## The classic star board drawn from BoardGeometry (board_map.json) — no
## geometry is hard-coded here (MAP_SPECIFICATION §7, UI_UX_DESIGN_SYSTEM §7).
## Always square (the largest square that fits), rotated in quarter turns so
## the local player's yard is bottom-left (K-09); symbols stay upright.
## Pawn sprites are children (PawnSprite); this node draws the board, the
## target rings and the last-move trail, and turns taps into pawn picks.

signal pawn_tapped(color: String, pawn: int)

const PAWN_TOUCH_RADIUS := 88.0  # 44 pt

var board: BoardGeometry
var turns := 0
var colors_in_game: Array[String] = []
var show_symbols := true
var theme_id := "board_classic"
## Selectable pawns: [{color, pawn}] ; targets: [{color, step}] ; trail: {color, from, to}
var selectable: Array = []
var targets: Array = []
var trail: Dictionary = {}
var pawns := {}  # "color:index" -> PawnSprite

var _side := 0.0
var _origin := Vector2.ZERO


func setup(p_board: BoardGeometry, p_colors: Array, local_color: String) -> void:
	board = p_board
	colors_in_game.clear()
	for c: Variant in p_colors:
		colors_in_game.append(String(c))
	turns = board.quarter_turns_to_bottom_left(local_color)
	_layout()


## A board cosmetic is presentation only, so a confirmed loadout update can
## repaint the live board without rebuilding its geometry, input map or state.
func set_theme_id(value: String) -> void:
	theme_id = value if Cosmetics.BOARDS.has(value) else "board_classic"
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)


func _layout() -> void:
	_side = minf(size.x, size.y)
	_origin = (size - Vector2(_side, _side)) * 0.5
	for key: String in pawns:
		(pawns[key] as PawnSprite).cell_size = cell_size()
	queue_redraw()


func cell_size() -> float:
	return _side / 15.0 if board != null else 0.0


func board_rect() -> Rect2:
	return Rect2(_origin, Vector2(_side, _side))


## Top-left corner of a (rotated) grid cell, in local coordinates.
func cell_rect(cell: Vector2i) -> Rect2:
	var r := board.rotate_cell(cell, turns)
	var c := cell_size()
	return Rect2(_origin + Vector2(r) * c, Vector2(c, c))


## A point in continuous cell space (0..15), rotated, to local coordinates.
func grid_point(p: Vector2) -> Vector2:
	return _origin + board.rotate_point(p, turns) * cell_size()


## Where a pawn stands: yard slot, cell centre or its colour's goal triangle.
func pawn_position(color: String, step: int, pawn: int) -> Vector2:
	if step < 0:
		var slot: Vector2 = board.yard_slots[color][pawn]
		return grid_point(slot + Vector2(0.5, 0.5))
	if step >= board.goal_step:
		var dir := _goal_direction(color)
		var side := Vector2(-dir.y, dir.x)
		return grid_point(Vector2(7.5, 7.5) + dir * 0.95 + side * (pawn - 1.5) * 0.32)
	return cell_rect(board.cell_of(color, step)).get_center()


func _goal_direction(color: String) -> Vector2:
	# Unrotated: the corridor K5 cell of the colour, seen from the centre.
	var k5: Vector2i = (board.home_columns[color] as Array)[4]
	return (Vector2(k5) + Vector2(0.5, 0.5) - Vector2(7.5, 7.5)).normalized()


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	if board == null:
		return
	var c := cell_size()
	var rect := board_rect()
	var palette := Cosmetics.board_palette(theme_id)
	# A warm tabletop rim gives the board a clear physical boundary while all
	# grid geometry, paths and tap positions remain exactly as before.
	_draw_round_rect(rect.grow(c * 0.26), c * 1.08, Color(UiPalette.NIGHT_900, 0.44))
	_draw_round_rect(rect.grow(c * 0.14), c * 1.0, Color(1, 1, 1, 0.10))
	_draw_round_rect(rect, c * 0.9, palette["board"])
	_draw_round_rect(rect.grow(-c * 0.10), c * 0.78, Color(UiPalette.CREAM_HIGHLIGHT, 0.20))
	for color: String in BoardGeometry.COLORS:
		_draw_yard(color)
	var starts := {}
	for color: String in BoardGeometry.COLORS:
		starts[board.start_index(color)] = color
	for i in board.track.size():
		var cell := board.track[i]
		var r := cell_rect(cell).grow(-c * 0.06)
		if starts.has(i):
			var color: String = starts[i]
			_draw_round_rect(r, c * 0.2, UiPalette.player(color, "dark"))
			_draw_round_rect(r.grow(-c * 0.04), c * 0.18, UiPalette.player(color))
			_draw_start_arrow(i, r)
		else:
			_draw_round_rect(r, c * 0.2, palette["edge"])
			_draw_round_rect(r.grow(-c * 0.03), c * 0.18, palette["cell"])
			if board.star_indices.has(i):
				_draw_star(r.get_center(), c * 0.36, palette["star"], palette["star_edge"])
	for color: String in BoardGeometry.COLORS:
		for cell: Vector2i in board.home_columns[color]:
			var r := cell_rect(cell).grow(-c * 0.06)
			_draw_round_rect(r, c * 0.2, UiPalette.player(color, "dark"))
			_draw_round_rect(r.grow(-c * 0.04), c * 0.18, UiPalette.player(color))
	_draw_goal(palette)
	_draw_trail()
	for t: Dictionary in targets:
		var p := pawn_position(t["color"], int(t["step"]), int(t.get("pawn", 0)))
		var col := UiPalette.player(t["color"])
		draw_arc(p, c * 0.36, 0, TAU, 32, col, c * 0.09, true)
		draw_circle(p, c * 0.12, col)


func _draw_yard(color: String) -> void:
	var c := cell_size()
	var r: Rect2i = board.yard_rects[color]
	var a := grid_point(Vector2(r.position))
	var b := grid_point(Vector2(r.position + r.size))
	var rect := Rect2(a, b - a).abs()
	var dim := 1.0 if colors_in_game.has(color) else 0.35
	_draw_round_rect(rect, c * 0.9, Color(UiPalette.player(color), dim))
	_draw_round_rect(rect.grow(-c * 0.85), c * 0.75, Color(UiPalette.CREAM_50, maxf(dim, 0.85)))
	for slot: Vector2 in board.yard_slots[color]:
		var p := grid_point(slot + Vector2(0.5, 0.5))
		draw_circle(p, c * 0.62, Color(UiPalette.player(color, "soft"), dim))
		draw_arc(p, c * 0.62, 0, TAU, 40, Color(UiPalette.player(color), dim), c * 0.1, true)
	if show_symbols:
		# Symbol in the yard's outer corner (the corner farthest from the centre).
		var centre := _origin + Vector2(_side, _side) * 0.5
		var corner := rect.position
		for p: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
			if p.distance_to(centre) > corner.distance_to(centre):
				corner = p
		var inward := (centre - corner).normalized()
		draw_symbol(self, UiPalette.PLAYER[color]["symbol"], corner + inward * c * 0.75, c * 0.24, Color(1, 1, 1, 0.85 * dim))


func _draw_start_arrow(track_index: int, r: Rect2) -> void:
	var here := cell_rect(board.track[track_index]).get_center()
	var next := cell_rect(board.track[(track_index + 1) % board.track_length]).get_center()
	var d := (next - here).normalized()
	var n := Vector2(-d.y, d.x)
	var c := cell_size()
	var tip := r.get_center() + d * c * 0.2
	var back := r.get_center() - d * c * 0.2
	draw_colored_polygon(PackedVector2Array([tip, back + n * c * 0.22, back - n * c * 0.22]), Color(1, 1, 1, 0.9))


func _draw_goal(palette: Dictionary) -> void:
	var c := cell_size()
	var m := grid_point(Vector2(7.5, 7.5))
	var corners := {
		"red": [Vector2(6, 6), Vector2(6, 9)], "green": [Vector2(6, 6), Vector2(9, 6)],
		"yellow": [Vector2(9, 6), Vector2(9, 9)], "blue": [Vector2(6, 9), Vector2(9, 9)],
	}
	for color: String in corners:
		var a := grid_point(corners[color][0])
		var b := grid_point(corners[color][1])
		draw_colored_polygon(PackedVector2Array([a, b, m]), UiPalette.player(color))
		draw_polyline(PackedVector2Array([a, b, m, a]), palette["board"], c * 0.08, true)
	draw_circle(m, c * 0.55, palette["board"])
	_draw_star(m, c * 0.42, palette["star"], palette["star_edge"])


func _draw_trail() -> void:
	if trail.is_empty():
		return
	var color: String = trail["color"]
	var pawn := int(trail.get("pawn", 0))
	var from := maxi(int(trail["from"]), 0)
	var to := int(trail["to"])
	var c := cell_size()
	var pts := PackedVector2Array()
	for st in range(from, to + 1):
		pts.append(pawn_position(color, st, pawn))
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var steps := int(a.distance_to(b) / (c * 0.37))
		for k in steps:
			draw_circle(a.lerp(b, (k + 0.5) / steps), c * 0.06, Color(UiPalette.player(color), 0.75))


func _draw_star(center: Vector2, r: float, color: Color = UiPalette.STAR, edge: Color = UiPalette.STAR_EDGE) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.46
		var a := -PI / 2 + k * PI / 5
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, edge, maxf(1.0, r * 0.1), true)


func _draw_round_rect(rect: Rect2, radius: float, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	box.corner_detail = 6
	draw_style_box(box, rect)


static func draw_symbol(canvas: CanvasItem, kind: String, p: Vector2, r: float, color: Color) -> void:
	match kind:
		"triangle":
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.95, r * 0.7), p + Vector2(-r * 0.95, r * 0.7)]), color)
		"circle":
			canvas.draw_circle(p, r * 0.85, color)
		"square":
			canvas.draw_rect(Rect2(p - Vector2(r, r) * 0.75, Vector2(r, r) * 1.5), color)
		_:
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), color)


# --- Input -----------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var tap := event as InputEventMouseButton
	if tap == null or not tap.pressed or tap.button_index != MOUSE_BUTTON_LEFT:
		return
	var best := {}
	var best_d := PAWN_TOUCH_RADIUS
	for s: Dictionary in selectable:
		var sprite: PawnSprite = pawns.get("%s:%d" % [s["color"], int(s["pawn"])])
		if sprite == null:
			continue
		var d := sprite.position.distance_to(tap.position)
		if d < best_d:
			best_d = d
			best = s
	if not best.is_empty():
		accept_event()
		pawn_tapped.emit(best["color"], int(best["pawn"]))
