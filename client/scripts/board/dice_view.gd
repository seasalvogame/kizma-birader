class_name DiceView
extends Control
## The dice (UI_UX_DESIGN_SYSTEM §7.3): shows a face; roll() spins and wobbles
## for at least DICE_MIN_MS and settles on the value. `active` draws the
## mango halo of the local player's turn (the dice pad).

signal tapped

var value := 6
var skin := "dice_classic":
	set(v):
		skin = v
		_faces.clear()
		if is_node_ready():
			_load_faces()
		queue_redraw()
var active := false:
	set(v):
		active = v
		queue_redraw()
var tappable := false

var _faces: Array[Texture2D] = []
var _spin := 0.0
var _rolling := false
var _pulse := 0.0
var _pulse_tween: Tween


func _ready() -> void:
	_load_faces()
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _load_faces() -> void:
	for i in range(1, 7):
		_faces.append(Cosmetics.dice_face(skin, i))


func set_active(on: bool) -> void:
	active = on
	tappable = on
	if _pulse_tween != null:
		_pulse_tween.kill()
	if on and not Settings.get_value("reduced_motion"):
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_method(func(v: float) -> void:
			_pulse = v
			queue_redraw(), 0.0, TAU, 1.4)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if active:
		var p := 0.5 + 0.5 * sin(_pulse)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1.0, 0.76, 0.35, 0.18 + 0.1 * p)
		box.border_color = Color(1.0, 0.76, 0.35, 0.65)
		box.set_border_width_all(4)
		box.set_corner_radius_all(int(size.x * 0.3))
		box.shadow_color = Color(1.0, 0.6, 0.12, 0.35 + 0.15 * p)
		box.shadow_size = int(20 + 10 * p)
		box.anti_aliasing = true
		draw_style_box(box, r)
	# An inactive die remains readable but is no longer mistaken for the next
	# action.  Bright paper and the mango pad belong exclusively to "roll now".
	var face_size := size * (0.72 if active else 0.62)
	var face_tint := Color.WHITE if active else Color(0.72, 0.67, 0.78, 0.82)
	var center := size * 0.5
	draw_set_transform(center, _spin, Vector2.ONE)
	draw_texture_rect(_faces[clampi(value, 1, 6) - 1], Rect2(-face_size * 0.5, face_size), false, face_tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Spins with random faces, then shows `result`. Duration in seconds.
func roll(result: int, duration: float) -> void:
	# A confirmed outcome still appears, but Reduce Motion never spins, wobbles,
	# or bounces the die.  Callers can keep awaiting this function unchanged.
	if Settings.get_value("reduced_motion"):
		value = result
		_spin = 0.0
		_rolling = false
		queue_redraw()
		return
	_rolling = true
	var total := clampf(duration, 0.35, 0.85)
	# Preparation makes the throw intentional; the intermediate faces are only
	# animation frames. `result` remains the sole final value supplied by the
	# controller/server event.
	var prepare := minf(0.09, total * 0.18)
	var tumble := maxf(0.18, total - prepare - 0.14)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(0.92, 0.92), prepare).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_method(func(k: float) -> void:
		_spin = sin(k * TAU * 3.0) * (0.62 - k * 0.38)
		var frame := clampi(int(k * 9.0), 0, 8)
		value = ((result + frame * 3 - 1) % 6) + 1
		queue_redraw(), 0.0, 1.0, tumble).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	value = result
	_spin = 0.0
	_rolling = false
	queue_redraw()
	var bounce := create_tween()
	bounce.tween_property(self, "scale", Vector2(0.97, 0.97), 0.055)
	bounce.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b != null and b.pressed and b.button_index == MOUSE_BUTTON_LEFT and tappable and not _rolling:
		accept_event()
		tapped.emit()
