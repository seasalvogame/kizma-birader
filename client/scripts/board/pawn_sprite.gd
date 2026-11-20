class_name PawnSprite
extends Node2D
## One pawn (UI_UX_DESIGN_SYSTEM §7.2): a cosmetic sprite, a readable player
## symbol, a pulsing halo when selectable, and the movement animations (hop
## cell by cell, fly home when captured, shrink into the goal). Position =
## the cell centre.

var color := "red"
var index := 0
var skin := "pawns_classic"
var step := -1
var cell_size := 44.0:
	set(v):
		cell_size = v
		_apply_scale()
var selectable := false:
	set(v):
		if v == selectable:
			return
		selectable = v
		_update_halo()

var _sprite: Sprite2D
var _mark: Node2D
var _halo_phase := 0.0
var _halo_tween: Tween
var _goal_scale := 1.0
var _stack_scale := 1.0
var _stack_count := 1


func _init(p_color: String = "red", p_index: int = 0, p_skin: String = "pawns_classic") -> void:
	color = p_color
	index = p_index
	skin = p_skin


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = Cosmetics.pawn_texture(skin, color)
	_sprite.z_index = 1
	add_child(_sprite)
	_mark = Node2D.new()
	_mark.z_index = 2
	_mark.draw.connect(_draw_mark)
	add_child(_mark)
	_apply_scale()


func _apply_scale() -> void:
	if _sprite == null:
		return
	# Both the 128 px SVG cosmetics and the 512 px painted PNGs are framed to
	# the same visual footprint, so texture resolution never changes gameplay.
	var source_size := maxf(_sprite.texture.get_size().x, _sprite.texture.get_size().y)
	var s := cell_size * 1.28 / maxf(source_size, 1.0) * _goal_scale * _stack_scale
	_sprite.scale = Vector2(s, s)
	if _mark != null:
		_mark.queue_redraw()
	queue_redraw()


func set_finished_look(finished: bool) -> void:
	_goal_scale = 0.7 if finished else 1.0
	_apply_scale()


## Updates only the visual texture.  Position, step, hit target and every
## game-rule value stay untouched, allowing an equipped pawn look to appear
## during an active match without waiting for the next match instance.
func set_skin(value: String) -> void:
	skin = value if value != "" else "pawns_classic"
	if _sprite != null:
		_sprite.texture = Cosmetics.pawn_texture(skin, color)
		_apply_scale()


## Same-cell clustering is visual-only.  It never changes the pawn's path,
## input target, or server/local rule position.
func set_stack_count(count: int) -> void:
	_stack_count = clampi(count, 1, 4)
	# At three pieces the previous 0.41 scale grazed a cell edge once the
	# triangular offset was applied.  0.40 keeps a measurable visual gutter.
	_stack_scale = [1.0, 0.48, 0.40, 0.36][_stack_count - 1]
	_apply_scale()


func visual_half_extent() -> float:
	# The artwork is framed at 1.28 cells wide in _apply_scale().
	return cell_size * 0.64 * _goal_scale * _stack_scale


func _draw() -> void:
	if not selectable:
		return
	var glow: Color = UiPalette.player(color, "light")
	var pulse := 0.5 + 0.5 * sin(_halo_phase)
	draw_circle(Vector2(0, cell_size * 0.05), cell_size * (0.58 + 0.06 * pulse), Color(glow, 0.55 + 0.25 * pulse))
	draw_arc(Vector2(0, cell_size * 0.05), cell_size * 0.56, 0, TAU, 40, Color(1, 1, 1, 0.95), cell_size * 0.08, true)


## A compact medallion keeps the player symbol recognisable even with a
## detailed PNG skin; colour is never the only cue on the board.
func _draw_mark() -> void:
	var r := cell_size * 0.18 * _goal_scale
	if r <= 0.0:
		return
	var p := Vector2(0, cell_size * 0.02 * _goal_scale)
	_mark.draw_circle(p, r, Color(UiPalette.CREAM_50, 0.94))
	_mark.draw_arc(p, r, 0, TAU, 28, UiPalette.player(color, "dark"), maxf(1.5, cell_size * 0.045), true)
	var symbol_r := r * 0.54
	match String(UiPalette.PLAYER[color]["symbol"]):
		"triangle":
			_mark.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -symbol_r), p + Vector2(symbol_r * 0.95, symbol_r * 0.7), p + Vector2(-symbol_r * 0.95, symbol_r * 0.7)]), UiPalette.player(color, "dark"))
		"circle":
			_mark.draw_circle(p, symbol_r * 0.82, UiPalette.player(color, "dark"))
		"square":
			_mark.draw_rect(Rect2(p - Vector2(symbol_r, symbol_r) * 0.72, Vector2(symbol_r, symbol_r) * 1.44), UiPalette.player(color, "dark"))
		_:
			_mark.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -symbol_r), p + Vector2(symbol_r, 0), p + Vector2(0, symbol_r), p + Vector2(-symbol_r, 0)]), UiPalette.player(color, "dark"))


func _update_halo() -> void:
	if _halo_tween != null:
		_halo_tween.kill()
		_halo_tween = null
	if selectable and not Settings.get_value("reduced_motion"):
		_halo_tween = create_tween().set_loops()
		_halo_tween.tween_method(func(v: float) -> void:
			_halo_phase = v
			queue_redraw(), 0.0, TAU, 1.2)
	queue_redraw()


## Hops through `points` (one per cell), ~90 ms per cell.
func hop_along(points: Array[Vector2], per_step: float) -> void:
	if Settings.get_value("reduced_motion"):
		if not points.is_empty():
			position = points.back()
		return
	var t := create_tween()
	var prev := position
	for p: Vector2 in points:
		t.tween_method(_hop.bind(prev, p), 0.0, 1.0, per_step)
		prev = p
	await t.finished


func _hop(k: float, a: Vector2, b: Vector2) -> void:
	position = a.lerp(b, k) + Vector2(0, -sin(k * PI) * cell_size * 0.35)


## Flies home on an arc (captured).
func fly_to(target: Vector2, duration: float) -> void:
	if Settings.get_value("reduced_motion"):
		position = target
		return
	var from := position
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		var e := ease(k, 0.4)
		position = from.lerp(target, e) + Vector2(0, -sin(k * PI) * cell_size * 1.6), 0.0, 1.0, duration)
	await t.finished


func pop() -> void:
	if Settings.get_value("reduced_motion"):
		scale = Vector2.ONE
		return
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.09)
	t.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
