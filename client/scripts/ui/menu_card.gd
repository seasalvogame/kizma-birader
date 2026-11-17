class_name MenuCard
extends Button
## Glass menu card (prototype 03_ana_menu: "Özel Oda", "Pratik"): icon,
## title, subtitle and an optional "SOON" chip. `wide` = one row with the icon
## on the left and a chevron on the right (mode list); otherwise a tile.

var icon_name := ""
var title := ""
var subtitle := ""
var soon := false
var badge := ""             # custom chip text (e.g. TEST) instead of SOON
var wide := false
var tint := Color.WHITE        # icon colour

var _face := StyleBoxFlat.new()


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_build()
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


## Rebuilds the card after title / subtitle / badge changed (e.g. a live counter).
func refresh() -> void:
	if not is_inside_tree():
		return
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	_build()


func _build() -> void:
	custom_minimum_size = Vector2(0, 156 if wide else 232)
	_face.bg_color = UiPalette.GLASS
	_face.border_color = UiPalette.GLASS_EDGE
	_face.set_border_width_all(3)
	_face.set_corner_radius_all(UiTokens.R_L)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var texts := UiKit.vbox(2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	# A label with ellipsis overrun has no minimum width: keep the title plain.
	var head := UiKit.hbox(UiTokens.S1)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UiKit.label(title, "H3Label")
	head.add_child(t)
	if (soon or badge != "") and wide:
		var chip := _chip()
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(chip)
	texts.add_child(head)
	var sub := UiKit.label(subtitle, "DimLabel")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(sub)
	var ic := TextureRect.new()
	ic.texture = UiTheme.icon(icon_name)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(64, 64)
	ic.modulate = tint
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wide:
		var row := UiKit.hbox(UiTokens.S3)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		row.add_child(texts)
		var chev := TextureRect.new()
		chev.texture = UiTheme.icon("chevron")
		chev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chev.custom_minimum_size = Vector2(40, 40)
		chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chev.modulate = Color(1, 1, 1, 0.5)
		chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chev)
		margin.add_child(row)
	else:
		var col := UiKit.vbox(UiTokens.S1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var top := UiKit.hbox(UiTokens.S1)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(ic)
		top.add_child(UiKit.spacer(false))
		if soon or badge != "":
			var chip := _chip()
			chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			top.add_child(chip)
		col.add_child(top)
		col.add_child(texts)
		margin.add_child(col)


func _chip() -> PanelContainer:
	if badge != "":
		return UiKit.chip(badge, Color(UiPalette.MINT_500, 0.2), UiPalette.MINT_500)
	return UiKit.chip(tr("SOON"), Color(UiPalette.MANGO_500, 0.22), UiPalette.MANGO_300)


func _draw() -> void:
	var down := is_pressed() or get_draw_mode() == DRAW_PRESSED
	_face.bg_color = Color(1, 1, 1, 0.12) if down else UiPalette.GLASS
	draw_style_box(_face, Rect2(Vector2.ZERO, size))
