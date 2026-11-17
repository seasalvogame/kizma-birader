class_name Celebration
extends Control
## Reward moment (level up, reward claimed, achievement): dimmed night sky, a cream
## card with a star burst, title, lines and a "Harika!" button. One tween for the card
## and a few drawn stars rotating slowly — cheap on low-end Android; reduced motion
## shows it without movement. Closes on tap or after a few seconds.

signal closed

var title := ""
var subtitle := ""
var lines: Array = []       # [String] or [[icon_name, String]]
var accent := UiPalette.GOLD_300
var auto_close := 4.5

var _card: PanelContainer
var _burst: Control
var _phase := 0.0
var _closing := false


## Shows a celebration on top of `host` (usually the current screen).
static func pop(host: Node, p_title: String, p_subtitle: String, p_lines: Array = [], p_accent: Color = UiPalette.GOLD_300) -> Celebration:
	var c := Celebration.new()
	c.title = p_title
	c.subtitle = p_subtitle
	c.lines = p_lines
	c.accent = p_accent
	host.add_child(c)
	return c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3000
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiPalette.NIGHT_900, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_burst = Control.new()
	_burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst.draw.connect(_draw_burst)
	add_child(_burst)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.theme_type_variation = "CreamCard"
	_card.custom_minimum_size = Vector2(560, 0)
	center.add_child(_card)
	var col := UiKit.vbox(UiTokens.S2)
	_card.add_child(col)
	var star := TextureRect.new()
	star.texture = UiTheme.icon("star")
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.custom_minimum_size = Vector2(0, 110)
	star.modulate = accent.darkened(0.15)
	col.add_child(star)
	var t := UiKit.label(title, "InkH2Label", HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", UiPalette.MANGO_700)
	col.add_child(t)
	if subtitle != "":
		var s := UiKit.label(subtitle, "InkBodyLabel", HORIZONTAL_ALIGNMENT_CENTER)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(s)
	for line: Variant in lines:
		var row := UiKit.hbox(UiTokens.S1)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var text: String = line if line is String else ""
		if line is Array:
			var ic := TextureRect.new()
			ic.texture = UiTheme.icon(String(line[0]))
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.custom_minimum_size = Vector2(48, 48)
			ic.modulate = UiPalette.MANGO_700
			row.add_child(ic)
			text = String(line[1])
		row.add_child(UiKit.label(text, "InkH3Label"))
		col.add_child(row)
	var ok := UiKit.button(tr("CELEBRATE_OK"), "primary", "s")
	ok.mouse_filter = Control.MOUSE_FILTER_PASS
	ok.pressed.connect(close)
	col.add_child(ok)
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())
	Settings.vibrate(60)
	if not Settings.get_value("reduced_motion"):
		_card.modulate.a = 0.0
		_card.scale = Vector2(0.6, 0.6)
		await get_tree().process_frame
		_card.pivot_offset = _card.size * 0.5
		var tw := create_tween().set_parallel()
		tw.tween_property(_card, "modulate:a", 1.0, 0.2)
		tw.tween_property(_card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if auto_close > 0:
		get_tree().create_timer(auto_close).timeout.connect(close)


func _process(delta: float) -> void:
	if not Settings.get_value("reduced_motion"):
		_phase += delta
		_burst.queue_redraw()


func _draw_burst() -> void:
	var c := size * 0.5 - Vector2(0, 120)
	for i in 12:
		var a := _phase * 0.4 + TAU * i / 12.0
		var r := 330.0 + 24.0 * sin(_phase * 2.0 + i)
		var p := c + Vector2(cos(a), sin(a)) * r
		_burst.draw_circle(p, 7.0 if i % 2 == 0 else 4.0, Color(accent, 0.75))
	_burst.draw_circle(c, 250, Color(accent, 0.07))


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	if Settings.get_value("reduced_motion") or not is_inside_tree():
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)
