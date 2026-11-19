class_name Avatar
extends Control
## Round avatar with the player-colour ring (UI_UX_DESIGN_SYSTEM §5.3).
## PLACEHOLDER art: an initial on a warm gradient disc (final avatar set: K-42,
## see assets/ASSETS.md). Bots show a robot glyph. When `timer` is on, a
## mango countdown ring runs around it.

var initial := "?"
var ring_color := Color.WHITE
var is_bot := false
var dim := false
var progress := -1.0:   # 0..1 time left; < 0 = no timer ring
	set(v):
		progress = v
		queue_redraw()
var urgent := false
var rank := 0           # > 0: finished, show the place
var frame_id := "frame_none"
var effect_id := "effect_none"
var _cosmetic_phase := 0.0

var _fill_top := Color("#ffb36b")
var _fill_bottom := Color("#ff7a45")
var _robot: Texture2D

const FILLS := [
	[Color("#ffb36b"), Color("#ff7a45")], [Color("#c9a7ff"), Color("#8a52ff")], [Color("#7fd6ff"), Color("#3a8fd8")],
	[Color("#ffd27a"), Color("#e8a020")], [Color("#9be7c4"), Color("#2fa77a")], [Color("#ff9fb8"), Color("#e0507a")],
]


## Picks one of the FILLS gradients (profile avatar colour).
func set_fill(index: int) -> void:
	var fill: Array = FILLS[posmod(index, FILLS.size())]
	_fill_top = fill[0]
	_fill_bottom = fill[1]
	queue_redraw()


func setup(name: String, color: String, bot: bool) -> void:
	initial = name.substr(0, 1).to_upper() if name != "" else "?"
	ring_color = UiPalette.player(color)
	is_bot = bot
	var fill: Array = FILLS[absi(name.hash()) % FILLS.size()]
	_fill_top = fill[0]
	_fill_bottom = fill[1]
	if bot:
		_robot = UiTheme.icon("robot")
		_fill_top = Color("#5b4a8c")
		_fill_bottom = Color("#3a2a6b")
	queue_redraw()


func set_cosmetics(p_frame: String, p_effect: String) -> void:
	frame_id = p_frame
	effect_id = p_effect
	queue_redraw()


func _process(delta: float) -> void:
	if (frame_id != "frame_none" or effect_id != "effect_none") and not Settings.get_value("reduced_motion"):
		_cosmetic_phase += delta
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 8.0
	var a := 0.45 if dim else 1.0
	Cosmetics.draw_effect(self, effect_id, c, r, _cosmetic_phase)
	if progress >= 0.0:
		draw_arc(c, r + 7, 0, TAU, 48, Color(1, 1, 1, 0.12), 7, true)
		var col := UiPalette.DANGER_500 if urgent else UiPalette.MANGO_500
		draw_arc(c, r + 7, -PI / 2, -PI / 2 + TAU * clampf(progress, 0, 1), 48, col, 7, true)
	draw_circle(c, r + 3, Color(ring_color, a))
	# vertical gradient disc
	var steps := 16
	for i in steps:
		var y0 := -r + 2.0 * r * i / steps
		var y1 := -r + 2.0 * r * (i + 1) / steps
		var col := _fill_top.lerp(_fill_bottom, (i + 0.5) / steps)
		var w0 := sqrt(maxf(0.0, (r - 3) * (r - 3) - y0 * y0))
		var w1 := sqrt(maxf(0.0, (r - 3) * (r - 3) - y1 * y1))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-w0, y0), c + Vector2(w0, y0), c + Vector2(w1, y1), c + Vector2(-w1, y1)]), Color(col, a))
	if is_bot and _robot != null:
		var s := r * 1.1
		draw_texture_rect(_robot, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))
	else:
		var font := UiTheme.display_font()
		var fs := int(r * 0.95)
		var w := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
	if rank > 0:
		var b := Vector2(c.x + r * 0.72, c.y + r * 0.72)
		draw_circle(b, r * 0.38, UiPalette.GOLD_500)
		var font := UiTheme.display_font()
		var fs := int(r * 0.42)
		var txt := str(rank)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, b + Vector2(-w * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#4a2d00"))
	Cosmetics.draw_frame(self, frame_id, c, r, _cosmetic_phase)
