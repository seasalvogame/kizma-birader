class_name AppScreen
extends Control
## Base of the menu screens (Phase 3.3): night background, safe-area margins,
## an optional header (back button + title), a scrolling column (`content`),
## an optional footer pinned above the bottom edge and, for the main tabs, the
## bottom navigation bar. Screens override _build() and the small hooks below.
## Navigation is requested with signals; the router (main.gd) owns the stack.

signal navigate(route: String, params: Dictionary)
signal back_requested

var params := {}
var content: VBoxContainer
var footer: VBoxContainer
var nav_bar: NavBar
var insets := Vector2.ZERO


func _ready() -> void:
	add_child(NightBackground.new())
	insets = SafeArea.insets(get_viewport_rect().size)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", UiTokens.EDGE)
	margin.add_theme_constant_override("margin_right", UiTokens.EDGE)
	margin.add_theme_constant_override("margin_top", int(insets.x) + UiTokens.S2)
	var tab := _nav_tab()
	margin.add_theme_constant_override("margin_bottom", UiTokens.S2 if tab != "" else int(insets.y) + UiTokens.S3)
	root.add_child(margin)
	var column := UiKit.vbox(UiTokens.S3)
	margin.add_child(column)
	if _title() != "":
		column.add_child(_header())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	column.add_child(scroll)
	content = UiKit.vbox(UiTokens.S3)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	footer = UiKit.vbox(UiTokens.S2)
	column.add_child(footer)
	if tab != "":
		nav_bar = NavBar.new()
		nav_bar.current = tab
		nav_bar.bottom_inset = insets.y
		nav_bar.tab_selected.connect(func(id: String) -> void:
			if id != tab:
				navigate.emit(id, {}))
		root.add_child(nav_bar)
	_build()
	if footer.get_child_count() == 0:
		footer.hide()


## Header title; "" = no header.
func _title() -> String:
	return ""


## Main tabs show the bottom bar instead of a back button: return the tab id.
func _nav_tab() -> String:
	return ""


func _build() -> void:
	pass


## Android back / Escape. Return true when the screen handled it itself.
func handle_back() -> bool:
	return false


func _header() -> Control:
	var row := UiKit.hbox(UiTokens.S2)
	if _nav_tab() == "":
		var back := UiKit.icon_button("back", tr("BACK"))
		back.pressed.connect(func() -> void: back_requested.emit())
		row.add_child(back)
	var title := UiKit.label(_title(), "H2Label")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	var extra := _header_extra()
	if extra != null:
		row.add_child(extra)
	return row


## Optional control at the right end of the header.
func _header_extra() -> Control:
	return null


## Cream card with a heading; returns the card's inner column.
func card(heading: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CreamCard"
	var col := UiKit.vbox(UiTokens.S2)
	panel.add_child(col)
	if heading != "":
		col.add_child(UiKit.label(heading, "InkH3Label"))
	content.add_child(panel)
	return col


static func wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
