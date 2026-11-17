class_name PlayCard
extends Button
## Big coloured "2 Kişi / 4 Kişi" card of the home screen (prototype
## 03_ana_menu): 3D bottom edge, title, subtitle, a cream "Play ▸" pill and a
## tilted dice. Drawn in code; presses sink the card like the game buttons.

var title := ""
var subtitle := ""
var pill := ""
var base := Color("#3a7bf7")
var light := Color("#6f9dff")
var dark := Color("#1f4fb8")
var dice_value := 6
var _dice: Texture2D

const EDGE := 14


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, 360)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_dice = load("res://assets/dice/dice_%d.svg" % dice_value)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var down := is_pressed() or get_draw_mode() == DRAW_PRESSED
	var y := 8.0 if down else 0.0
	var h := size.y - EDGE
	var r := UiTokens.R_XL
	var edge := StyleBoxFlat.new()
	edge.bg_color = dark
	edge.set_corner_radius_all(r)
	draw_style_box(edge, Rect2(0, EDGE, size.x, h))
	var face := StyleBoxFlat.new()
	face.bg_color = base
	face.set_corner_radius_all(r)
	draw_style_box(face, Rect2(0, y, size.x, h))
	# soft top light: stacked rounded bands fading out towards the middle
	var bands := 10
	for i in bands:
		var k := float(i) / bands
		var band := StyleBoxFlat.new()
		band.bg_color = Color(light, 0.09)
		band.set_corner_radius_all(r)
		draw_style_box(band, Rect2(0, y, size.x, h * (0.62 - 0.5 * k)))
	# dice in the lower right corner, slightly turned
	if _dice != null:
		var ds := minf(size.x * 0.46, 150.0)
		var c := Vector2(size.x - ds * 0.5 - 6, y + h - ds * 0.42)
		draw_set_transform(c, deg_to_rad(-12), Vector2.ONE)
		draw_texture_rect(_dice, Rect2(-ds * 0.5, -ds * 0.5, ds, ds), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var pad := 34.0
	var title_font := UiTheme.display_font()
	draw_string(title_font, Vector2(pad, y + pad + 52), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - pad * 2, UiTokens.H1, Color.WHITE)
	draw_string(UiTheme.body_font(800), Vector2(pad, y + pad + 100), subtitle, HORIZONTAL_ALIGNMENT_LEFT, size.x - pad * 2, UiTokens.LABEL, Color(1, 1, 1, 0.88))
	# cream pill "Play ▸"
	var pill_font := UiTheme.display_font()
	var tw := pill_font.get_string_size(pill, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.BUTTON_TEXT_S).x
	var pw := tw + 96.0
	var pr := Rect2(pad - 6, y + h - 116, pw, 80)
	var pill_edge := StyleBoxFlat.new()
	pill_edge.bg_color = Color(dark, 0.9)
	pill_edge.set_corner_radius_all(40)
	draw_style_box(pill_edge, Rect2(pr.position + Vector2(0, 6), pr.size))
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = UiPalette.CREAM_50
	pill_box.set_corner_radius_all(40)
	draw_style_box(pill_box, pr)
	draw_string(pill_font, pr.position + Vector2(32, 54), pill, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.BUTTON_TEXT_S, UiPalette.INK_900)
	var tri := pr.position + Vector2(32 + tw + 18, 40)
	draw_colored_polygon(PackedVector2Array([tri + Vector2(0, -10), tri + Vector2(14, 0), tri + Vector2(0, 10)]), UiPalette.INK_900)
