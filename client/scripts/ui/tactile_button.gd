class_name TactileButton
extends Button
## Shared physical response for the standard action and icon buttons.  Layout
## remains owned by containers; the tween affects only the rendered control.

@export_range(0.90, 1.0, 0.005) var press_scale := 0.965
@export_range(1.0, 1.08, 0.005) var hover_scale := 1.015

var _motion: Tween
var _is_down := false


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	if not has_focus() or disabled:
		return
	# Keyboard focus is a crisp, palette-owned ring; touch users never rely on
	# it, but external-keyboard navigation remains visible and intentional.
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color.TRANSPARENT
	ring.border_color = Color(UiPalette.MANGO_300, 0.95)
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(UiTokens.R_L)
	ring.anti_aliasing = true
	draw_style_box(ring, Rect2(2, 2, maxf(0, size.x - 4), maxf(0, size.y - 4)))


func _on_button_down() -> void:
	_is_down = true
	_animate_to(Vector2.ONE * press_scale, UiTokens.T_INSTANT)


func _on_button_up() -> void:
	_is_down = false
	_animate_to(_rest_scale(), UiTokens.T_FAST)


func _on_mouse_entered() -> void:
	if not _is_down and not disabled and not DisplayServer.is_touchscreen_available():
		_animate_to(Vector2.ONE * hover_scale, UiTokens.T_FAST)


func _on_mouse_exited() -> void:
	if not _is_down:
		_animate_to(Vector2.ONE, UiTokens.T_FAST)


func _rest_scale() -> Vector2:
	if is_hovered() and not DisplayServer.is_touchscreen_available() and not disabled:
		return Vector2.ONE * hover_scale
	return Vector2.ONE


func _animate_to(target: Vector2, token_ms: float) -> void:
	if _motion != null:
		_motion.kill()
	if Settings.get_value("reduced_motion"):
		scale = target
		return
	_motion = create_tween()
	_motion.tween_property(self, "scale", target, UiTokens.duration(token_ms)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
