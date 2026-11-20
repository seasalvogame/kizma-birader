class_name UiKit
extends RefCounted
## Small builders for the design system (keeps screens short and consistent).

const TACTILE_BUTTON := preload("res://scripts/ui/tactile_button.gd")


static func label(text: String, variation: String = "BodyLabel", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## kind: primary | secondary | berry | mint | ghost ; size: s | l | xl
static func button(text: String, kind: String = "primary", size: String = "l") -> Button:
	# Do not rely on Godot's editor-owned global-class cache in exported or
	# headless builds: the shared button script is explicitly preloaded.
	var b: Button = TACTILE_BUTTON.new()
	b.text = text
	b.theme_type_variation = kind.capitalize() + "Button"
	var h := UiTokens.BUTTON_L
	var font := UiTokens.BUTTON_TEXT
	match size:
		"s":
			h = UiTokens.BUTTON_S
			font = UiTokens.BUTTON_TEXT_S
		"xl":
			h = UiTokens.BUTTON_XL
			font = UiTokens.BUTTON_TEXT_XL
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", font)
	b.focus_mode = Control.FOCUS_ALL
	return b


static func icon_button(icon_name: String, tooltip: String = "") -> Button:
	var b: Button = TACTILE_BUTTON.new()
	b.theme_type_variation = "IconButton"
	b.icon = UiTheme.icon(icon_name)
	b.expand_icon = true
	b.custom_minimum_size = Vector2(UiTokens.ICON_BUTTON, UiTokens.ICON_BUTTON)
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_constant_override("icon_max_width", 44)
	return b


static func hbox(separation: int = UiTokens.S2) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func vbox(separation: int = UiTokens.S2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func spacer(vertical: bool = true) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Rounded "chip" (tag) with a label: glass on night, or a colour.
static func chip(text: String, bg: Color = Color(0, 0, 0, 0.3), fg: Color = UiPalette.ON_NIGHT) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, UiTokens.CHIP_H)
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(UiTokens.CHIP_H / 2)
	box.set_border_width_all(2)
	box.border_color = Color(fg, 0.16)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	box.anti_aliasing = true
	p.add_theme_stylebox_override("panel", box)
	var l := label(text, "MicroLabel", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color", fg)
	p.add_child(l)
	return p
