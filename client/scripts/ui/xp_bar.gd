class_name XpBar
extends Control
## Level badge + XP progress bar (profile, home): "Sv. 7  ·  120 / 250 XP".
## `animate_to()` fills the bar smoothly (one tween).

var level := 1
var xp_in_level := 0
var xp_for_next := 100
var compact := false          # home screen: thinner, no texts below
var _fill := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_progress(p_level: int, in_level: int, for_next: int) -> void:
	level = p_level
	xp_in_level = in_level
	xp_for_next = for_next
	_fill = 1.0 if for_next <= 0 else clampf(float(in_level) / float(for_next), 0.0, 1.0)
	queue_redraw()


func animate_to(target: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_fill = v
		queue_redraw(), _fill, clampf(target, 0.0, 1.0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var h := 18.0 if compact else 26.0
	var y := (size.y - h) * 0.5
	var r := Rect2(0, y, size.x, h)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.12) if not compact else Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(int(h * 0.5))
	draw_style_box(back, r)
	if _fill > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = UiPalette.MANGO_500
		fill.set_corner_radius_all(int(h * 0.5))
		draw_style_box(fill, Rect2(r.position, Vector2(maxf(h, r.size.x * _fill), h)))
		var shine := StyleBoxFlat.new()
		shine.bg_color = Color(1, 1, 1, 0.25)
		shine.set_corner_radius_all(int(h * 0.25))
		draw_style_box(shine, Rect2(r.position + Vector2(h * 0.3, 3), Vector2(maxf(0, r.size.x * _fill - h * 0.6), h * 0.28)))
