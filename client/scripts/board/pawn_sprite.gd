class_name PawnSprite
extends Node2D
## One pawn (UI_UX_DESIGN_SYSTEM §7.2): the colour's SVG sprite, a pulsing
## halo when selectable, and the movement animations (hop cell by cell,
## fly home when captured, shrink into the goal). Position = the cell centre.

var color := "red"
var index := 0
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
var _halo_phase := 0.0
var _halo_tween: Tween
var _goal_scale := 1.0


func _init(p_color: String = "red", p_index: int = 0) -> void:
	color = p_color
	index = p_index


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/pawns/pawn_%s.svg" % color)
	add_child(_sprite)
	_apply_scale()


func _apply_scale() -> void:
	if _sprite == null:
		return
	# The SVG is 128 px for a 128 px "cell" with margins: one cell = 100 SVG units.
	var s := cell_size / 100.0 * _goal_scale
	_sprite.scale = Vector2(s, s)
	queue_redraw()


func set_finished_look(finished: bool) -> void:
	_goal_scale = 0.7 if finished else 1.0
	_apply_scale()


func _draw() -> void:
	if not selectable:
		return
	var glow: Color = UiPalette.player(color, "light")
	var pulse := 0.5 + 0.5 * sin(_halo_phase)
	draw_circle(Vector2(0, cell_size * 0.05), cell_size * (0.58 + 0.06 * pulse), Color(glow, 0.55 + 0.25 * pulse))
	draw_arc(Vector2(0, cell_size * 0.05), cell_size * 0.56, 0, TAU, 40, Color(1, 1, 1, 0.95), cell_size * 0.08, true)


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
	var from := position
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		var e := ease(k, 0.4)
		position = from.lerp(target, e) + Vector2(0, -sin(k * PI) * cell_size * 1.6), 0.0, 1.0, duration)
	await t.finished


func pop() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.09)
	t.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
