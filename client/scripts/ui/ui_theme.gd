class_name UiTheme
extends RefCounted
## Builds the shared Theme of "Akşam Masası" in code (fonts, buttons, cards,
## labels) so every value comes from UiTokens / UiPalette.
## Button variations: PrimaryButton, SecondaryButton, BerryButton,
## MintButton, GhostButton, IconButton. Panels: CreamCard, GlassPanel,
## SheetPanel. Labels: DisplayLabel, H1Label, H2Label, H3Label, BodyLabel,
## DimLabel, CaptionLabel, MicroLabel, InkH2Label, InkBodyLabel, InkDimLabel.

const BALOO := "res://assets/fonts/Baloo2.ttf"
const NUNITO := "res://assets/fonts/Nunito-Variable.ttf"

static var _theme: Theme
static var _fonts := {}


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = UiTokens.BODY
	t.set_color("font_color", "Label", UiPalette.ON_NIGHT)
	_label(t, "DisplayLabel", display_font(), UiTokens.DISPLAY, UiPalette.ON_NIGHT)
	_label(t, "H1Label", display_font(), UiTokens.H1, UiPalette.ON_NIGHT)
	_label(t, "H2Label", display_font(), UiTokens.H2, UiPalette.ON_NIGHT)
	_label(t, "H3Label", display_font(700), UiTokens.H3, UiPalette.ON_NIGHT)
	_label(t, "BodyLabel", body_font(), UiTokens.BODY, UiPalette.ON_NIGHT)
	_label(t, "DimLabel", body_font(), UiTokens.LABEL, UiPalette.ON_NIGHT_DIM)
	_label(t, "CaptionLabel", body_font(), UiTokens.CAPTION, UiPalette.ON_NIGHT_DIM)
	_label(t, "MicroLabel", body_font(900), UiTokens.MICRO, UiPalette.ON_NIGHT_DIM)
	_label(t, "InkH2Label", display_font(), UiTokens.H2, UiPalette.INK_900)
	_label(t, "InkH3Label", display_font(700), UiTokens.H3, UiPalette.INK_900)
	_label(t, "InkBodyLabel", body_font(), UiTokens.BODY, UiPalette.INK_900)
	_label(t, "InkDimLabel", body_font(), UiTokens.LABEL, UiPalette.INK_500)
	for kind: String in ["primary", "secondary", "berry", "mint", "ghost"]:
		_button(t, kind.capitalize() + "Button", kind)
	_icon_button(t)
	t.set_stylebox("panel", "CreamCard", card_box())
	t.set_type_variation("CreamCard", "PanelContainer")
	t.set_stylebox("panel", "GlassPanel", glass_box())
	t.set_type_variation("GlassPanel", "PanelContainer")
	t.set_stylebox("panel", "SheetPanel", card_box(UiTokens.R_XL, true))
	t.set_type_variation("SheetPanel", "PanelContainer")
	_theme = t
	return t


## Baloo 2 at a weight (800 default).
static func display_font(weight: int = 800) -> Font:
	return _variation(BALOO, weight)


## Nunito at a weight (700 default).
static func body_font(weight: int = 700) -> Font:
	return _variation(NUNITO, weight)


static func _variation(path: String, weight: int) -> Font:
	var key := "%s:%d" % [path, weight]
	if _fonts.has(key):
		return _fonts[key]
	var base: FontFile = load(path)
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	f.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	_fonts[key] = f
	return f


static func _label(t: Theme, name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


static func _button(t: Theme, name: String, kind: String) -> void:
	t.set_type_variation(name, "Button")
	var normal := _button_box(kind, false)
	var pressed := _button_box(kind, true)
	t.set_stylebox("normal", name, normal)
	t.set_stylebox("hover", name, normal)
	t.set_stylebox("focus", name, StyleBoxEmpty.new())
	t.set_stylebox("pressed", name, pressed)
	t.set_stylebox("hover_pressed", name, pressed)
	var disabled := normal.duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(1, 1, 1, 0.45)
	t.set_stylebox("disabled", name, disabled)
	t.set_font("font", name, display_font())
	t.set_font_size("font_size", name, UiTokens.BUTTON_TEXT)
	var ink := UiPalette.MANGO_INK
	match kind:
		"secondary":
			ink = UiPalette.INK_900
		"berry":
			ink = Color.WHITE
		"mint":
			ink = Color("#04291b")
		"ghost":
			ink = UiPalette.ON_NIGHT
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, name, ink)
	t.set_color("font_disabled_color", name, Color(ink, 0.55))
	t.set_constant("h_separation", name, UiTokens.S2)


## 9-slice texture box; pressed = content sinks 8 px (the 3D edge shrinks).
static func _button_box(kind: String, pressed: bool) -> StyleBoxTexture:
	var path := "res://assets/ui/button_%s%s.svg" % [kind, "_pressed" if pressed else ""]
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.texture_margin_left = 48
	box.texture_margin_right = 48
	box.texture_margin_top = 28
	box.texture_margin_bottom = 34
	box.content_margin_left = UiTokens.S4
	box.content_margin_right = UiTokens.S4
	var sink := 8 if pressed and kind != "ghost" else 0
	box.content_margin_top = 4 + sink
	box.content_margin_bottom = 14 - sink
	return box


static func _icon_button(t: Theme) -> void:
	t.set_type_variation("IconButton", "Button")
	var normal := glass_box(30)
	var pressed := glass_box(30)
	pressed.bg_color = Color(1, 1, 1, 0.16)
	for state: String in ["normal", "hover", "focus"]:
		t.set_stylebox(state, "IconButton", normal if state != "focus" else StyleBoxEmpty.new())
	t.set_stylebox("pressed", "IconButton", pressed)
	t.set_stylebox("hover_pressed", "IconButton", pressed)
	t.set_constant("icon_max_width", "IconButton", 44)


## Cream card: flat cream, 6 pt (12 px) cream-300 bottom edge, soft shadow.
static func card_box(radius: int = UiTokens.R_XL, sheet: bool = false) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = UiPalette.CREAM_50
	b.set_corner_radius_all(radius)
	# A light rim separates a card from the night surface without making it
	# metallic. The heavier warm lower edge keeps the tactile card language.
	b.border_width_top = 2
	b.border_width_left = 2
	b.border_width_right = 2
	b.border_width_bottom = 12
	b.border_color = UiPalette.CREAM_300
	b.shadow_color = UiPalette.CREAM_SHADOW
	b.shadow_size = 32
	b.shadow_offset = Vector2(0, 18)
	b.set_content_margin_all(UiTokens.S4)
	b.content_margin_bottom = UiTokens.S4 + 12
	b.anti_aliasing = true
	if sheet:
		b.corner_radius_bottom_left = 0
		b.corner_radius_bottom_right = 0
		b.border_width_bottom = 0
	return b


## Dark glass panel: 7 % white, 12 % white edge.
static func glass_box(radius: int = UiTokens.R_L) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = UiPalette.GLASS
	b.border_color = UiPalette.GLASS_EDGE
	b.set_border_width_all(3)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(UiTokens.S3)
	b.shadow_color = UiPalette.GLASS_SHADOW
	b.shadow_size = 16
	b.shadow_offset = Vector2(0, 8)
	b.anti_aliasing = true
	return b


static func icon(name: String) -> Texture2D:
	return load("res://assets/icons/%s.svg" % name)
