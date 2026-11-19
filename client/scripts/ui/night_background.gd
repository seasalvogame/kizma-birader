class_name NightBackground
extends Control
## Screen background of "Akşam Masası" (UI_UX_DESIGN_SYSTEM §2.1): radial
## night gradient centred at 38 % height, faint star field, optional warm
## lamp glow behind the board. Drawn once (static).

@export var glow_center := Vector2(0.5, 0.42)
@export var glow_radius := 0.62
@export var show_glow := true

var _gradient_texture: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# anchors AND offsets: set_anchors_preset alone left the size at (0, 0).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.38, 0.70, 1.0])
	g.colors = PackedColorArray([UiPalette.NIGHT_600, UiPalette.NIGHT_700, UiPalette.NIGHT_800, UiPalette.NIGHT_900])
	_gradient_texture = GradientTexture2D.new()
	_gradient_texture.gradient = g
	_gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	_gradient_texture.fill_from = Vector2(0.5, 0.38)
	_gradient_texture.fill_to = Vector2(1.15, 1.05)
	_gradient_texture.width = 256
	_gradient_texture.height = 512
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_texture_rect(_gradient_texture, Rect2(Vector2.ZERO, size), false)
	if show_glow:
		var c := size * glow_center
		var r := size.x * glow_radius
		for i in 36:
			var k := 1.0 - i / 36.0
			draw_circle(c, r * k, Color(UiPalette.GLOW.r, UiPalette.GLOW.g, UiPalette.GLOW.b, 0.0085))
	# Fixed, deliberately sparse star field (same on every run).  The board and
	# content should read as the illuminated objects; stars are a signature, not
	# visual noise across every menu and state.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261116
	var count := int(size.x * size.y / 22000.0)
	for i in count:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var warm := rng.randf() < 0.3
		var a := rng.randf_range(0.18, 0.48)
		draw_circle(p, rng.randf_range(1.0, 2.1), Color(1.0, 0.91, 0.69, a) if warm else Color(1, 1, 1, a))
