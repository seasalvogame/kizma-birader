class_name StatusCard
extends PanelContainer
## Loading / error / offline / empty state used by the online screens: a glass
## card with a small animated dice (loading) or an icon, a message and an
## optional action button. One instance switches between the states.

signal action_pressed

var _icon: TextureRect
var _label: Label
var _button: Button
var _spin := false
var _phase := 0.0
var _dice: Texture2D


func _ready() -> void:
	theme_type_variation = "GlassPanel"
	_dice = load("res://assets/dice/dice_5.svg")
	var col := UiKit.vbox(UiTokens.S2)
	add_child(col)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(80, 80)
	_icon.pivot_offset = Vector2(40, 40)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_icon)
	_label = UiKit.label("", "BodyLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_label)
	_button = UiKit.button("", "primary", "s")
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.custom_minimum_size = Vector2(320, UiTokens.BUTTON_S)
	_button.mouse_filter = Control.MOUSE_FILTER_PASS
	_button.pressed.connect(func() -> void: action_pressed.emit())
	col.add_child(_button)
	hide()


func loading(text: String) -> void:
	_show_state("", text, "", true)


func error(text: String, action: String = "") -> void:
	_show_state("wifi_off", text, action, false)


func empty(icon: String, text: String, action: String = "") -> void:
	_show_state(icon, text, action, false)


func clear() -> void:
	_spin = false
	hide()


func _show_state(icon: String, text: String, action: String, spin: bool) -> void:
	_label.text = text
	_button.text = action
	_button.visible = action != ""
	_spin = spin
	_icon.rotation = 0.0
	_icon.texture = _dice if spin else (UiTheme.icon(icon) if icon != "" else null)
	_icon.visible = _icon.texture != null
	show()


func _process(delta: float) -> void:
	if _spin and visible:
		_phase += delta
		_icon.rotation = _phase * 3.0
