class_name BootScreen
extends Control
## Startup surface bound to the real session/profile/catalog preparation path.

signal retry_requested

var _message: Label
var _retry: Button
var _continue: Button
var _spinner: Control
var _phase := 0.0
var _loading := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(NightBackground.new())
	var body := VBoxContainer.new()
	body.set_anchors_preset(Control.PRESET_CENTER)
	body.offset_left = -230
	body.offset_right = 230
	body.offset_top = -190
	body.offset_bottom = 190
	body.add_theme_constant_override("separation", UiTokens.S4)
	add_child(body)
	var crest := Control.new()
	crest.custom_minimum_size = Vector2(0, 170)
	crest.draw.connect(_draw_crest.bind(crest))
	body.add_child(crest)
	var title := UiKit.label("Kızma Birader", "DisplayLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 66)
	body.add_child(title)
	var subtitle := UiKit.label(tr("BOOT_SUBTITLE"), "DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(subtitle)
	_spinner = Control.new()
	_spinner.custom_minimum_size = Vector2(0, 92)
	_spinner.draw.connect(_draw_spinner.bind(_spinner))
	body.add_child(_spinner)
	_message = UiKit.label("", "BodyLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)
	_retry = UiKit.button("", "primary")
	_retry.visible = false
	_retry.pressed.connect(func() -> void: retry_requested.emit())
	body.add_child(_retry)
	_continue = UiKit.button("", "ghost")
	_continue.visible = false
	_continue.pressed.connect(_continue_offline)
	body.add_child(_continue)


func _process(delta: float) -> void:
	if _loading and not Settings.get_value("reduced_motion"):
		_phase += delta
		_spinner.queue_redraw()


func set_loading(message: String) -> void:
	_loading = true
	_message.text = message
	_retry.hide()
	_continue.hide()


func show_error(message: String, retry_text: String, continue_text: String) -> void:
	_loading = false
	_message.text = message
	_message.add_theme_color_override("font_color", UiPalette.ON_NIGHT)
	_retry.text = retry_text
	_continue.text = continue_text
	_retry.show()
	_continue.show()


func set_buttons_enabled(enabled: bool) -> void:
	_retry.disabled = not enabled
	_continue.disabled = not enabled


func _continue_offline() -> void:
	var main := get_parent().get_parent()
	if main != null and main.has_method("continue_offline"):
		main.call("continue_offline")


func _draw_crest(node: Control) -> void:
	var c := Vector2(node.size.x * 0.5, 82)
	node.draw_circle(c, 70, Color(UiPalette.MANGO_500, 0.16))
	node.draw_circle(c, 52, UiPalette.CREAM_50)
	node.draw_circle(c, 43, UiPalette.MANGO_500)
	node.draw_arc(c, 43, 0, TAU, 48, UiPalette.MANGO_300, 5, true)
	Cosmetics._star(node, c, 21, UiPalette.CREAM_50)


func _draw_spinner(node: Control) -> void:
	var c := Vector2(node.size.x * 0.5, 42)
	for i in 3:
		var alpha := 0.35 + 0.65 * maxf(0.0, sin(_phase * 4.0 - i * 0.8))
		node.draw_circle(c + Vector2((i - 1) * 26, 0), 7, Color(UiPalette.MANGO_300, alpha))
